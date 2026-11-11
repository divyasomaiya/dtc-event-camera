# Agent instructions — DTC Event Camera

These files are the *current engineering baseline*, not authorization to invent or finalize unspecified features. Before writing production code, read `docs/PRODUCT_SPEC.md` and `docs/DATA_MODEL.md`, then inspect all existing repository files if any.

## Non-negotiable requirements

1. **Zero-install guest path**: QR/NFC → HTTPS web app → name input → camera; no email/password for ordinary guests. Use a single responsive PWA for Android and iPhone in V1.
2. **Four surfaces**: Admin, Host, Guest and User. The precise boundaries of the User/customer panel remain to be defined by the product owner; do not collapse it into Host without confirmation.
3. **Shared limits**: camera-taken and gallery-uploaded media consume exactly the same server-side allowance, separated by photo/video type.
4. **Server-authorized guest sessions**: secrets issued by the server; store only token hashes in D1, prefer Secure + HttpOnly + SameSite cookies when deployed on a compatible site origin. Never trust a token minted in browser JavaScript or use IP addresses as unique identity.
5. **Offline resilience**: app shell cache; IndexedDB queue; Background Sync only where available; foreground/resume/reconnect retries everywhere. Never claim an upload is safely backed up until verified by the server.
6. **Strong quota operations**: atomic conditional updates in D1, idempotency keys, expiry/rollback for unfinished uploads, and reconciliation of D1 records against private R2 objects. Allow delete-and-retake only after reliable deletion/slot release.
7. **Protect private media**: R2 objects private by default. Authorization for album view, individual download and video playback; short-lived signed access as appropriate. No public bucket or public source repository containing media.
8. **Separate storage from playback**: R2 stores originals for photos and videos. Optional transcoding/Stream must be a replaceable service. Retain originals if the business plan calls for later editing.
9. **Costs**: free micro-events (target 5–7 guests), photo-only, video-only, combined, custom quotes, manual payment approval, discounts and per-event cost guardrails. These are product modes; *prices are not finalized*.
10. **No surprise deployment**: never spend money, enable paid resources, set up payment gateways, publish an iOS app, or deploy to production without explicit approval.

## Engineering conventions

- Use TypeScript and validated input schemas for Workers routes and the PWA; write authZ tests for every role and event boundary.
- Use UTC epoch seconds in D1 timestamps; keep user-facing timezone separately per event.
- IDs are cryptographically random UUIDs/ULIDs generated server-side; never trust client-chosen object keys or prices.
- Store all payment amounts as integer INR paise; verify manual payments before marking orders paid.
- Store estimated vs measured usage separately; provider usage/actual costs can lag and must be reconciled.
- Treat database migration 0001 as a *draft* until product scope is confirmed. Prefer additive migrations once deployed.
- Make the photo/video object storage adapter replaceable; keep database and storage credentials out of GitHub.

## Initial development sequence

Read specs → review database schema → implement API auth and event quotas → offline-resilient capture and upload → galleries and cost guards → four surfaces → live device tests → deployment.
