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
const userID = req => req.header("x-user-id")?.trim();

async function migrate() {
  const sql = await fs.readFile(new URL("./schema.sql", import.meta.url), "utf8");
  await pool.query(sql);
}

const dealSelect = `
  SELECT d.id, m.name AS merchant, d.title, d.detail, d.deal_type AS type,
    d.value::float8 AS value, d.category, d.distance::float8 AS distance,
    d.expiry, d.quantity, d.redeemed, d.is_active AS "isActive"
  FROM deals d JOIN merchants m ON m.id = d.merchant_id`;

app.get("/health", asyncRoute(async (_req, res) => {
  await pool.query("SELECT 1");
  res.json({ status: "ok" });
}));

app.get("/v1/deals", asyncRoute(async (_req, res) => {
  const { rows } = await pool.query(`${dealSelect} WHERE d.is_active AND d.expiry > now() AND d.redeemed < d.quantity ORDER BY d.created_at DESC`);
  res.json(rows);
}));

app.post("/v1/merchants", asyncRoute(async (req, res) => {
  const owner = userID(req);
  const { name, attendantCode } = req.body;
  if (!owner || !name || !/^\d{4,8}$/.test(attendantCode || "")) return res.status(400).json({ error: "name and a 4–8 digit attendant code are required" });
  const { rows } = await pool.query(`INSERT INTO merchants(owner_id,name,attendant_code_hash) VALUES($1,$2,$3) ON CONFLICT(owner_id) DO UPDATE SET name=EXCLUDED.name RETURNING id,name`, [owner, name, hash(attendantCode)]);
  res.status(201).json(rows[0]);
}));

app.post("/v1/deals", asyncRoute(async (req, res) => {
  const owner = userID(req);
  const { merchant, title, detail, type, value, category, expiry, quantity } = req.body;
  if (!owner || !merchant || !title || !detail || !type || !category || !expiry || !quantity) return res.status(400).json({ error: "missing deal fields" });
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const merchantResult = await client.query(`INSERT INTO merchants(owner_id,name,attendant_code_hash) VALUES($1,$2,$3) ON CONFLICT(owner_id) DO UPDATE SET name=EXCLUDED.name RETURNING id`, [owner, merchant, hash("1234")]);
    const result = await client.query(`INSERT INTO deals(merchant_id,title,detail,deal_type,value,category,expiry,quantity) VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`, [merchantResult.rows[0].id, title, detail, type, value, category, expiry, quantity]);
    await client.query("COMMIT");
    const { rows } = await pool.query(`${dealSelect} WHERE d.id=$1`, [result.rows[0].id]);
    res.status(201).json(rows[0]);
  } catch (error) { await client.query("ROLLBACK"); throw error; } finally { client.release(); }
}));

app.patch("/v1/deals/:id/status", asyncRoute(async (req, res) => {
  const owner = userID(req);
  const result = await pool.query(`UPDATE deals d SET is_active=$1 FROM merchants m WHERE d.id=$2 AND d.merchant_id=m.id AND m.owner_id=$3 RETURNING d.id`, [Boolean(req.body.isActive), req.params.id, owner]);
  if (!result.rowCount) return res.status(404).json({ error: "deal not found" });
  res.json({ ok: true });
}));

app.get("/v1/vouchers", asyncRoute(async (req, res) => {
  const shopper = userID(req);
  if (!shopper) return res.status(401).json({ error: "x-user-id required" });
  const { rows } = await pool.query(`SELECT id, deal_id AS "dealID", code, saved_at AS "savedAt", redeemed_at AS "redeemedAt", status FROM vouchers WHERE shopper_id=$1 ORDER BY saved_at DESC`, [shopper]);
  res.json(rows);
}));

app.post("/v1/deals/:id/vouchers", asyncRoute(async (req, res) => {
  const shopper = userID(req);
  if (!shopper) return res.status(401).json({ error: "x-user-id required" });
  const code = `VAL-${crypto.randomInt(100000, 999999)}`;
  const { rows } = await pool.query(`INSERT INTO vouchers(deal_id,shopper_id,code) SELECT id,$2,$3 FROM deals WHERE id=$1 AND is_active AND expiry>now() AND redeemed<quantity ON CONFLICT(deal_id,shopper_id) DO UPDATE SET deal_id=EXCLUDED.deal_id RETURNING id,deal_id AS "dealID",code,saved_at AS "savedAt",redeemed_at AS "redeemedAt",status`, [req.params.id, shopper, code]);
  if (!rows.length) return res.status(404).json({ error: "deal unavailable" });
  res.status(201).json(rows[0]);
}));

app.post("/v1/vouchers/:id/redeem", asyncRoute(async (req, res) => {
  const shopper = userID(req);
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const found = await client.query(`SELECT v.deal_id,m.attendant_code_hash FROM vouchers v JOIN deals d ON d.id=v.deal_id JOIN merchants m ON m.id=d.merchant_id WHERE v.id=$1 AND v.shopper_id=$2 AND v.status='Ready to use' FOR UPDATE`, [req.params.id, shopper]);
    if (!found.rows.length || found.rows[0].attendant_code_hash !== hash(req.body.attendantCode || "")) { await client.query("ROLLBACK"); return res.status(403).json({ error: "invalid or used voucher" }); }
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
