const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = path.join(__dirname, 'gym_backend.db');
const db = new Database(DB_PATH);

// Enable WAL mode for high performance concurrent reads and writes
db.pragma('journal_mode = WAL');

// Initialize schema
db.exec(`
  CREATE TABLE IF NOT EXISTS members (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    phone       TEXT,
    email       TEXT,
    plan        TEXT NOT NULL,
    expiry_date TEXT NOT NULL,
    status      TEXT NOT NULL, -- 'paid', 'due', 'expired'
    qr_token    TEXT UNIQUE NOT NULL,
    qr_path     TEXT,
    gender      TEXT,
    notes       TEXT,
    created_at  TEXT DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS attendance (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    member_id   TEXT,
    qr_token    TEXT NOT NULL,
    member_name TEXT NOT NULL,
    status      TEXT NOT NULL,
    scanned_at  TEXT NOT NULL,
    created_at  TEXT DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS whatsapp_queue (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    member_id       TEXT,
    recipient_phone TEXT NOT NULL,
    message_text    TEXT NOT NULL,
    message_type    TEXT DEFAULT 'custom', -- 'welcome', 'expiry_alert', 'payment_receipt', 'custom', 'test'
    status          TEXT DEFAULT 'pending', -- 'pending', 'processing', 'sent', 'failed', 'cancelled'
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
    status          TEXT NOT NULL, -- 'sent', 'failed'
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

// Prepared statements for maximum performance
const stmts = {
  getAllMembers: db.prepare(`SELECT * FROM members ORDER BY name ASC`),
  getMemberByToken: db.prepare(`SELECT * FROM members WHERE qr_token = ?`),
  getMemberById: db.prepare(`SELECT * FROM members WHERE id = ?`),
  countMembers: db.prepare(`SELECT COUNT(*) as count FROM members`),
  
  insertMember: db.prepare(`
    INSERT INTO members (id, name, phone, email, plan, expiry_date, status, qr_token, qr_path, gender, notes, created_at)
    VALUES (@id, @name, @phone, @email, @plan, @expiry_date, @status, @qr_token, @qr_path, @gender, @notes, @created_at)
  `),

  updateMember: db.prepare(`
    UPDATE members 
    SET name = @name, phone = @phone, email = @email, plan = @plan, 
        expiry_date = @expiry_date, status = @status, gender = @gender, notes = @notes
    WHERE id = @id
  `),

  deleteMember: db.prepare(`DELETE FROM members WHERE id = ?`),

  insertAttendance: db.prepare(`
    INSERT INTO attendance (member_id, qr_token, member_name, status, scanned_at)
    VALUES (@member_id, @qr_token, @member_name, @status, @scanned_at)
  `),

  getRecentAttendance: db.prepare(`
    SELECT a.*, m.phone, m.plan, m.expiry_date as member_expiry
    FROM attendance a
    LEFT JOIN members m ON a.qr_token = m.qr_token
    ORDER BY a.id DESC
    LIMIT ?
  `),

  getTodayCheckinsCount: db.prepare(`
    SELECT COUNT(*) as count 
    FROM attendance 
    WHERE date(scanned_at) = date('now', 'localtime')
  `),

  // WhatsApp Queue Statements
  enqueueWaMessage: db.prepare(`
    INSERT INTO whatsapp_queue (member_id, recipient_phone, message_text, message_type, status, created_at)
    VALUES (@member_id, @recipient_phone, @message_text, @message_type, 'pending', CURRENT_TIMESTAMP)
  `),

  getNextPendingWaMessage: db.prepare(`
    SELECT * FROM whatsapp_queue 
    WHERE status = 'pending' 
    ORDER BY id ASC 
    LIMIT 1
  `),

  updateWaQueueStatus: db.prepare(`
    UPDATE whatsapp_queue 
    SET status = @status, delay_seconds = @delay_seconds, attempts = attempts + 1, 
        last_error = @last_error, processed_at = CURRENT_TIMESTAMP
    WHERE id = @id
  `),

  getWaQueueList: db.prepare(`
    SELECT * FROM whatsapp_queue 
    ORDER BY id DESC 
    LIMIT ?
  `),

  getWaQueueByStatus: db.prepare(`
    SELECT * FROM whatsapp_queue 
    WHERE status = ? 
    ORDER BY id ASC 
    LIMIT ?
  `),

  getPendingWaCount: db.prepare(`
    SELECT COUNT(*) as count FROM whatsapp_queue WHERE status = 'pending'
  `),

  clearPendingWaQueue: db.prepare(`
    UPDATE whatsapp_queue 
    SET status = 'cancelled' 
    WHERE status = 'pending'
  `),

  insertWaLog: db.prepare(`
    INSERT INTO whatsapp_logs (queue_id, member_id, recipient_phone, message_text, message_type, status, delay_used_sec, error, created_at)
    VALUES (@queue_id, @member_id, @recipient_phone, @message_text, @message_type, @status, @delay_used_sec, @error, CURRENT_TIMESTAMP)
  `),

  getRecentWaLogs: db.prepare(`
    SELECT * FROM whatsapp_logs 
    ORDER BY id DESC 
    LIMIT ?
  `),

  getWaSentTodayCount: db.prepare(`
    SELECT COUNT(*) as count 
    FROM whatsapp_logs 
    WHERE status = 'sent' AND date(created_at) = date('now', 'localtime')
  `),

  // Settings
  getSetting: db.prepare(`SELECT value FROM whatsapp_settings WHERE key = ?`),
  setSetting: db.prepare(`INSERT OR REPLACE INTO whatsapp_settings (key, value) VALUES (?, ?)`),
  getAllSettings: db.prepare(`SELECT key, value FROM whatsapp_settings`),

  // Tablet devices
  upsertTabletDevice: db.prepare(`
    INSERT INTO tablet_devices (device_id, device_name, ip_address, battery_level, app_version, last_seen, total_scans)
    VALUES (@device_id, @device_name, @ip_address, @battery_level, @app_version, CURRENT_TIMESTAMP, 1)
    ON CONFLICT(device_id) DO UPDATE SET
      device_name = COALESCE(excluded.device_name, tablet_devices.device_name),
      ip_address = COALESCE(excluded.ip_address, tablet_devices.ip_address),
      battery_level = COALESCE(excluded.battery_level, tablet_devices.battery_level),
      app_version = COALESCE(excluded.app_version, tablet_devices.app_version),
      last_seen = CURRENT_TIMESTAMP,
      total_scans = tablet_devices.total_scans + 1
  `),

  getAllTabletDevices: db.prepare(`
    SELECT * FROM tablet_devices ORDER BY last_seen DESC
  `),

  // Due / Expired / Expiring soon queries
  getDueOrExpiredMembers: db.prepare(`
    SELECT * FROM members 
    WHERE status IN ('due', 'expired') 
       OR date(expiry_date) <= date('now', '+3 days', 'localtime')
    ORDER BY expiry_date ASC
  `),
};

// Batch attendance insertion transaction
const insertAttendanceBatchTx = db.transaction((scans) => {
  const results = [];
  for (const scan of scans) {
    const member = stmts.getMemberByToken.get(scan.qr_token);
    let memberName = scan.member_name || 'Unknown Member';
    let memberId = null;
    let status = scan.status || 'paid';

    if (member) {
      memberName = member.name;
      memberId = member.id;
      status = member.status;
      const expiry = new Date(member.expiry_date);
      if (expiry < new Date()) {
        status = 'expired';
      }
    }

    const res = stmts.insertAttendance.run({
      member_id: memberId,
      qr_token: scan.qr_token,
      member_name: memberName,
      status: status,
      scanned_at: scan.scanned_at || new Date().toISOString(),
    });

    results.push({
      id: Number(res.lastInsertRowid),
      member_id: memberId,
      member_name: memberName,
      qr_token: scan.qr_token,
      status: status,
      scanned_at: scan.scanned_at,
    });
  }
  return results;
});

module.exports = {
  db,
  getAllMembers: () => stmts.getAllMembers.all(),
  getMemberByToken: (token) => stmts.getMemberByToken.get(token),
  getMemberById: (id) => stmts.getMemberById.get(id),
  countMembers: () => stmts.countMembers.get().count,
  insertMember: (member) => stmts.insertMember.run(member),
  updateMember: (member) => stmts.updateMember.run(member),
  deleteMember: (id) => stmts.deleteMember.run(id),
  insertAttendance: (record) => stmts.insertAttendance.run(record),
  insertAttendanceBatch: (scans) => insertAttendanceBatchTx(scans),
  getRecentAttendance: (limit = 50) => stmts.getRecentAttendance.all(limit),
  getTodayCheckinsCount: () => stmts.getTodayCheckinsCount.get().count,
  getDueOrExpiredMembers: () => stmts.getDueOrExpiredMembers.all(),

  // WhatsApp helpers
  enqueueWaMessage: (msg) => stmts.enqueueWaMessage.run(msg),
  getNextPendingWaMessage: () => stmts.getNextPendingWaMessage.get(),
  updateWaQueueStatus: (id, status, delaySec = 0, lastError = null) =>
    stmts.updateWaQueueStatus.run({
      id,
      status,
      delay_seconds: delaySec,
      last_error: lastError,
    }),
  getWaQueueList: (limit = 50) => stmts.getWaQueueList.all(limit),
  getPendingWaCount: () => stmts.getPendingWaCount.get().count,
  clearPendingWaQueue: () => stmts.clearPendingWaQueue.run(),
  insertWaLog: (log) => stmts.insertWaLog.run(log),
  getRecentWaLogs: (limit = 50) => stmts.getRecentWaLogs.all(limit),
  getWaSentTodayCount: () => stmts.getWaSentTodayCount.get().count,

  // Settings
  getSetting: (key, defVal = null) => {
    const row = stmts.getSetting.get(key);
    return row ? row.value : defVal;
  },
  setSetting: (key, value) => stmts.setSetting.run(key, String(value)),
  getAllSettings: () => {
    const rows = stmts.getAllSettings.all();
    const map = {};
    for (const r of rows) map[r.key] = r.value;
    return map;
  },

  // Tablet devices
  upsertTabletDevice: (dev) => stmts.upsertTabletDevice.run(dev),
  getAllTabletDevices: () => stmts.getAllTabletDevices.all(),
};
