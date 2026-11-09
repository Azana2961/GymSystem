const fs = require('fs');
const path = require('path');
const Database = require(path.join(__dirname, '..', 'backend', 'node_modules', 'better-sqlite3'));

const cleanDbPath = path.join(__dirname, 'staging', 'backend', 'gym_backend.db');
if (fs.existsSync(cleanDbPath)) {
  fs.unlinkSync(cleanDbPath);
}

// Also remove wal / shm files if any
const walPath = cleanDbPath + '-wal';
const shmPath = cleanDbPath + '-shm';
if (fs.existsSync(walPath)) fs.unlinkSync(walPath);
if (fs.existsSync(shmPath)) fs.unlinkSync(shmPath);

const db = new Database(cleanDbPath);
db.pragma('journal_mode = DELETE');

db.exec(`
  CREATE TABLE IF NOT EXISTS members (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    phone       TEXT,
    email       TEXT,
    plan        TEXT NOT NULL,
    expiry_date TEXT NOT NULL,
    status      TEXT NOT NULL,
    qr_token    TEXT UNIQUE NOT NULL,
    qr_path     TEXT,
    gender      TEXT,
    notes       TEXT,
    due_amount  REAL DEFAULT 0,
    paid_amount REAL DEFAULT 0,
    created_at  TEXT DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS attendance (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    member_id     TEXT,
    qr_token      TEXT NOT NULL,
    member_name   TEXT NOT NULL,
    status        TEXT NOT NULL,
    visitor_photo TEXT,
    scanned_at    TEXT NOT NULL,
    created_at    TEXT DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS whatsapp_queue (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    member_id       TEXT,
    recipient_phone TEXT NOT NULL,
    message_text    TEXT NOT NULL,
    message_type    TEXT DEFAULT 'custom',
    image_path      TEXT,
    status          TEXT DEFAULT 'pending',
    delay_seconds   REAL DEFAULT 0,
    attempts        INTEGER DEFAULT 0,
    last_error      TEXT,
    created_at      TEXT DEFAULT CURRENT_TIMESTAMP,
    processed_at    TEXT
  );

  CREATE TABLE IF NOT EXISTS whatsapp_logs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    queue_id        INTEGER,
    member_id       TEXT,
    recipient_phone TEXT NOT NULL,
    message_text    TEXT NOT NULL,
    message_type    TEXT,
    status          TEXT NOT NULL,
    delay_used_sec  REAL DEFAULT 0,
    error           TEXT,
    created_at      TEXT DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS whatsapp_settings (
    key             TEXT PRIMARY KEY,
    value           TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS tablet_devices (
    device_id       TEXT PRIMARY KEY,
    device_name     TEXT,
    ip_address      TEXT,
    battery_level   REAL,
    app_version     TEXT,
    last_seen       TEXT DEFAULT CURRENT_TIMESTAMP,
    total_scans     INTEGER DEFAULT 0
  );

  CREATE INDEX IF NOT EXISTS idx_members_qr ON members(qr_token);
  CREATE INDEX IF NOT EXISTS idx_attendance_scanned_at ON attendance(scanned_at DESC);
  CREATE INDEX IF NOT EXISTS idx_wa_queue_status ON whatsapp_queue(status, id ASC);
  CREATE INDEX IF NOT EXISTS idx_wa_logs_created ON whatsapp_logs(created_at DESC);
`);

console.log('--- CLEAN PRODUCTION DATABASE CREATED ---');
console.log('Members count:', db.prepare('SELECT count(*) as count FROM members').get().count);
console.log('Attendance count:', db.prepare('SELECT count(*) as count FROM attendance').get().count);
console.log('Queue count:', db.prepare('SELECT count(*) as count FROM whatsapp_queue').get().count);
console.log('Logs count:', db.prepare('SELECT count(*) as count FROM whatsapp_logs').get().count);

db.close();
