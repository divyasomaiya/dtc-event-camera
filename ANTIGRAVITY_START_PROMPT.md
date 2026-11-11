# Copy/paste into Google Antigravity

I am building **DTC Event Camera**, a zero-install guest photo/video capture platform for events. This private repository contains a working architecture handoff and a *foundational draft* D1 migration.

**First task: review and validate the foundation; do not deploy, purchase, or finalize unspecified product features.**

1. Read `AGENTS.md`, `docs/PRODUCT_SPEC.md`, `docs/DATA_MODEL.md`, `docs/HANDOFF_CHECKLIST.md`, `apps/api/migrations/0001_init.sql` and `scripts/validate_schema.py` in full.
2. Run `python scripts/validate_schema.py`. Verify that the SQL is compatible with the targeted Cloudflare D1 runtime; identify migration/SQLite mismatches and security or concurrency issues.
3. Produce an entity relationship explanation showing the four surfaces: **Admin, Host, Guest, User**. Guests are anonymous per event; Users are registered platform accounts. Admin and Host are account roles.
4. Audit atomic guest enrollment, per-photo/per-video reservations, event storage reservations, idempotency, R2 direct upload confirmation, expiry/delete reconciliation, offline recovery and private download permissions.
5. Propose the minimum testable vertical slice: event creation → guest joins with server-issued session → photo/video quota reservation → private upload → confirmation → authenticated gallery.
6. Propose the source folder structure and API endpoints, the security test plan, Android/iPhone web camera tests, and Cloudflare free-tier usage protections. Prefer Cloudflare Workers + Static Assets, D1 and R2; keep video processing as an optional adapter.
7. Distinguish **implemented**, **draft**, **unknown**, and **deferred**. The complete POV/Lense-inspired UX, precise plan pricing and exact boundaries of the normal User panel are awaiting the product owner. Do not guess or quietly declare them final.
8. Present findings and a phased plan **before changing source code or deploying**. Never enable billed services or production infrastructure without explicit approval.

The target experience is a single Android/iOS browser PWA first, with a native iOS App Clip considered later. Anonymous sessions must come from the server (not a browser-generated trust token). Offline uploads must retry in foreground when background sync is unavailable. Camera-captured and gallery-selected media share the same server-enforced quotas.
