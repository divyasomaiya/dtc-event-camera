#!/usr/bin/env python3
"""Local SQLite smoke test for the foundational D1 migration (not live D1)."""
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


def main():
    db = sqlite3.connect(":memory:")
    db.execute("PRAGMA foreign_keys=ON")
    db.executescript(SQL.read_text())
    assert db.execute("PRAGMA foreign_key_check").fetchall() == []
    tables = [row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")]
    print(f"PASS migration: {len(tables)} tables created with no broken foreign keys")

    db.execute("INSERT INTO users(id,email_normalized,display_name) VALUES ('u_admin','admin@example.test','Admin')")
    db.execute("INSERT INTO users(id,email_normalized,display_name) VALUES ('u_host','host@example.test','Host')")
    db.execute("INSERT INTO user_roles(user_id,role) VALUES ('u_admin','admin'),('u_host','user'),('u_host','host')")
    db.execute("INSERT INTO admin_profiles(user_id) VALUES ('u_admin')")
    db.execute("INSERT INTO host_profiles(id,user_id,display_name) VALUES ('hp_1','u_host','Test Host')")
    db.execute("INSERT INTO pricing_versions(id,version_label,config_json) VALUES ('pv_1','0.1','{}')")
    db.execute("""INSERT INTO plans(id,slug,name,media_mode,is_free,guest_capacity,
        photo_limit_per_guest,video_limit_per_guest,max_video_seconds,storage_quota_bytes,retention_days)
        VALUES ('p_1','free-mini-draft','Free Mini','both',1,7,5,1,10,1000000000,3)""")
    db.execute("""INSERT INTO quotes(id,created_by_user_id,plan_id,pricing_version_id,
        configuration_json,cost_estimate_json,subtotal_paise,total_paise)
        VALUES ('q_1','u_host','p_1','pv_1','{}','{}',0,0)""")
    db.execute("""INSERT INTO events(id,public_code,title,created_by_user_id,owner_user_id,
        host_profile_id,quote_id,status,media_mode,guest_capacity,photo_limit_per_guest,
        video_limit_per_guest,max_video_seconds,max_photo_bytes,max_video_bytes,
        storage_quota_bytes,retention_days)
        VALUES ('e_1','EVENT7','Test Wedding','u_host','u_host','hp_1','q_1','live',
        'both',7,5,1,10,15000000,30000000,1000000000,3)""")
    db.execute("INSERT INTO guests(id,event_id,display_name) VALUES ('g_1','e_1','Example Guest')")
    db.execute("INSERT INTO guest_sessions(id,guest_id,session_token_hash,expires_at) VALUES ('s_1','g_1','hashed-token',1999999999)")
    db.execute("INSERT INTO guest_usage(guest_id) VALUES ('g_1')")
    db.execute("INSERT INTO event_usage(event_id) VALUES ('e_1')")

    must_fail(lambda: db.execute("INSERT INTO guests(id,event_id,display_name) VALUES ('g_bad','missing','Guest')"), "foreign key")
    must_fail(lambda: db.execute("INSERT INTO guest_sessions(id,guest_id,session_token_hash,expires_at) VALUES ('s_2','g_1','hashed-token',1999999999)"), "unique session hash")
    must_fail(lambda: db.execute("INSERT INTO media_items(id,event_id,guest_id,client_upload_id,media_kind,source_kind,reserved_bytes) VALUES ('m_bad','missing','g_1','c_bad','photo','camera',3000000)"), "cross-event media FK")

    # Atomic reservation rule: 5 shots accepted, sixth refused. Delete/release
    # lifecycle is an API responsibility; this exercises only the SQL guard.
    reserve_sql = """UPDATE guest_usage SET photo_reserved = photo_reserved + 1
      WHERE guest_id='g_1' AND photo_reserved + photo_uploaded < (
      SELECT COALESCE(g.photo_limit_override,e.photo_limit_per_guest)
      FROM guests g JOIN events e ON e.id=g.event_id
      WHERE g.id=guest_usage.guest_id AND g.status='active' AND e.status='live')
      RETURNING guest_id"""
    for _ in range(5):
        assert db.execute(reserve_sql).fetchone() == ('g_1',)
    assert db.execute(reserve_sql).fetchone() is None
    print("PASS photo quota: sixth reservation rejected")

    db.execute("""INSERT INTO media_items(id,event_id,guest_id,client_upload_id,media_kind,source_kind,status,reserved_bytes)
        VALUES ('m_1','e_1','g_1','client-uuid-1','photo','camera','reserved',3000000)""")
    must_fail(lambda: db.execute("""INSERT INTO media_items(id,event_id,guest_id,client_upload_id,media_kind,source_kind,reserved_bytes)
        VALUES ('m_dup','e_1','g_1','client-uuid-1','photo','gallery',3000000)"""), "upload idempotency uniqueness")
    db.execute("INSERT INTO orders(id,quote_id,event_id,created_by_user_id,total_paise) VALUES ('o_1','q_1','e_1','u_admin',0)")
    db.execute("INSERT INTO discount_codes(id,code_normalized,discount_kind,percentage_bps) VALUES ('d_1','WELCOME10','percentage',1000)")
    db.execute("INSERT INTO discount_redemptions(id,discount_code_id,order_id) VALUES ('r_1','d_1','o_1')")
    assert db.execute("PRAGMA foreign_key_check").fetchall() == []
    print("PASS purchase linkage and referential integrity")
    db.close()
    print("All SQLite smoke tests passed. Live Cloudflare D1 and concurrency tests remain required.")


if __name__ == '__main__':
    main()
