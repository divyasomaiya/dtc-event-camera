# Jules first task — DTC Event Camera foundation, then handoff to Google Antigravity

**You are Google Jules, the FIRST coding agent for this project.** After your work, a different agent, **Google Antigravity**, will continue development from this SAME private GitHub repository. There is **no automatic Jules-to-Antigravity migration**. Your job is to make your changes portable, tested, committed to GitHub, and documented in the repo.

**Important availability:** Google announced that Jules becomes read-only after November 11, 2026. Prioritize completing a small, reviewable, documented PR over attempting the whole application.

## What to read first

Read `README.md`, `AGENTS.md`, `docs/PRODUCT_SPEC.md`, `docs/DATA_MODEL.md`, `docs/HANDOFF_CHECKLIST.md`, `apps/api/migrations/0001_init.sql`, `scripts/validate_schema.py`, and `ANTIGRAVITY_START_PROMPT.md`. Treat the SQL schema as a draft rather than proven production code.

## Do the following limited, valuable engineering work

1. Inspect the current project and identify what is implemented, only documented, unverified, and missing. Do not present the handoff package as a functioning guest camera or API.
2. Run `python scripts/validate_schema.py` (or `python3` if required). Record the exact commands and outcomes.
3. Audit D1/SQLite migration 0001 for foreign keys, uniqueness, guest versus registered-user identity, event boundaries, quota reservations, idempotency, deletion/reconciliation, manual orders/payments and race conditions. Do not claim the local SQLite test proves live D1 concurrency correctness.
4. Make narrowly scoped, reviewable changes to migration, validation script or explanatory docs only if you find an evidenced defect. Add focused tests for corrected issues. If uncertain, log the risk rather than invent behavior.
5. Prepare the next implementation phase for a **single Android+iPhone browser-first PWA** with Cloudflare Workers + Static Assets, D1 for relational data, private R2 for original photos/videos, and optional replaceable video-processing service. iOS App Clip is future scope.
6. Keep **four surfaces** separate: Admin, Host, Guest, User. Registered users and anonymous per-event guests are different concepts. Do not finalize the exact User panel, customer prices, photo-reveal UX, or other pending product-owner choices.
7. Preserve server-issued anonymous sessions, camera/gallery shared quotas, offline IndexedDB queue with foreground retry, and no paid resource provisioning. No production deploy, Cloudflare resource creation, API keys or secrets in Git.
8. Create `docs/JULES_AUDIT_REPORT.md` with specific findings, evidence, tests and outstanding issues.
9. Create **`docs/JULES_TO_ANTIGRAVITY_HANDOFF.md`** containing: changes made, current file tree, architectural decisions, what is complete/unfinished, exact commands to run, test results, unresolved bugs, security risks, D1/R2 pending tasks, and the recommended FIRST Antigravity coding task. Include a short copy/paste Antigravity continuation prompt.
10. Keep the original project files and useful work. Make a dedicated GitHub branch and submit a reviewable PR (or provide the branch/patch if PR creation is unavailable). Do not merge into `main` without my approval.

## Expected final response

Link the branch/PR, summarize files changed, include test output, and direct the owner to `docs/JULES_TO_ANTIGRAVITY_HANDOFF.md`. Explicitly tell the owner that Antigravity should **clone the same GitHub repo after changes are committed/merged** and read `AGENTS.md`, the current specifications, and your handoff report. Don't claim Antigravity already has this Jules session context.

**Scope limit:** The owner is still specifying detailed behavior inspired by POV.camera and Lense. This is foundation/testing/handoff, **not** permission to build or deploy a finished wedding app.
