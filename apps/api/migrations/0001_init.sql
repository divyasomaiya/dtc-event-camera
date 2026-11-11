-- DTC Event Camera — foundational Cloudflare D1 migration
-- Draft v0.1 / 2026-11-11. SQLite-compatible; generated IDs come from the API.
-- No photos, videos, raw session tokens, or payment secrets belong in D1.
-- D1 enforces foreign keys; do not attempt PRAGMA foreign_keys=OFF.

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email_normalized TEXT UNIQUE,
  display_name TEXT NOT NULL,
  auth_provider TEXT NOT NULL DEFAULT 'email' CHECK (auth_provider IN ('email','google','apple','manual')),
  auth_subject TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','deleted')),
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
  UNIQUE(auth_provider,auth_subject)
);

-- A registered user can have multiple roles; anonymous guests have no users row.
CREATE TABLE IF NOT EXISTS user_roles (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user','host','admin')),
  granted_at INTEGER NOT NULL DEFAULT (unixepoch()),
  granted_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  PRIMARY KEY (user_id, role)
);

CREATE TABLE IF NOT EXISTS admin_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  title TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS host_profiles (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE RESTRICT,
  display_name TEXT NOT NULL,
  billing_contact_email TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

-- Catalog entries are templates. Purchased entitlements are snapshotted on events.
CREATE TABLE IF NOT EXISTS plans (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  media_mode TEXT NOT NULL CHECK (media_mode IN ('photo','video','both')),
  is_free INTEGER NOT NULL DEFAULT 0 CHECK (is_free IN (0,1)),
  is_public INTEGER NOT NULL DEFAULT 0 CHECK (is_public IN (0,1)),
  guest_capacity INTEGER NOT NULL CHECK (guest_capacity >= 1),
  photo_limit_per_guest INTEGER NOT NULL DEFAULT 0 CHECK (photo_limit_per_guest >= 0),
  video_limit_per_guest INTEGER NOT NULL DEFAULT 0 CHECK (video_limit_per_guest >= 0),
  max_video_seconds INTEGER NOT NULL DEFAULT 0 CHECK (max_video_seconds >= 0),
  max_photo_bytes INTEGER NOT NULL DEFAULT 15000000 CHECK (max_photo_bytes > 0),
  max_video_bytes INTEGER NOT NULL DEFAULT 100000000 CHECK (max_video_bytes > 0),
  storage_quota_bytes INTEGER NOT NULL CHECK (storage_quota_bytes >= 0),
  stream_delivery_quota_seconds INTEGER NOT NULL DEFAULT 0 CHECK (stream_delivery_quota_seconds >= 0),
  retention_days INTEGER NOT NULL CHECK (retention_days >= 1),
  base_price_paise INTEGER NOT NULL DEFAULT 0 CHECK (base_price_paise >= 0),
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
  CHECK ((media_mode IN ('photo','both') OR photo_limit_per_guest = 0) AND
         (media_mode IN ('video','both') OR video_limit_per_guest = 0))
);

-- Server-owned, versioned pricing parameters (not an untrusted client quote).
CREATE TABLE IF NOT EXISTS pricing_versions (
  id TEXT PRIMARY KEY,
  version_label TEXT NOT NULL UNIQUE,
  config_json TEXT NOT NULL CHECK (json_valid(config_json)),
  created_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS discount_codes (
  id TEXT PRIMARY KEY,
  code_normalized TEXT NOT NULL UNIQUE,
  discount_kind TEXT NOT NULL CHECK (discount_kind IN ('percentage','fixed')),
  percentage_bps INTEGER,
  fixed_amount_paise INTEGER,
  assigned_to_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  max_redemptions INTEGER CHECK (max_redemptions IS NULL OR max_redemptions >= 1),
  valid_from INTEGER,
  valid_until INTEGER,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  CHECK ((discount_kind = 'percentage' AND percentage_bps BETWEEN 1 AND 10000 AND fixed_amount_paise IS NULL)
      OR (discount_kind = 'fixed' AND fixed_amount_paise > 0 AND percentage_bps IS NULL))
);

CREATE TABLE IF NOT EXISTS quotes (
  id TEXT PRIMARY KEY,
  requested_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_by_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  plan_id TEXT REFERENCES plans(id) ON DELETE SET NULL,
  pricing_version_id TEXT NOT NULL REFERENCES pricing_versions(id) ON DELETE RESTRICT,
  discount_code_id TEXT REFERENCES discount_codes(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','issued','accepted','expired','cancelled')),
  configuration_json TEXT NOT NULL CHECK (json_valid(configuration_json)),
  cost_estimate_json TEXT NOT NULL CHECK (json_valid(cost_estimate_json)),
  subtotal_paise INTEGER NOT NULL CHECK (subtotal_paise >= 0),
  discount_paise INTEGER NOT NULL DEFAULT 0 CHECK (discount_paise >= 0),
  total_paise INTEGER NOT NULL CHECK (total_paise >= 0),
  currency TEXT NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
  expires_at INTEGER,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  CHECK (discount_paise <= subtotal_paise AND total_paise = subtotal_paise - discount_paise)
);

CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,
  public_code TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  created_by_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  owner_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  host_profile_id TEXT REFERENCES host_profiles(id) ON DELETE SET NULL,
  quote_id TEXT UNIQUE REFERENCES quotes(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','scheduled','live','closed','archived')),
  event_starts_at INTEGER,
  event_ends_at INTEGER,
  timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
  media_mode TEXT NOT NULL CHECK (media_mode IN ('photo','video','both')),
  guest_capacity INTEGER NOT NULL CHECK (guest_capacity >= 1),
  photo_limit_per_guest INTEGER NOT NULL DEFAULT 0 CHECK (photo_limit_per_guest >= 0),
  video_limit_per_guest INTEGER NOT NULL DEFAULT 0 CHECK (video_limit_per_guest >= 0),
  max_video_seconds INTEGER NOT NULL DEFAULT 0 CHECK (max_video_seconds >= 0),
  max_photo_bytes INTEGER NOT NULL CHECK (max_photo_bytes > 0),
  max_video_bytes INTEGER NOT NULL CHECK (max_video_bytes > 0),
  storage_quota_bytes INTEGER NOT NULL CHECK (storage_quota_bytes >= 0),
  stream_delivery_quota_seconds INTEGER NOT NULL DEFAULT 0 CHECK (stream_delivery_quota_seconds >= 0),
  retention_days INTEGER NOT NULL CHECK (retention_days >= 1),
  allow_gallery_upload INTEGER NOT NULL DEFAULT 1 CHECK (allow_gallery_upload IN (0,1)),
  allow_guest_download INTEGER NOT NULL DEFAULT 1 CHECK (allow_guest_download IN (0,1)),
  gallery_reveal_mode TEXT NOT NULL DEFAULT 'host' CHECK (gallery_reveal_mode IN ('immediate','host','scheduled')),
  gallery_reveal_at INTEGER,
  uploads_open_at INTEGER,
  uploads_close_at INTEGER,
  delete_media_after INTEGER,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
  CHECK ((media_mode IN ('photo','both') OR photo_limit_per_guest = 0) AND
         (media_mode IN ('video','both') OR video_limit_per_guest = 0)),
  CHECK (event_ends_at IS NULL OR event_starts_at IS NULL OR event_ends_at >= event_starts_at),
  CHECK (gallery_reveal_mode != 'scheduled' OR gallery_reveal_at IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS event_staff (
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner','manager','viewer')),
  added_at INTEGER NOT NULL DEFAULT (unixepoch()),
  PRIMARY KEY (event_id, user_id)
);

-- Guests are event-scoped pseudonymous identities; one person may rejoin as a new guest
-- after clearing cookies/changing devices. No IP-based person uniqueness is claimed.
CREATE TABLE IF NOT EXISTS guests (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  photo_limit_override INTEGER CHECK (photo_limit_override IS NULL OR photo_limit_override >= 0),
  video_limit_override INTEGER CHECK (video_limit_override IS NULL OR video_limit_override >= 0),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','blocked','left')),
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  last_seen_at INTEGER,
  UNIQUE (event_id,id)
);

-- Store only the hash of an opaque, server-generated session secret.
CREATE TABLE IF NOT EXISTS guest_sessions (
  id TEXT PRIMARY KEY,
  guest_id TEXT NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
  session_token_hash TEXT NOT NULL UNIQUE,
  expires_at INTEGER NOT NULL,
  revoked_at INTEGER,
  last_seen_at INTEGER,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

-- Counts must be changed through atomic conditional statements in the API.
-- The DB itself does not know each guest's effective allowance.
CREATE TABLE IF NOT EXISTS guest_usage (
  guest_id TEXT PRIMARY KEY REFERENCES guests(id) ON DELETE CASCADE,
  photo_reserved INTEGER NOT NULL DEFAULT 0 CHECK (photo_reserved >= 0),
  photo_uploaded INTEGER NOT NULL DEFAULT 0 CHECK (photo_uploaded >= 0),
  video_reserved INTEGER NOT NULL DEFAULT 0 CHECK (video_reserved >= 0),
  video_uploaded INTEGER NOT NULL DEFAULT 0 CHECK (video_uploaded >= 0),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS event_usage (
  event_id TEXT PRIMARY KEY REFERENCES events(id) ON DELETE CASCADE,
  reserved_storage_bytes INTEGER NOT NULL DEFAULT 0 CHECK (reserved_storage_bytes >= 0),
  used_storage_bytes INTEGER NOT NULL DEFAULT 0 CHECK (used_storage_bytes >= 0),
  reserved_stream_seconds INTEGER NOT NULL DEFAULT 0 CHECK (reserved_stream_seconds >= 0),
  authorized_stream_seconds INTEGER NOT NULL DEFAULT 0 CHECK (authorized_stream_seconds >= 0),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

-- R2 keys refer to private objects; bytes NEVER go in this table.
CREATE TABLE IF NOT EXISTS media_items (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  guest_id TEXT NOT NULL,
  client_upload_id TEXT NOT NULL,
  media_kind TEXT NOT NULL CHECK (media_kind IN ('photo','video')),
  source_kind TEXT NOT NULL CHECK (source_kind IN ('camera','gallery')),
  status TEXT NOT NULL DEFAULT 'reserved' CHECK (status IN ('reserved','uploading','uploaded','processing','ready','failed','deleting','deleted')),
  storage_provider TEXT NOT NULL DEFAULT 'r2' CHECK (storage_provider IN ('r2','oracle','s3')),
  object_key TEXT UNIQUE,
  thumbnail_object_key TEXT UNIQUE,
  mime_type TEXT,
  reserved_bytes INTEGER NOT NULL CHECK (reserved_bytes >= 0),
  size_bytes INTEGER CHECK (size_bytes IS NULL OR size_bytes >= 0),
  duration_ms INTEGER CHECK (duration_ms IS NULL OR duration_ms >= 0),
  width_px INTEGER CHECK (width_px IS NULL OR width_px > 0),
  height_px INTEGER CHECK (height_px IS NULL OR height_px > 0),
  upload_expires_at INTEGER,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  uploaded_at INTEGER,
  deleted_at INTEGER,
  UNIQUE (guest_id,client_upload_id),
  FOREIGN KEY (event_id,guest_id) REFERENCES guests(event_id,id) ON DELETE CASCADE,
  CHECK ((media_kind = 'video') OR duration_ms IS NULL)
);

-- Aggregate grants, not a per-view log table: cheap tracking and enforcement.
-- In practice, delivery provider billing may lag behind these authorized counters.
CREATE TABLE IF NOT EXISTS guest_delivery_daily (
  guest_id TEXT NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
  usage_day TEXT NOT NULL,
  downloads_authorized INTEGER NOT NULL DEFAULT 0 CHECK (downloads_authorized >= 0),
  video_seconds_authorized INTEGER NOT NULL DEFAULT 0 CHECK (video_seconds_authorized >= 0),
  media_requests_authorized INTEGER NOT NULL DEFAULT 0 CHECK (media_requests_authorized >= 0),
  PRIMARY KEY (guest_id, usage_day)
);

CREATE TABLE IF NOT EXISTS event_delivery_daily (
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  usage_day TEXT NOT NULL,
  downloads_authorized INTEGER NOT NULL DEFAULT 0 CHECK (downloads_authorized >= 0),
  video_seconds_authorized INTEGER NOT NULL DEFAULT 0 CHECK (video_seconds_authorized >= 0),
  media_requests_authorized INTEGER NOT NULL DEFAULT 0 CHECK (media_requests_authorized >= 0),
  PRIMARY KEY (event_id, usage_day)
);

CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY,
  quote_id TEXT NOT NULL UNIQUE REFERENCES quotes(id) ON DELETE RESTRICT,
  event_id TEXT UNIQUE REFERENCES events(id) ON DELETE SET NULL,
  customer_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  customer_display_name TEXT,
  customer_contact TEXT,
  created_by_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','cancelled','refunded')),
  payment_channel TEXT NOT NULL DEFAULT 'manual' CHECK (payment_channel IN ('manual','gateway','free')),
  total_paise INTEGER NOT NULL CHECK (total_paise >= 0),
  currency TEXT NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  paid_at INTEGER
);

CREATE TABLE IF NOT EXISTS payments (
  id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  method TEXT NOT NULL CHECK (method IN ('upi_manual','bank_transfer','cash','gateway','other')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','verified','rejected','refunded')),
  amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
  payment_reference TEXT,
  payment_proof_object_key TEXT,
  verified_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  paid_at INTEGER,
  verified_at INTEGER,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS discount_redemptions (
  id TEXT PRIMARY KEY,
  discount_code_id TEXT NOT NULL REFERENCES discount_codes(id) ON DELETE RESTRICT,
  order_id TEXT NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
  redeemed_by_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

-- Use these to retry deletion of R2 media after expiry or deletion requests.
CREATE TABLE IF NOT EXISTS cleanup_jobs (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  media_id TEXT REFERENCES media_items(id) ON DELETE SET NULL,
  task_kind TEXT NOT NULL CHECK (task_kind IN ('delete_media','delete_expired_event','reconcile_upload')),
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','running','done','failed')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  due_at INTEGER NOT NULL,
  last_error TEXT,
  completed_at INTEGER,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id TEXT PRIMARY KEY,
  actor_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  event_id TEXT REFERENCES events(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  detail_json TEXT CHECK (detail_json IS NULL OR json_valid(detail_json)),
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_user_roles_role ON user_roles(role);
CREATE INDEX IF NOT EXISTS idx_events_owner ON events(owner_user_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_host ON events(host_profile_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status,event_starts_at);
CREATE INDEX IF NOT EXISTS idx_event_staff_user ON event_staff(user_id);
CREATE INDEX IF NOT EXISTS idx_guests_event ON guests(event_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_guest_sessions_guest ON guest_sessions(guest_id,expires_at);
CREATE INDEX IF NOT EXISTS idx_media_event_status ON media_items(event_id,status,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_media_guest_status ON media_items(guest_id,status,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_media_reservation_expiry ON media_items(status,upload_expires_at);
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(customer_user_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id,status);
CREATE INDEX IF NOT EXISTS idx_discount_redemptions_code ON discount_redemptions(discount_code_id);
CREATE INDEX IF NOT EXISTS idx_cleanup_due ON cleanup_jobs(status,due_at);
CREATE INDEX IF NOT EXISTS idx_audit_event ON audit_logs(event_id,created_at DESC);
