# DTC Event Camera — Engineering Handoff (Foundational Draft)

**Prepared:** 2026-11-11 · **Status:** Architecture accepted as working direction; feature details and prices are not yet final.  
**Use:** Extract this ZIP into the **root of a private GitHub repository**. Start with Jules using `JULES_START_PROMPT.md` if Jules still accepts tasks on November 11, 2026; then move to Antigravity using the same GitHub repo and Jules handoff report.  
**Important:** This is a saved *file package*, not a modification to ChatGPT Project memory.

## Files

```text
.
├── AGENTS.md                            # Antigravity agent guardrails and priorities
├── JULES_START_PROMPT.md               # Jules-first audit/task and handoff instructions
├── ANTIGRAVITY_START_PROMPT.md         # Antigravity continuation request
├── docs/
│   ├── PRODUCT_SPEC.md                  # Entire agreed direction, roles and non-goals
│   ├── DATA_MODEL.md                    # Entity relationships and quota transactions
│   ├── HANDOFF_CHECKLIST.md             # Implementation stages and release gates
│   ├── JULES_FIRST_WORKFLOW.md          # Exact GitHub/Jules/Antigravity steps
│   └── JULES_TO_ANTIGRAVITY_HANDOFF_TEMPLATE.md  # Jules should fill a real report
├── apps/api/migrations/
│   └── 0001_init.sql                    # Executable SQLite/D1 schema
└── scripts/
    └── validate_schema.py               # Local SQLite integrity smoke tests
```

## Architecture at a glance

QR/NFC event URL → shared Android/iOS browser PWA → Cloudflare Worker API → Cloudflare D1 (metadata and quotas) + private Cloudflare R2 (originals and previews). A future native **iOS App Clip** can reuse the same API. Use an optional video processing/delivery provider only when justified. GitHub holds **source code**, not guest media.

## Run the database smoke test

Requires Python 3.9+ with its bundled `sqlite3` module.

```bash
python scripts/validate_schema.py
```

The validator runs the migration in an in-memory SQLite database and checks relationship integrity, quota conditions and idempotent upload identifiers. **This does not substitute for a live D1 test**. Before deployment, apply the migration to a dedicated *development* D1 database using the CLI and workflow selected by the implementing project. Never run prototype migrations on an existing production D1 database.

## Referenced official docs

- [Cloudflare D1 database](https://developers.cloudflare.com/d1/)
- [D1 foreign keys](https://developers.cloudflare.com/d1/sql-api/foreign-keys/)
- [D1 migrations](https://developers.cloudflare.com/d1/reference/migrations/)
- [D1 limits](https://developers.cloudflare.com/d1/platform/limits/)
- [R2 upload methods](https://developers.cloudflare.com/r2/objects/upload-objects/)

**Important operational limit (as checked November 2026):** D1 Free has a **500 MB per-database limit** and **5 GB total account storage**; those are different limits. Guest photos and videos belong in R2, not D1.
