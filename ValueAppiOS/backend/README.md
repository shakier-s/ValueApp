# ValueApp API

Express/PostgreSQL service for shared deals and one-time voucher redemption.

Required environment: `DATABASE_URL`. Railway supplies this through a service reference to the PostgreSQL `ValueApp` service.

The iOS app uses an anonymous device identifier in `X-User-ID`. Before a public production launch, replace this MVP identity mechanism with Sign in with Apple and server-verified identity tokens.
