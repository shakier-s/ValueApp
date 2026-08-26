import crypto from "node:crypto";
import fs from "node:fs/promises";
import express from "express";
import helmet from "helmet";
import pg from "pg";

const { Pool } = pg;
const app = express();
const port = Number(process.env.PORT || 3000);
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: process.env.NODE_ENV === "production" ? { rejectUnauthorized: false } : false });

app.use(helmet());
app.use(express.json({ limit: "64kb" }));

const asyncRoute = fn => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
const hash = value => crypto.createHash("sha256").update(value).digest("hex");
const passwordHash = (password, salt) => crypto.scryptSync(password, salt, 64).toString("hex");

async function identity(req, requiredRole) {
  const bearer = req.header("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (bearer) {
    const { rows } = await pool.query(`SELECT u.id::text AS id,u.role FROM auth_sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=$1 AND s.expires_at>now()`, [hash(bearer)]);
    if (!rows.length || (requiredRole && rows[0].role !== requiredRole)) return null;
    return rows[0].id;
  }
  return req.header("x-user-id")?.trim() || null;
}

async function authenticatedUser(req, requiredRole) {
  const bearer = req.header("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!bearer) return null;
  const { rows } = await pool.query(`SELECT u.id,u.email,u.name,u.role,u.password_salt,u.password_hash,s.token_hash FROM auth_sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=$1 AND s.expires_at>now()`, [hash(bearer)]);
  if (!rows.length || (requiredRole && rows[0].role !== requiredRole)) return null;
  return rows[0];
}

async function createSession(user) {
  const token = crypto.randomBytes(32).toString("hex");
  await pool.query(`INSERT INTO auth_sessions(token_hash,user_id) VALUES($1,$2)`, [hash(token), user.id]);
  return { token, user: { id: user.id, email: user.email, name: user.name || null, role: user.role } };
}

async function migrate() {
  const sql = await fs.readFile(new URL("./schema.sql", import.meta.url), "utf8");
  await pool.query(sql);
}

const dealSelect = `
  SELECT d.id, m.name AS merchant, d.title, d.detail, d.deal_type AS type,
    d.value::float8 AS value, d.category, d.distance::float8 AS distance,
    d.latitude, d.longitude,
    d.expiry, d.quantity, d.redeemed, d.is_active AS "isActive"
  FROM deals d JOIN merchants m ON m.id = d.merchant_id`;

app.get("/health", asyncRoute(async (_req, res) => {
  await pool.query("SELECT 1");
  res.json({ status: "ok" });
}));

app.post("/v1/auth/register", asyncRoute(async (req, res) => {
  const email = String(req.body.email || "").trim().toLowerCase();
  const password = String(req.body.password || "");
  const role = req.body.role;
  const name = String(req.body.name || "").trim().slice(0, 80) || null;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || password.length < 8 || !["shopper", "merchant"].includes(role)) return res.status(400).json({ error: "Enter a valid email, an 8-character password and an account type." });
  const salt = crypto.randomBytes(16).toString("hex");
  try {
    const { rows } = await pool.query(`INSERT INTO users(email,name,password_salt,password_hash,role) VALUES($1,$2,$3,$4,$5) RETURNING id,email,name,role`, [email, name, salt, passwordHash(password, salt), role]);
    res.status(201).json(await createSession(rows[0]));
  } catch (error) {
    if (error.code === "23505") return res.status(409).json({ error: "An account with this email already exists." });
    throw error;
  }
}));

app.post("/v1/auth/login", asyncRoute(async (req, res) => {
  const email = String(req.body.email || "").trim().toLowerCase();
  const password = String(req.body.password || "");
  const { rows } = await pool.query(`SELECT id,email,name,role,password_salt,password_hash FROM users WHERE email=$1`, [email]);
  if (!rows.length) return res.status(401).json({ error: "Incorrect email or password." });
  const candidate = Buffer.from(passwordHash(password, rows[0].password_salt), "hex");
  const expected = Buffer.from(rows[0].password_hash, "hex");
  if (candidate.length !== expected.length || !crypto.timingSafeEqual(candidate, expected)) return res.status(401).json({ error: "Incorrect email or password." });
  res.json(await createSession(rows[0]));
}));

app.patch("/v1/profile", asyncRoute(async (req, res) => {
  const user = await authenticatedUser(req);
  if (!user) return res.status(401).json({ error: "Sign in required." });
  const email = String(req.body.email || "").trim().toLowerCase();
  const name = String(req.body.name || "").trim().slice(0, 80);
  if (!name || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return res.status(400).json({ error: "Enter a name and valid email address." });
  try {
    const { rows } = await pool.query(`UPDATE users SET name=$1,email=$2 WHERE id=$3 RETURNING id,email,name,role`, [name, email, user.id]);
    res.json(rows[0]);
  } catch (error) {
    if (error.code === "23505") return res.status(409).json({ error: "An account with this email already exists." });
    throw error;
  }
}));

app.patch("/v1/profile/password", asyncRoute(async (req, res) => {
  const user = await authenticatedUser(req);
  if (!user) return res.status(401).json({ error: "Sign in required." });
  const currentPassword = String(req.body.currentPassword || "");
  const newPassword = String(req.body.newPassword || "");
  const candidate = Buffer.from(passwordHash(currentPassword, user.password_salt), "hex");
  const expected = Buffer.from(user.password_hash, "hex");
  if (candidate.length !== expected.length || !crypto.timingSafeEqual(candidate, expected)) return res.status(403).json({ error: "Current password is incorrect." });
  if (newPassword.length < 8) return res.status(400).json({ error: "New password must contain at least 8 characters." });
  const salt = crypto.randomBytes(16).toString("hex");
  await pool.query(`UPDATE users SET password_salt=$1,password_hash=$2 WHERE id=$3`, [salt, passwordHash(newPassword, salt), user.id]);
  res.json({ ok: true });
}));

app.get("/v1/deals", asyncRoute(async (_req, res) => {
  const { rows } = await pool.query(`${dealSelect} WHERE d.is_active AND d.expiry > now() AND d.redeemed < d.quantity ORDER BY d.created_at DESC`);
  res.json(rows);
}));

app.get("/v1/merchant/deals", asyncRoute(async (req, res) => {
  const owner = await identity(req, "merchant");
  if (!owner) return res.status(401).json({ error: "x-user-id required" });
  const { rows } = await pool.query(`${dealSelect} WHERE m.owner_id=$1 ORDER BY d.created_at DESC`, [owner]);
  res.json(rows.map(row => ({ ...row, isOwned: true })));
}));

app.post("/v1/merchants", asyncRoute(async (req, res) => {
  const owner = await identity(req, "merchant");
  const { name, attendantCode } = req.body;
  if (!owner || !name || !/^\d{4,8}$/.test(attendantCode || "")) return res.status(400).json({ error: "name and a 4–8 digit attendant code are required" });
  const { rows } = await pool.query(`INSERT INTO merchants(owner_id,name,attendant_code_hash) VALUES($1,$2,$3) ON CONFLICT(owner_id) DO UPDATE SET name=EXCLUDED.name RETURNING id,name`, [owner, name, hash(attendantCode)]);
  res.status(201).json(rows[0]);
}));

app.post("/v1/deals", asyncRoute(async (req, res) => {
  const owner = await identity(req, "merchant");
  const { merchant, title, detail, type, value, category, expiry, quantity, latitude, longitude } = req.body;
  if (!owner || !merchant || !title || !detail || !type || !category || !expiry || !quantity) return res.status(400).json({ error: "missing deal fields" });
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const merchantResult = await client.query(`INSERT INTO merchants(owner_id,name,attendant_code_hash) VALUES($1,$2,$3) ON CONFLICT(owner_id) DO UPDATE SET name=EXCLUDED.name RETURNING id`, [owner, merchant, hash("1234")]);
    const result = await client.query(`INSERT INTO deals(merchant_id,title,detail,deal_type,value,category,expiry,quantity,latitude,longitude) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id`, [merchantResult.rows[0].id, title, detail, type, value, category, expiry, quantity, latitude || null, longitude || null]);
    await client.query("COMMIT");
    const { rows } = await pool.query(`${dealSelect} WHERE d.id=$1`, [result.rows[0].id]);
    res.status(201).json({ ...rows[0], isOwned: true });
  } catch (error) { await client.query("ROLLBACK"); throw error; } finally { client.release(); }
}));

app.patch("/v1/deals/:id/status", asyncRoute(async (req, res) => {
  const owner = await identity(req, "merchant");
  const result = await pool.query(`UPDATE deals d SET is_active=$1 FROM merchants m WHERE d.id=$2 AND d.merchant_id=m.id AND m.owner_id=$3 RETURNING d.id`, [Boolean(req.body.isActive), req.params.id, owner]);
  if (!result.rowCount) return res.status(404).json({ error: "deal not found" });
  res.json({ ok: true });
}));

app.put("/v1/deals/:id", asyncRoute(async (req, res) => {
  const owner = await identity(req, "merchant");
  const { merchant, title, detail, type, value, category, expiry, quantity, latitude, longitude } = req.body;
  if (!owner || !merchant || !title || !detail || !type || !category || !expiry || !quantity) return res.status(400).json({ error: "missing deal fields" });
  const result = await pool.query(`UPDATE deals d SET title=$1,detail=$2,deal_type=$3,value=$4,category=$5,expiry=$6,quantity=$7,latitude=$8,longitude=$9 FROM merchants m WHERE d.id=$10 AND d.merchant_id=m.id AND m.owner_id=$11 RETURNING d.id`, [title, detail, type, value, category, expiry, quantity, latitude || null, longitude || null, req.params.id, owner]);
  if (!result.rowCount) return res.status(404).json({ error: "deal not found" });
  await pool.query(`UPDATE merchants SET name=$1 WHERE owner_id=$2`, [merchant, owner]);
  const { rows } = await pool.query(`${dealSelect} WHERE d.id=$1 AND m.owner_id=$2`, [req.params.id, owner]);
  res.json({ ...rows[0], isOwned: true });
}));

app.delete("/v1/deals/:id", asyncRoute(async (req, res) => {
  const owner = await identity(req, "merchant");
  const result = await pool.query(`DELETE FROM deals d USING merchants m WHERE d.id=$1 AND d.merchant_id=m.id AND m.owner_id=$2 RETURNING d.id`, [req.params.id, owner]);
  if (!result.rowCount) return res.status(404).json({ error: "deal not found" });
  res.json({ ok: true });
}));

app.get("/v1/vouchers", asyncRoute(async (req, res) => {
  const shopper = await identity(req, "shopper");
  if (!shopper) return res.status(401).json({ error: "x-user-id required" });
  const { rows } = await pool.query(`SELECT id, deal_id AS "dealID", code, saved_at AS "savedAt", redeemed_at AS "redeemedAt", status FROM vouchers WHERE shopper_id=$1 ORDER BY saved_at DESC`, [shopper]);
  res.json(rows);
}));

app.post("/v1/deals/:id/vouchers", asyncRoute(async (req, res) => {
  const shopper = await identity(req, "shopper");
  if (!shopper) return res.status(401).json({ error: "x-user-id required" });
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const deal = await client.query(`SELECT id FROM deals WHERE id=$1 AND is_active AND expiry>now() AND redeemed<quantity FOR UPDATE`, [req.params.id]);
    if (!deal.rows.length) { await client.query("ROLLBACK"); return res.status(404).json({ error: "deal unavailable" }); }
    const owned = await client.query(`SELECT count(*)::int AS count FROM vouchers WHERE deal_id=$1 AND shopper_id=$2`, [req.params.id, shopper]);
    if (owned.rows[0].count >= 10) { await client.query("ROLLBACK"); return res.status(409).json({ error: "You can save up to 10 coupons from the same deal." }); }
    const code = `VAL-${crypto.randomInt(100000, 999999)}`;
    const { rows } = await client.query(`INSERT INTO vouchers(deal_id,shopper_id,code) VALUES($1,$2,$3) RETURNING id,deal_id AS "dealID",code,saved_at AS "savedAt",redeemed_at AS "redeemedAt",status`, [req.params.id, shopper, code]);
    await client.query("COMMIT");
    res.status(201).json(rows[0]);
  } catch (error) { await client.query("ROLLBACK"); throw error; } finally { client.release(); }
}));

app.post("/v1/vouchers/:id/redeem", asyncRoute(async (req, res) => {
  const shopper = await identity(req, "shopper");
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const found = await client.query(`SELECT v.deal_id,m.attendant_code_hash,d.redeemed,d.quantity FROM vouchers v JOIN deals d ON d.id=v.deal_id JOIN merchants m ON m.id=d.merchant_id WHERE v.id=$1 AND v.shopper_id=$2 AND v.status='Ready to use' FOR UPDATE`, [req.params.id, shopper]);
    if (!found.rows.length || found.rows[0].attendant_code_hash !== hash(req.body.attendantCode || "")) { await client.query("ROLLBACK"); return res.status(403).json({ error: "invalid or used voucher" }); }
    if (found.rows[0].redeemed >= found.rows[0].quantity) { await client.query("ROLLBACK"); return res.status(409).json({ error: "This deal has no coupons remaining." }); }
    await client.query(`UPDATE vouchers SET status='Redeemed',redeemed_at=now() WHERE id=$1`, [req.params.id]);
    await client.query(`UPDATE deals SET redeemed=redeemed+1 WHERE id=$1 AND redeemed<quantity`, [found.rows[0].deal_id]);
    await client.query("COMMIT");
    res.json({ ok: true });
  } catch (error) { await client.query("ROLLBACK"); throw error; } finally { client.release(); }
}));

app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({ error: "internal server error" });
});

migrate().then(() => app.listen(port, "0.0.0.0", () => console.log(`ValueApp API listening on ${port}`))).catch(error => { console.error(error); process.exit(1); });
