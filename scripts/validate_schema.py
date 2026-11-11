#!/usr/bin/env python3
"""Local SQLite smoke and constraint test suite for the foundational D1 migration (not live D1)."""
from pathlib import Path
import sqlite3

SQL = Path(__file__).resolve().parents[1] / "apps/api/migrations/0001_init.sql"


def must_fail(fn, name):
    try:
        fn()
    except sqlite3.IntegrityError:
        print(f"PASS {name}: constraint rejected invalid input")
    else:
        raise AssertionError(f"FAIL {name}: invalid input was accepted")


def setup_test_db():
    db = sqlite3.connect(":memory:")
    db.execute("PRAGMA foreign_keys=ON")
    db.executescript(SQL.read_text())
    assert db.execute("PRAGMA foreign_key_check").fetchall() == []
    return db


def test_four_surfaces_and_roles(db):
    """Test identity boundaries between Admin, Host, Guest, and User surfaces."""
    # 1. Registered users with distinct surface roles
    db.execute("INSERT INTO users(id,email_normalized,display_name) VALUES ('u_admin','admin@example.test','Admin User')")
    db.execute("INSERT INTO users(id,email_normalized,display_name) VALUES ('u_host','host@example.test','Host User')")
    db.execute("INSERT INTO users(id,email_normalized,display_name) VALUES ('u_customer','customer@example.test','Customer User')")

    # User roles: admin surface, host surface, ordinary user surface
    db.execute("INSERT INTO user_roles(user_id,role) VALUES ('u_admin','admin')")
    db.execute("INSERT INTO user_roles(user_id,role) VALUES ('u_host','user'),('u_host','host')")
    db.execute("INSERT INTO user_roles(user_id,role) VALUES ('u_customer','user')")

    # Associated profiles
    db.execute("INSERT INTO admin_profiles(user_id,title) VALUES ('u_admin','Super Admin')")
    db.execute("INSERT INTO host_profiles(id,user_id,display_name) VALUES ('hp_1','u_host','Premier Events Host')")

    # Anonymous guest is event-scoped, not a registered user
    db.execute("INSERT INTO pricing_versions(id,version_label,config_json) VALUES ('pv_1','1.0','{}')")
    db.execute("""INSERT INTO plans(id,slug,name,media_mode,is_free,guest_capacity,
        photo_limit_per_guest,video_limit_per_guest,max_video_seconds,storage_quota_bytes,retention_days)
        VALUES ('p_1','mini-photo','Mini Photo','photo',1,10,5,0,0,500000000,3)""")
    db.execute("""INSERT INTO events(id,public_code,title,created_by_user_id,owner_user_id,
        host_profile_id,status,media_mode,guest_capacity,photo_limit_per_guest,
        video_limit_per_guest,max_video_seconds,max_photo_bytes,max_video_bytes,
        storage_quota_bytes,retention_days)
        VALUES ('e_1','EVT001','Wedding 2026','u_host','u_host','hp_1','live',
        'photo',10,5,0,0,15000000,30000000,500000000,3)""")

    # Guest joins event anonymously with server-issued session
    db.execute("INSERT INTO guests(id,event_id,display_name) VALUES ('g_1','e_1','Alice Guest')")
    db.execute("INSERT INTO guest_sessions(id,guest_id,session_token_hash,expires_at) VALUES ('s_1','g_1','hash_alice_session',2000000000)")
    db.execute("INSERT INTO guest_usage(guest_id) VALUES ('g_1')")
    db.execute("INSERT INTO event_usage(event_id) VALUES ('e_1')")

    # Reject duplicate session token hash
    must_fail(lambda: db.execute("INSERT INTO guest_sessions(id,guest_id,session_token_hash,expires_at) VALUES ('s_dup','g_1','hash_alice_session',2000000000)"), "duplicate session token hash")

    # Reject invalid role string
    must_fail(lambda: db.execute("INSERT INTO user_roles(user_id,role) VALUES ('u_admin','superuser')"), "invalid user role enum")

    # Guest capacity guard SQL check
    join_guest_sql = """INSERT INTO guests(id,event_id,display_name)
      SELECT ?, ?, ?
      WHERE (SELECT COUNT(*) FROM guests WHERE event_id = ?) < (SELECT guest_capacity FROM events WHERE id = ?)
      RETURNING id"""
    # e_1 capacity is 10. We already have g_1 (count 1). Insert 9 more:
    for i in range(2, 11):
        res = db.execute(join_guest_sql, (f'g_{i}', 'e_1', f'Guest {i}', 'e_1', 'e_1')).fetchone()
        assert res == (f'g_{i}',), f"Guest {i} enrollment failed"
    # 11th guest exceeds capacity of 10 and must return None
    res_exceeded = db.execute(join_guest_sql, ('g_11', 'e_1', 'Guest 11', 'e_1', 'e_1')).fetchone()
    assert res_exceeded is None, "Guest enrollment succeeded despite exceeding guest_capacity"
    print("PASS guest capacity: 10 allowed, 11th rejected")

    print("PASS four surfaces: Admin, Host, Guest, and User roles verified")


def test_atomic_reservations_and_limits(db):
    """Test photo, video, and storage conditional update patterns."""
    # Create combined event with photo limit 3 and video limit 2
    db.execute("""INSERT INTO events(id,public_code,title,created_by_user_id,owner_user_id,
        status,media_mode,guest_capacity,photo_limit_per_guest,
        video_limit_per_guest,max_video_seconds,max_photo_bytes,max_video_bytes,
        storage_quota_bytes,retention_days)
        VALUES ('e_combo','EVT002','Combined Event','u_host','u_host','live',
        'both',5,3,2,15,15000000,50000000,100000000,7)""")
    db.execute("INSERT INTO guests(id,event_id,display_name) VALUES ('g_combo','e_combo','Bob Guest')")
    db.execute("INSERT INTO guest_usage(guest_id) VALUES ('g_combo')")
    db.execute("INSERT INTO event_usage(event_id) VALUES ('e_combo')")

    # Photo reservation pattern
    reserve_photo_sql = """UPDATE guest_usage SET photo_reserved = photo_reserved + 1
      WHERE guest_id = 'g_combo' AND photo_reserved + photo_uploaded < (
        SELECT COALESCE(g.photo_limit_override, e.photo_limit_per_guest)
        FROM guests g JOIN events e ON e.id = g.event_id
        WHERE g.id = guest_usage.guest_id AND g.status = 'active' AND e.status = 'live'
      )
      RETURNING guest_id"""

    for i in range(3):
        assert db.execute(reserve_photo_sql).fetchone() == ('g_combo',), f"Photo reservation {i+1} failed"
    # 4th photo must be rejected
    assert db.execute(reserve_photo_sql).fetchone() is None
    print("PASS photo quota: 3 permitted, 4th rejected")

    # Video reservation pattern
    reserve_video_sql = """UPDATE guest_usage SET video_reserved = video_reserved + 1
      WHERE guest_id = 'g_combo' AND video_reserved + video_uploaded < (
        SELECT COALESCE(g.video_limit_override, e.video_limit_per_guest)
        FROM guests g JOIN events e ON e.id = g.event_id
        WHERE g.id = guest_usage.guest_id AND g.status = 'active' AND e.status = 'live'
      )
      RETURNING guest_id"""

    for i in range(2):
        assert db.execute(reserve_video_sql).fetchone() == ('g_combo',), f"Video reservation {i+1} failed"
    # 3rd video must be rejected
    assert db.execute(reserve_video_sql).fetchone() is None
    print("PASS video quota: 2 permitted, 3rd rejected")

    # Event storage byte reservation pattern
    reserve_bytes_sql = """UPDATE event_usage
      SET reserved_storage_bytes = reserved_storage_bytes + ?,
          updated_at = unixepoch()
      WHERE event_id = ?
        AND used_storage_bytes + reserved_storage_bytes + ? <= (
          SELECT storage_quota_bytes FROM events WHERE id = event_usage.event_id
        )
      RETURNING event_id"""

    # e_combo has 100,000,000 bytes storage quota. Reserve 60,000,000 -> OK
    assert db.execute(reserve_bytes_sql, (60000000, 'e_combo', 60000000)).fetchone() == ('e_combo',)
    # Reserve another 30,000,000 -> OK (total 90,000,000)
    assert db.execute(reserve_bytes_sql, (30000000, 'e_combo', 30000000)).fetchone() == ('e_combo',)
    # Reserve another 20,000,000 -> REJECTED (90M + 20M = 110M > 100M)
    assert db.execute(reserve_bytes_sql, (20000000, 'e_combo', 20000000)).fetchone() is None
    print("PASS event storage quota: byte-level guard rejected excess reservation")


def test_media_lifecycle_and_idempotency(db):
    """Test media item state transitions, client upload ID idempotency, and duration checks."""
    # Valid reservation
    db.execute("""INSERT INTO media_items(id,event_id,guest_id,client_upload_id,media_kind,source_kind,status,reserved_bytes)
        VALUES ('m_10','e_combo','g_combo','client-up-10','photo','camera','reserved',5000000)""")

    # Same client_upload_id for same guest must fail (Idempotency)
    must_fail(lambda: db.execute("""INSERT INTO media_items(id,event_id,guest_id,client_upload_id,media_kind,source_kind,status,reserved_bytes)
        VALUES ('m_10_dup','e_combo','g_combo','client-up-10','photo','gallery','reserved',5000000)"""), "duplicate client_upload_id for same guest")

    # Cross-event reference must fail
    must_fail(lambda: db.execute("""INSERT INTO media_items(id,event_id,guest_id,client_upload_id,media_kind,source_kind,status,reserved_bytes)
        VALUES ('m_cross','e_1','g_combo','client-up-11','photo','camera','reserved',5000000)"""), "cross-event guest_id / event_id FK mismatch")

    # Photo cannot have duration_ms (CHECK constraint)
    must_fail(lambda: db.execute("""INSERT INTO media_items(id,event_id,guest_id,client_upload_id,media_kind,source_kind,status,reserved_bytes,duration_ms)
        VALUES ('m_dur_bad','e_combo','g_combo','client-up-12','photo','camera','reserved',5000000,1000)"""), "photo media_item with duration_ms")

    # Video can have duration_ms
    db.execute("""INSERT INTO media_items(id,event_id,guest_id,client_upload_id,media_kind,source_kind,status,reserved_bytes,duration_ms)
        VALUES ('m_vid_1','e_combo','g_combo','client-up-13','video','camera','reserved',25000000,12000)""")

    # Lifecycle transition: reserved -> uploading -> uploaded -> ready
    db.execute("UPDATE media_items SET status='uploading' WHERE id='m_10'")
    db.execute("UPDATE media_items SET status='uploaded', object_key='e_combo/photos/m_10.jpg', size_bytes=4200000 WHERE id='m_10'")
    db.execute("UPDATE media_items SET status='ready' WHERE id='m_10'")
    assert db.execute("SELECT status, size_bytes FROM media_items WHERE id='m_10'").fetchone() == ('ready', 4200000)

    # Invalid status enum
    must_fail(lambda: db.execute("UPDATE media_items SET status='published' WHERE id='m_10'"), "invalid media_item status enum")

    print("PASS media lifecycle, idempotency and format checks verified")


def test_discount_codes_and_quotes(db):
    """Test percentage vs fixed discount checks and quote pricing math."""
    # Percentage discount requires percentage_bps BETWEEN 1 AND 10000 and fixed_amount_paise IS NULL
    db.execute("INSERT INTO discount_codes(id,code_normalized,discount_kind,percentage_bps) VALUES ('dc_pct','SAVE20','percentage',2000)")
    must_fail(lambda: db.execute("INSERT INTO discount_codes(id,code_normalized,discount_kind,percentage_bps) VALUES ('dc_bad_pct','SAVE150','percentage',15000)"), "percentage > 100%")
    must_fail(lambda: db.execute("INSERT INTO discount_codes(id,code_normalized,discount_kind,percentage_bps,fixed_amount_paise) VALUES ('dc_mix','MIX','percentage',1000,500)"), "mixed discount kind fields")

    # Fixed discount requires fixed_amount_paise > 0 and percentage_bps IS NULL
    db.execute("INSERT INTO discount_codes(id,code_normalized,discount_kind,fixed_amount_paise) VALUES ('dc_fix','FLAT500','fixed',50000)")
    must_fail(lambda: db.execute("INSERT INTO discount_codes(id,code_normalized,discount_kind,fixed_amount_paise) VALUES ('dc_zero','ZERO','fixed',0)"), "fixed discount <= 0")

    # Quote arithmetic check: total_paise = subtotal_paise - discount_paise
    db.execute("""INSERT INTO quotes(id,created_by_user_id,pricing_version_id,configuration_json,cost_estimate_json,
        subtotal_paise,discount_paise,total_paise)
        VALUES ('q_valid','u_host','pv_1','{}','{}',100000,20000,80000)""")
    must_fail(lambda: db.execute("""INSERT INTO quotes(id,created_by_user_id,pricing_version_id,configuration_json,cost_estimate_json,
        subtotal_paise,discount_paise,total_paise)
        VALUES ('q_math_err','u_host','pv_1','{}','{}',100000,20000,75000)"""), "quote total_paise arithmetic mismatch")

    print("PASS discounts and quotes arithmetic checks verified")


def main():
    db = setup_test_db()
    tables = [row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")]
    print(f"PASS migration: {len(tables)} tables created with no broken foreign keys")

    test_four_surfaces_and_roles(db)
    test_atomic_reservations_and_limits(db)
    test_media_lifecycle_and_idempotency(db)
    test_discount_codes_and_quotes(db)

    # Ensure no lingering foreign key violations across all test steps
    fk_violations = db.execute("PRAGMA foreign_key_check").fetchall()
    assert fk_violations == [], f"Lingering foreign key violations: {fk_violations}"
    print("PASS final foreign key integrity check cleanly completed")

    db.close()
    print("All SQLite smoke & constraint tests passed. Live Cloudflare D1 and concurrency tests remain required.")


if __name__ == '__main__':
    main()
