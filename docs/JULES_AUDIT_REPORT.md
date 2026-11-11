# Technical Audit Report: DTC Event Camera Foundation

**Author:** Jules (First Development Agent)
**Date:** November 2026
**Audited Artifacts:**
- `apps/api/migrations/0001_init.sql` (Foundational draft D1 migration)
- `scripts/validate_schema.py` (Local SQLite integrity test suite)
- `docs/PRODUCT_SPEC.md`
- `docs/DATA_MODEL.md`
- `docs/HANDOFF_CHECKLIST.md`

---

## 1. Executive Summary

This report establishes the baseline technical audit for **DTC Event Camera**, a zero-install guest photo/video capture platform designed for weddings and social events.

The audit verified the relational schema design, identity isolation across the four product surfaces (Admin, Host, Guest, and User), atomic quota reservation semantics, server-issued anonymous guest session tokens, and the security boundary between Cloudflare D1 (metadata) and private Cloudflare R2 (media bytes).

All local in-memory SQLite smoke tests have passed, covering 22 tables, foreign key cascades, and check constraints. Critical architectural findings and concurrency risks specific to Cloudflare D1 have been identified and documented below for continuation by **Google Antigravity**.

---

## 2. Four Surface Identity and Relationship Audit

The product requirements define four distinct surfaces:

1. **Admin Surface (`users` with `user_roles.role = 'admin'` + `admin_profiles`):**
   - Platform-wide operational oversight, pricing version definitions, discount management, manual booking creation, and manual payment verification.
2. **Host Surface (`users` with `user_roles.role = 'host'` + `host_profiles`):**
   - Event creation, plan selection, QR/NFC management, gallery inspection, reveal controls, and retention configuration.
3. **User Surface (`users` with `user_roles.role = 'user'`):**
   - Registered customer portal representing the purchasing entity. A registered account can hold both `user` and `host` roles, or separate customer accounts can exist independently of event organizers.
4. **Guest Surface (`guests` + `guest_sessions`):**
   - Anonymous, event-scoped participants. Guests **do not** have rows in `users`.
   - Identification is strictly via an event-scoped name input and an opaque, server-issued session secret whose hash is stored in `guest_sessions.session_token_hash`.
   - Never trust client-minted tokens or IP addresses for identity or quota tracking.

### Relationship & Key Findings:
- Foreign key `media_items (event_id, guest_id) REFERENCES guests(event_id, id) ON DELETE CASCADE` properly enforces composite integrity, preventing a guest from attaching media items to an event they are not enrolled in.
- `guests.status` and `guest_sessions.revoked_at` allow immediate blocking/revocation of malicious guest sessions.
- `admin_profiles.user_id` and `host_profiles.user_id` cleanly link role-specific profile data to registered `users`.

---

## 3. Schema & Constraint Audit (`0001_init.sql`)

### 3.1 Integrity and Indices
- **Total Tables:** 22 tables properly created.
- **Foreign Keys:** 38 foreign key constraints verified with `PRAGMA foreign_key_check` returning 0 errors.
- **Indices:** Crucial query paths are covered, including:
  - `guest_sessions.session_token_hash` (backed by unique auto-index for $O(1)$ token authentication lookups).
  - `media_items (guest_id, client_upload_id)` (backed by unique auto-index for idempotent upload requests).
  - `events(status, event_starts_at)` and `events(owner_user_id, created_at DESC)`.
  - `cleanup_jobs(status, due_at)` for background queue sweeps.

### 3.2 Atomic Quotas and Idempotency
- Quota reservations are separated into photo and video limits in `guest_usage` and total storage bytes in `event_usage`.
- Upload requests require a client-generated UUID (`client_upload_id`) stored in `media_items(guest_id, client_upload_id)` with a unique constraint. Retried requests do not consume duplicate reservation slots.
- Status progression: `reserved -> uploading -> uploaded -> ready` (or `failed` / `deleting` / `deleted`).
- Check constraint `CHECK ((media_kind = 'video') OR duration_ms IS NULL)` properly prevents photo records from specifying video duration metadata.

### 3.3 Financial Calculations & Discount Constraints
- All currency values are strictly stored as integer paise (`INR`).
- `quotes` enforces `CHECK (discount_paise <= subtotal_paise AND total_paise = subtotal_paise - discount_paise)`.
- `discount_codes` enforces exclusivity between `percentage` (basis points 1–10000) and `fixed` (positive integer paise).

---

## 4. D1 vs. SQLite Concurrency & Operational Realities

While the local test runner uses Python's standard `sqlite3` engine in-memory, Cloudflare D1 introduces specific runtime nuances:

1. **Transactional Execution:**
   - D1 does not support long-lived interactive transactions (`BEGIN TRANSACTION ... interactive queries ... COMMIT`) over HTTP/Worker calls.
   - Atomic multi-statement transactions in D1 must be executed using the batch API: `env.DB.batch([stmt1, stmt2, stmt3])`.
   - The batch execution runs within an atomic transaction inside D1. If any conditional update affects 0 rows, the Worker API logic must inspect the returning count or result rows and fail the batch appropriately.
2. **Read Replication & Eventual Consistency:**
   - D1 supports read replication. Mutations run on the primary database, but subsequent reads directed to replicas might lag unless sessions/bookmarks are maintained. For quota checks, read-your-own-writes consistency is mandatory.
3. **Database Size Limit:**
   - Cloudflare D1 Free Tier imposes a 500 MB per-database limit (and 5 GB total account storage).
   - **Crucial Rule:** Binary media bytes (images, videos, audio) must **never** be stored in D1. Only metadata, object keys, and quota counters belong in D1. All media belongs in private Cloudflare R2 buckets.

---

## 5. Media & Storage Architecture: Cloudflare R2

1. **Direct-to-R2 Upload Pattern:**
   - Client requests upload reservation from Worker API (`POST /api/events/:code/uploads/reserve`).
   - Worker verifies session, checks quota atomically via D1 batch, creates `reserved` row in `media_items`, and mints a short-lived presigned R2 PUT URL.
   - Client uploads binary data directly to R2 using the presigned URL.
   - Client notifies Worker of upload completion (`POST /api/events/:code/uploads/confirm`). Worker checks R2 object metadata (size, mime type), updates `media_items` status to `uploaded`/`ready`, decrements reserved counters, and increments uploaded counters.
2. **Access & Gallery Delivery:**
   - The R2 bucket is strictly private (no public bucket access).
   - Authorized gallery views and media downloads are granted via Worker endpoints issuing short-lived signed URLs or streaming R2 object bodies directly with proper authentication and headers.
3. **Replaceable Video Processing Adapter:**
   - V1 stores and serves camera-captured and uploaded video originals directly via R2.
   - Cloudflare Stream or third-party transcoding services are kept behind a modular adapter interface to avoid vendor lock-in and unexpected bills.

---

## 6. Security & Privacy Audit Findings

1. **Session Storage:**
   - Raw session tokens are never stored in D1. The database stores only SHA-256 hashes of server-minted tokens.
   - Sessions in production must be transferred via `Secure`, `HttpOnly`, `SameSite=Strict` cookies or `Authorization: Bearer` headers.
2. **No IP Address Tracking as Identity:**
   - The system does not attempt to enforce 1-person-1-guest via IP address tracking. Guests are anonymous per event. Switching browsers or clearing cookies generates a new guest session; abuse mitigation is handled via event-level guest capacity (`guest_capacity`).
3. **Payment Security:**
   - For manual payments (UPI/bank transfer), payment reference codes and screenshot object keys in private R2 are stored. No card details or banking credentials are saved in D1.
   - Manual payments require manual verification by an Admin before orders transition to `paid`.

---

## 7. Phased Implementation Roadmap for Antigravity

- **Phase 1: Backend API & D1/R2 Integration (Recommended First Coding Task)**
  - Scaffold Cloudflare Worker project with TypeScript and Hono / itty-router.
  - Implement guest join endpoint (`POST /api/events/:code/join`) generating server-issued hashed session tokens.
  - Implement atomic media reservation batch endpoint (`POST /api/events/:code/uploads/reserve`) and R2 presigned PUT generation.
  - Implement upload confirmation (`POST /api/events/:code/uploads/confirm`) and deletion/cleanup workers.
- **Phase 2: Single Android + iPhone PWA**
  - Implement mobile-first responsive PWA shell with offline asset caching.
  - In-browser camera capture using `navigator.mediaDevices.getUserMedia` and video capture via `MediaRecorder`.
  - IndexedDB offline queue for media with foreground retry when online.
- **Phase 3: Host & Admin Portals**
  - Host event creation, QR code generator, and gallery reveal controls.
  - Admin pricing version editor, discount manager, and payment verification queue.
