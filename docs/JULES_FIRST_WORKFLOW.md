# Owner workflow: Jules first, Antigravity next

1. Create a **private** GitHub repo named `dtc-event-camera`. Start with an empty repo (no generated README) if uploading these files as the initial commit.
2. Extract the ZIP on your computer. Open the `dtc-event-camera-handoff` folder, then upload **its contents** to the GitHub repo root. The repository should show `AGENTS.md`, `JULES_START_PROMPT.md`, `README.md`, `docs/`, `apps/`, and `scripts/` immediately at the top level. Do not upload the ZIP blob instead, and do not put everything under a nested `dtc-event-camera-handoff/` subfolder.
3. Commit the initial files to `main`. Do not upload secrets, `.env`, guest photos/videos or API tokens.
4. In Jules, grant its GitHub app access to the repo, select the `main` base branch, and paste the contents of `JULES_START_PROMPT.md`. Review its plan and approve only if it stays within scoped foundation/testing tasks.
5. When Jules completes, save/publish the Jules branch and open a PR. Review it and run tests. Merge only after verifying changes; keep its PR/branch if not yet reviewed.
6. Before Jules becomes read-only, use Google's Jules export if you need full prompt/session/settings context; treat any exported `.env` files as secrets and do **not** commit them to GitHub.
7. In Antigravity, clone the SAME repo. If Jules PR is merged, work from `main`; if not, review and integrate the branch first. Read `AGENTS.md` and `docs/JULES_TO_ANTIGRAVITY_HANDOFF.md` (created by Jules), then the product requirements and Antigravity start prompt.

**Date warning:** Google announced the Jules task/session cutoff is November 11, 2026, followed by read-only access and final shutdown December 31, 2026. If the Jules interface no longer accepts tasks, skip the Jules execution and give the same repository plus `JULES_START_PROMPT.md` to Antigravity as historical task context.

**This is a handoff package and draft schema, not a finished application and not a deployed Cloudflare service.**
