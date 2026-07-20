# Developer Notes — car_rental_backend

## Standing Rules for Debug / Scratch Scripts

**ALL temporary scripts (database queries, API testers, OTP overrides, connection checks)
must be deleted from disk before ending a session.**

### Naming patterns that are ALWAYS debug-only (never application code)

| Pattern | Examples |
|---------|---------|
| `test_*.js / .ts` | `test_conn.js`, `test_parse.dart` |
| `check_*.js / .ts` | `check_db.js` |
| `override_*.js / .ts` | `override_otp.js` |
| `*_conn.js / .ts` | `test_conn.js` |
| `api_test_*.js / .ts` | `api_test_send_otp.js` |
| `query_*.js / .ts` | `query_otp.js`, `query-db.ts` |
| `scratch_*.js / .ts` | `scratch_check.js` |
| `list_all_bookings.js` | (specific prior offender) |

All of the above are covered by `.gitignore` patterns.  
**However, being gitignored does not mean they can be left on disk.**  
They must be physically deleted (`Remove-Item` / `rm`) before the session ends.

### Why this matters
These scripts typically contain:
- Hardcoded production database URLs (`DATABASE_URL`)
- Hardcoded JWT tokens or admin credentials
- Hardcoded phone numbers / OTPs

Leaving them on disk is a security and hygiene violation regardless of gitignore status.

### Session-end checklist
Before signing off any session on this repo:
- [ ] Run: `Get-ChildItem -Recurse | Where-Object { $_.Name -match "^test_|^check_|^override_|_conn\.|^api_test_|^query_|^scratch_" }` (excluding `node_modules`)
- [ ] Delete any files found
- [ ] Confirm `git status` is clean
