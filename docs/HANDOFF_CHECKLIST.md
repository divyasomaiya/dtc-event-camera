# Google Antigravity handoff and phased delivery

## Proposed repository bootstrap

- [ ] Create a **new private GitHub repository** for this project; do not mix with existing PrintBridge or GST projects.
- [ ] Commit this handoff package unchanged as an initial architecture draft.
- [ ] Ask Antigravity to inspect the handoff and propose a prioritized implementation plan **before** changing scope.
- [ ] Choose tooling consistent with current Cloudflare recommendations; no billing-enabled service without explicit owner permission.
- [ ] Create isolated development/staging Cloudflare resources; do not use existing production R2 buckets or D1 databases.

## Phase 1 — schema and backend proof of concept

- [ ] Execute and validate migration 0001 on local SQLite and development D1.
- [ ] Implement guest enrollment under event capacity with server-issued hashed sessions and secure cookies.
- [ ] Implement atomic photo/video slot reservations, storage-byte reservations and idempotent retries.
- [ ] Implement private, validated R2 upload path; include multipart/resumable uploads for large videos.
- [ ] Implement R2 upload confirmation, soft deletion, retry/cleanup and abandoned upload expiry.
- [ ] Implement role-based access for Admin/Host/User and event-scoped Guest; add automated tests for unauthorized access.

## Phase 2 — guest web app

- [ ] QR/NFC event route and name-only join.
- [ ] Camera/photo and video recording (format detection, max seconds), plus device photo/video picker.
- [ ] Shared per-guest quotas across camera and gallery uploads.
- [ ] Offline IndexedDB media queue and retries on foreground/resume/reconnect; optional Background Sync where available.
- [ ] Distinguish local pending files from server-confirmed files in UI.
- [ ] Test on multiple Android browsers and iPhone Safari.

## Phase 3 — operations

- [ ] Admin panel: plans/pricing/discounts/booking/payment verification, audit and cost monitoring.
- [ ] Host panel: event settings, quota limits, visibility/reveal, gallery, permissions and export.
- [ ] Guest surface: capture, uploads, offline status and authorized gallery.
- [ ] User panel: customer account/bookings/payment history **subject to product-owner refinement**.
- [ ] Free micro-event abuse controls and high-volume event rate protection.
- [ ] Versioned price quotes and actual usage reconciliation; avoid claiming estimates are bills.
- [ ] Optional Stream adapter only after playback requirements/testing justify its cost.

## Product-owner decisions still needed

- [ ] The exact POV/Lense inspired experience and any differentiating behaviors.
- [ ] Price schedule and plan entitlements (free 5–7 guest target is only a direction).
- [ ] What User (customer) can do versus Host (organizer).
- [ ] Media reveal timing, moderation and download rights.
- [ ] Duration/file caps, thumbnail policy, retention and deletions.
- [ ] Branding, legal terms/privacy/consent and support process.

**Definition of ready for launch:** live real-device trials, successful under-load quota/retry tests, private album authorization tests, measured storage and playback costs, recovery tests and owner approval. No current file claims the product is fully implemented or production-ready.
