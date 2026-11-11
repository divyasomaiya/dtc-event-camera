# Product requirements baseline — DTC Event Camera

**Date:** 11 November 2026  
**Scope:** Proposed engineering layout accepted for planning, with product owner to provide detailed POV/Lense behavior and visual specifications.

## Product purpose

A zero-install, event-based disposable camera-style experience. Guests open a unique event URL via QR code or NFC, enter a name, then use a camera and optional device gallery to contribute photos and/or video clips under the host's limits. No traditional account registration is required for the ordinary guest flow. Privacy and predictable cloud expenses are mandatory.

## Four operational surfaces

| Surface | Access and principal jobs | Identity |
| --- | --- | --- |
| **Admin** | Platform-wide oversight; pricing versions/plans; discounts; manually create bookings; verify manual payments; moderate events; investigate costs and abuse; support | Registered `users` with `admin` role + `admin_profiles` |
| **Host** | Create and configure event; choose photo-only, video-only or combined plan; set allowed quantities/durations; distribute QR/NFC; inspect gallery; reveal content; manage permissions, retention and billing | Registered `users` with `host` role + `host_profiles` |
| **Guest** | Event code → name → camera/gallery; see remaining quotas; capture/upload or delete/retake; check pending/offline state; view/download album when allowed | Event-scoped anonymous `guests` + server-issued `guest_sessions`, not `users` |
| **User** | Proposed ordinary customer portal for account, quotes, purchased bookings and receipts. May later request a host/managed event. **Exact UI/rights not yet specified.** | Registered `users` with `user` role |

A registered account can have more than one role. One guest identity is scoped to a single event and is *not* automatically the same as a registered platform user. A guest can be duplicated by switching devices or clearing cookies; stronger identity checks are optional future controls and may reduce onboarding ease.

## Platforms

- **V1**: A single Android + iOS **HTTPS PWA**, opened in the browser directly from QR/NFC. Mobile-first full-screen-looking UI; browser chrome is not guaranteed to disappear unless installed/standalone.
- In-browser live camera uses `getUserMedia`; use capability detection and MIME checks for video `MediaRecorder`. Photo capture via camera frames. Both may require consent and have device/browser limitations.
- **V2 optional**: Native iOS App Clip + companion iOS app, linked to the same backend. Apple developer enrollment, App Store review and App Clip constraints are separate work and cost. Do not implement the App Clip as an initial deployment prerequisite.

## Ingestion, quotas and offline behavior

- Event packages support **photo only**, **video only**, **photo + video**.
- Configurable guest count, per-guest photo count, video count, clip duration, allowed file sizes, event storage quota, album retention and gallery visibility.
- Camera captures and user-selected gallery files spend the *same* respective photo or video allowance. Uploaded gallery videos also obey duration/size policies.
- Request camera permission only after clear guest action. Capture should work in the active browser with valid permissions; formats vary across phones.
- Cache PWA shell where safe. Queue media locally using IndexedDB on disconnections. Retry when app reopens/resumes; optionally Background Sync on supported platforms. Never promise an upload at the exact instant connectivity returns.
- Show **Pending / Uploading / Uploaded / Failed** per media item. Browser storage may evict queued data; provide clear warnings and recovery behavior.
- Uploads must use idempotent client operation IDs, D1 quota reservations and server-verified R2 completion. Duplicate network retries must not consume extra slots.
- Video uploads should be resumable when needed; R2 multipart uploads are suitable for larger videos.
- Deleting and retaking replenishes quota *after* the server reliably processes deletion; replays and gallery views are controlled separately from upload slots.

## Gallery and privacy

- Keep original photos/videos in private Cloudflare R2 storage. D1 holds IDs, metadata and object references only.
- Support host-mediated reveal and future delayed reveal; exact behavior is pending the owner’s feature brief.
- Issue authorized, time-limited media access. Avoid casually exposing direct permanent object URLs. Download-button restrictions alone cannot prevent screenshots or client-side saving.
- Photo viewing can be relatively generous; protect against automated abuse. Video delivery and download permissions should be controllable by event and guest.
- For ordinary R2 delivery, egress is free but reads and Workers requests may incur costs. Cloudflare Stream is optional and charges per delivery minute. Budget controls based on authorization are not a guarantee of exact final provider bills.

## Packages and pricing

- **Free micro-event**: target 5–7 participants, minimal photo/video counts and short retention. The final limit, anti-abuse policy and availability are not yet finalized.
- Paid plans: photo-only, video-only, combined. Also custom quotes.
- Price engine must use **server-side** quote rules and a versioned pricing snapshot; inputs include reserved guest capacity, photo/video limits, max clip seconds, estimated bytes, chosen processing/streaming mode, retention and costs of API/media operations. Do not promise a precise real cloud bill from an estimate.
- Keep provider cost estimate, safety/ops buffer and customer price distinguishable; customer quotation may be rounded to INR. Track actual provider metrics after each event.
- Discounts: fixed or percentage, personalized/manual, complimentary events where authorized. Manual UPI/bank/cash payments can be admin-verified; never automatically treat a screenshot as proof of payment.
- First-party advertising in guest galleries is not part of V1. Brand/marketing or optional upsell paths can be explored later.

## Services

- **GitHub**: private repository, CI and change history. Not a media store.
- **Cloudflare Workers + Static Assets**: PWA and API.
- **Cloudflare D1**: users, roles, events, guests, quotas, pricing, orders and metadata.
- **Cloudflare R2**: private photos, videos and thumbnails.
- **Cloudflare Stream**: optional *paid* enhancement for processed video delivery, not required for a basic R2 prototype.
- **Oracle / AWS**: optional future backup or migration target; no need to integrate during V1.

## Critical unconfirmed items

1. Exact disposable-camera workflow: whether delete/retake is allowed after upload and whether a guest can view their own photos before reveal.
2. Guest-gallery reveal timing, moderation, and host download/export rules.
3. The boundary between User panel (ordinary customer account) and Host panel (event management).
4. Plan caps/actual selling prices, who pays for overages, data-retention defaults and refund policy.
5. Camera filters/visual brand, design, age/privacy/consent requirements, and offline video policies.
6. Exact video playback guarantees and when paid processing/transcoding should be enabled.

Do not present assumptions here as finalized customer-facing commitments.
