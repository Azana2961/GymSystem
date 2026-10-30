const express = require('express');
const cors = require('cors');
const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { WebSocketServer } = require('ws');
const QRCode = require('qrcode');

const db = require('./db');
const seed = require('./seed');
const { generateQrToken, generateAndSaveQr, QR_DIR } = require('./qrService');
const whatsappService = require('./whatsappService');
const realWhatsAppManager = require('./realWhatsapp');

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

const PORT = process.env.PORT || 5000;

// Permissive CORS for Tablet & LAN connections
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-device-id', 'x-tablet-id'],
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
// Explicit Tablet Kiosk App routes (served from root /tablet directory)
const tabletDir = path.join(__dirname, '..', 'tablet');
app.get(['/tablet', '/tablet/', '/kiosk'], (req, res) => {
  res.sendFile(path.join(tabletDir, 'index.html'));
});
app.use('/tablet', express.static(tabletDir));

app.use('/qrcodes', express.static(QR_DIR));
app.use(express.static(path.join(__dirname, 'public')));

// Set of connected SSE clients
const sseClients = new Set();

/**
 * Broadcast an event to all connected WebSocket and SSE clients
 */
function broadcast(eventType, data) {
  const payload = JSON.stringify({ type: eventType, data, timestamp: new Date().toISOString() });

  // 1. WebSocket broadcast
  wss.clients.forEach((client) => {
    if (client.readyState === 1) { // OPEN
      try {
        client.send(payload);
      } catch (err) {}
    }
  });

  // 2. Server-Sent Events broadcast
  sseClients.forEach((res) => {
    try {
      res.write(`event: ${eventType}\n`);
      res.write(`data: ${payload}\n\n`);
    } catch (err) {}
  });

  // 3. Auto-trigger WhatsApp queue worker when Real WhatsApp connects
  if (eventType === 'whatsapp:real:connected') {
    setTimeout(() => whatsappService.startWorker(), 1000);
  }
}

// Wire WhatsApp services real-time broadcaster
whatsappService.setBroadcaster(broadcast);
realWhatsAppManager.setBroadcaster(broadcast);

// ── WebSocket Connection Handler ──────────────────────────────────────────
wss.on('connection', (ws, req) => {
  const clientIp = req.socket.remoteAddress;
  console.log(`[WS] Client connected from ${clientIp}`);

  // Send initial state on connection
  ws.send(JSON.stringify({
    type: 'init',
    data: {
      recentAttendance: db.getRecentAttendance(15),
      totalCheckinsToday: db.getTodayCheckinsCount(),
      whatsappStatus: whatsappService.getStatus(),
    },
    timestamp: new Date().toISOString(),
  }));

  ws.on('close', () => {
    console.log('[WS] Client disconnected');
  });

  ws.on('error', (err) => {
    console.error('[WS Error]:', err.message);
  });
});

// ── SSE Endpoint: Real-time Attendance Stream ─────────────────────────────
app.get('/api/attendance/stream', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  sseClients.add(res);
  console.log('[SSE] Client connected to live stream');

  res.write(`data: ${JSON.stringify({ type: 'connected', time: new Date() })}\n\n`);

  req.on('close', () => {
    sseClients.delete(res);
    console.log('[SSE] Client disconnected');
  });
});

// ── Helper to retrieve all Local IPv4 Network Addresses ───────────────────
function getLocalIpAddresses() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const net of interfaces[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        addresses.push(net.address);
      }
    }
  }
  return addresses;
}

// ── Health & Reachability Probes ──────────────────────────────────────────
app.get('/', (req, res, next) => {
  if (req.accepts('html')) {
    return next();
  }
  const ips = getLocalIpAddresses();
  res.json({
    status: 'ok',
    server: 'Gym System Local Hub',
    time: new Date().toISOString(),
    localIp: ips[0] || 'localhost',
    port: PORT,
    totalMembers: db.countMembers(),
    todayCheckins: db.getTodayCheckinsCount(),
  });
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// Fast ping probe specifically designed for Tablet "Test Connection" button
app.get('/api/ping', (req, res) => {
  const ips = getLocalIpAddresses();
  res.json({
    success: true,
    message: 'Lá Fitness Backend is online & reachable',
    serverTime: new Date().toISOString(),
    primaryIp: ips[0] || '127.0.0.1',
    port: PORT,
  });
});

// ── Tablet IP Connection & Network Discovery ─────────────────────────────
app.get('/api/network/info', async (req, res) => {
  try {
    const ips = getLocalIpAddresses();
    const primaryIp = ips[0] || '127.0.0.1';
    const baseUrl = `http://${primaryIp}:${PORT}`;

    // Generate a QR Code encoding the Tablet Auto-Connect payload
    const tabletUrl = `${baseUrl}/tablet`;
    const connectPayload = JSON.stringify({
      serverUrl: baseUrl,
      tabletUrl,
      primaryIp,
      port: PORT,
      wsUrl: `ws://${primaryIp}:${PORT}/ws`,
      gymName: whatsappService.getSettings().gym_name || 'Lá Fitness',
    });

    const qrDataUrl = await QRCode.toDataURL(connectPayload, {
      errorCorrectionLevel: 'M',
      margin: 2,
      width: 280,
    });

    res.json({
      success: true,
      hostname: os.hostname(),
      port: PORT,
      primaryIp,
      allIps: ips,
      baseUrl,
      tabletUrl,
      pingUrl: `${baseUrl}/api/ping`,
      syncUrl: `${baseUrl}/api/members/sync`,
      scanUrl: `${baseUrl}/api/attendance/scan`,
      batchScanUrl: `${baseUrl}/api/attendance/batch`,
      wsUrl: `ws://${primaryIp}:${PORT}/ws`,
      configQr: qrDataUrl,
      instructions: [
        '1. Connect your Tablet and Laptop to the SAME Wi-Fi or hotspot network.',
        `2. In the Tablet Kiosk Settings, enter Host IP / Base URL: ${baseUrl}`,
        `3. Alternatively, open ${tabletUrl} on your tablet browser directly!`,
        '4. Or scan this setup QR Code on screen with the tablet camera to configure automatically.',
        '5. Tap "Test Connection" on the tablet to verify reachability.',
      ],
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Tablet Kiosk Configuration
app.get('/api/tablet/config', (req, res) => {
  const ips = getLocalIpAddresses();
  res.json({
    success: true,
    gymName: whatsappService.getSettings().gym_name || 'Lá Fitness',
    serverTime: new Date().toISOString(),
    primaryIp: ips[0] || '127.0.0.1',
    autoSyncIntervalSec: 300,
    scanCooldownMs: 2000,
    offlineCachingEnabled: true,
  });
});

// Tablet Heartbeat & Device Registry
app.post('/api/tablet/heartbeat', (req, res) => {
  try {
    const { device_id, device_name, battery_level, app_version } = req.body;
    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || '';

    if (!device_id) {
      return res.status(400).json({ success: false, message: 'device_id is required' });
    }

    db.upsertTabletDevice({
      device_id,
      device_name: device_name || 'Gym Tablet Kiosk',
      ip_address: ip.replace(/^.*:/, ''), // clean IPv6 mapped
      battery_level: battery_level || null,
      app_version: app_version || '1.0.0',
    });

    broadcast('tablet:heartbeat', {
      device_id,
      device_name,
      battery_level,
      last_seen: new Date().toISOString(),
    });

    res.json({ success: true, timestamp: new Date().toISOString() });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get('/api/tablet/devices', (req, res) => {
  const devices = db.getAllTabletDevices();
  res.json({ success: true, devices });
});

// Force all connected tablets to re-sync members roster
app.post('/api/tablet/broadcast-sync', (req, res) => {
  const members = db.getAllMembers();
  broadcast('sync:force', { count: members.length, timestamp: new Date().toISOString() });
  res.json({ success: true, message: 'Broadcasted sync signal to all connected tablets', count: members.length });
});

// ── 1. Tablet Member Sync: GET /api/members/sync ──────────────────────────
app.get('/api/members/sync', (req, res) => {
  try {
    const all = db.getAllMembers();
    // Exact schema expected by TabletApp's Member.fromJson
    const members = all.map((m) => {
      const isVis =
        m.status === 'visitor' ||
        String(m.qr_token || '').toUpperCase().startsWith('VIS-') ||
        String(m.plan || '').toLowerCase().includes('visitor');
      let status = isVis ? 'visitor' : m.status;
      if (!isVis && new Date(m.expiry_date) < new Date()) {
        status = 'expired';
      }
      return {
        id: m.id,
        qr_token: m.qr_token,
        name: m.name,
        status: status,
        expiry_date: m.expiry_date,
        phone: m.phone,
        plan: m.plan,
        email: m.email,
        gender: m.gender,
      };
    });

    res.json({
      success: true,
      timestamp: new Date().toISOString(),
      count: members.length,
      members,
    });
  } catch (err) {
    console.error('Sync error:', err);
    res.status(500).json({ success: false, error: 'Database error during sync' });
  }
});

// ── 2. Attendance Scan: POST /api/attendance/scan ────────────────────────
app.post('/api/attendance/scan', (req, res) => {
  try {
    const { qr_token, scanned_at, device_id, visitor_photo_base64, visitor_photo } = req.body;
    if (!qr_token) {
      return res.status(400).json({ success: false, message: 'qr_token is required' });
    }

    const timestamp = scanned_at || new Date().toISOString();
    const member = db.getMemberByToken(qr_token);

    if (!member) {
      return res.status(404).json({
        success: false,
        message: 'Member with this QR code not found in gym system',
      });
    }

    // Determine current status (including 'visitor')
    const isVisitorMember =
      member.status === 'visitor' ||
      String(member.qr_token || '').toUpperCase().startsWith('VIS-') ||
      String(qr_token).toUpperCase().startsWith('VIS-') ||
      String(member.plan || '').toLowerCase().includes('visitor');

    let status = isVisitorMember ? 'visitor' : member.status;
    const now = new Date();
    const expiry = new Date(member.expiry_date);
    if (!isVisitorMember) {
      if (expiry < now) {
        status = 'expired';
      } else if (status !== 'due') {
        const daysLeft = Math.ceil((expiry - now) / 86400000);
        if (daysLeft <= 5) {
          status = 'due';
        }
      }
    }

    // Save visitor camera snapshot if provided
    let savedPhotoUrl = visitor_photo || null;
    if (visitor_photo_base64) {
      try {
        const cleanB64 = String(visitor_photo_base64).replace(/^data:image\/\w+;base64,/, '');
        const fileName = `VISITOR-${member.id}-${Date.now()}.jpg`;
        const filePath = path.join(QR_DIR, fileName);
        fs.writeFileSync(filePath, Buffer.from(cleanB64, 'base64'));
        savedPhotoUrl = `/qrcodes/${fileName}`;
      } catch (photoErr) {
        console.warn('[ATTENDANCE] Failed to save visitor photo:', photoErr.message);
      }
    }

    // Save attendance entry to SQLite
    const result = db.insertAttendance({
      member_id: member.id,
      qr_token: member.qr_token,
      member_name: member.name,
      status: status,
      visitor_photo: savedPhotoUrl,
      scanned_at: timestamp,
    });

    const attendanceRecord = {
      id: Number(result.lastInsertRowid),
      member_id: member.id,
      member_name: member.name,
      qr_token: member.qr_token,
      status: status,
      plan: member.plan,
      phone: member.phone,
      visitor_photo: savedPhotoUrl,
      scanned_at: timestamp,
      device_id: device_id || 'tablet',
    };

    console.log(`[ATTENDANCE] Checked in: ${member.name} (${status.toUpperCase()})${savedPhotoUrl ? ' [PHOTO CAPTURED]' : ''} at ${timestamp}`);

    // Broadcast attendance in real time to the laptop dashboard
    broadcast('attendance:new', attendanceRecord);

    res.json({
      success: true,
      message: `Welcome, ${member.name}!`,
      status: status,
      is_visitor: isVisitorMember,
      visitor_photo: savedPhotoUrl,
      member: {
        id: member.id,
        name: member.name,
        status: status,
        expiry_date: member.expiry_date,
        plan: member.plan,
      },
      attendance: attendanceRecord,
    });
  } catch (err) {
    console.error('Scan recording error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Offline Batch Sync: POST /api/attendance/batch ────────────────────────
// When a tablet was offline and queued check-ins locally, it posts them all once online
app.post('/api/attendance/batch', (req, res) => {
  try {
    const { scans } = req.body;
    if (!Array.isArray(scans) || scans.length === 0) {
      return res.status(400).json({ success: false, message: 'scans array is required' });
    }

    // Save any offline visitor camera snapshots to files on disk
    for (const scan of scans) {
      if (scan.visitor_photo && (scan.visitor_photo.length > 200 || scan.visitor_photo.startsWith('data:image'))) {
        try {
          const cleanB64 = String(scan.visitor_photo).replace(/^data:image\/\w+;base64,/, '');
          const fileName = `VISITOR-${scan.member_id || scan.qr_token || 'OFFLINE'}-${Date.now()}-${Math.floor(Math.random() * 1000)}.jpg`;
          const filePath = path.join(QR_DIR, fileName);
          fs.writeFileSync(filePath, Buffer.from(cleanB64, 'base64'));
          scan.visitor_photo = `/qrcodes/${fileName}`;
        } catch (photoErr) {
          console.warn('[BATCH SYNC] Could not save offline visitor photo snapshot:', photoErr.message);
        }
      }
    }

    const saved = db.insertAttendanceBatch(scans);
    console.log(`[BATCH SYNC] Successfully processed ${saved.length} offline check-ins from tablet`);

    // Broadcast latest batch to dashboard
    broadcast('attendance:batch', { count: saved.length, records: saved });

    res.json({
      success: true,
      processed: saved.length,
      records: saved,
    });
  } catch (err) {
    console.error('Batch scan error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── 3. Member Registration: POST /api/members/register ────────────────────
app.post('/api/members/register', async (req, res) => {
  try {
    const { id, qr_token, name, phone, plan, expiry_date, status, email, gender, notes, send_welcome, image_base64 } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Member name is required' });
    }

    const isVisitorReg =
      status === 'visitor' ||
      String(plan || '').toLowerCase().includes('visitor');
    const memberId = (id && String(id).trim()) || ((isVisitorReg ? 'V' : 'M') + Date.now().toString().slice(-6));
    const qrToken = (qr_token && String(qr_token).trim()) || generateQrToken(isVisitorReg ? 'VIS' : 'GYM');

    // Generate physical PNG and DataURL
    const { url, dataUrl } = await generateAndSaveQr(qrToken);

    const newMember = {
      id: memberId,
      name: name.trim(),
      phone: (phone || '').trim(),
      email: (email || '').trim(),
      plan: plan || 'Monthly',
      expiry_date: expiry_date || new Date(Date.now() + 30 * 86400000).toISOString().split('T')[0],
      status: status || 'paid',
      qr_token: qrToken,
      qr_path: url,
      gender: gender || 'Other',
      notes: notes || '',
      created_at: new Date().toISOString(),
    };

    db.insertMember(newMember);

    console.log(`[REGISTRATION] New member: ${newMember.name} (QR: ${qrToken})`);

    // Broadcast new member to any connected laptop or tablet
    broadcast('member:new', newMember);

    // Auto-trigger WhatsApp welcome notification with anti-ban delay queue
    let whatsappQueued = null;
    if (newMember.phone && send_welcome !== false) {
      try {
        whatsappQueued = whatsappService.sendWelcomeMessage(newMember, image_base64 || null);
      } catch (waErr) {
        console.warn('[WhatsApp] Welcome queue skipped:', waErr.message);
      }
    }

    res.status(201).json({
      success: true,
      message: 'Member registered successfully',
      member: {
        id: newMember.id,
        qr_token: newMember.qr_token,
        name: newMember.name,
        phone: newMember.phone,
        plan: newMember.plan,
        expiry_date: newMember.expiry_date,
        status: newMember.status,
        qr_url: newMember.qr_path,
        qr_data_url: dataUrl,
      },
      whatsappQueued,
    });
  } catch (err) {
    console.error('Registration error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── 4. Member Management API ──────────────────────────────────────────────
app.get('/api/members', (req, res) => {
  const members = db.getAllMembers();
  res.json({ success: true, count: members.length, members });
});

app.get('/api/members/:id', (req, res) => {
  const member = db.getMemberById(req.params.id);
  if (!member) return res.status(404).json({ success: false, message: 'Member not found' });
  res.json({ success: true, member });
});

app.put('/api/members/:id', (req, res) => {
  try {
    const existing = db.getMemberById(req.params.id);
    if (!existing) return res.status(404).json({ success: false, message: 'Member not found' });

    const updated = {
      id: req.params.id,
      name: req.body.name ?? existing.name,
      phone: req.body.phone ?? existing.phone,
      email: req.body.email ?? existing.email,
      plan: req.body.plan ?? existing.plan,
      expiry_date: req.body.expiry_date ?? existing.expiry_date,
      status: req.body.status ?? existing.status,
      gender: req.body.gender ?? existing.gender,
      notes: req.body.notes ?? existing.notes,
    };

    db.updateMember(updated);
    broadcast('member:updated', updated);

    // If renewed or paid, send receipt if requested
    if (req.body.send_receipt && updated.phone) {
      try {
        whatsappService.sendPaymentReceipt(updated, {
          amount: req.body.paid_amount || '0',
          method: req.body.payment_method || 'Cash',
        });
      } catch (e) {}
    }

    res.json({ success: true, member: updated });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

app.delete('/api/members/:id', (req, res) => {
  try {
    const existing = db.getMemberById(req.params.id);
    if (!existing) return res.status(404).json({ success: false, message: 'Member not found' });

    db.deleteMember(req.params.id);
    broadcast('member:deleted', { id: req.params.id, qr_token: existing.qr_token });
    res.json({ success: true, message: 'Member deleted' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── 5. Attendance Feed & Statistics ───────────────────────────────────────
app.get('/api/attendance/feed', (req, res) => {
  const limit = Math.min(parseInt(req.query.limit, 10) || 30, 100);
  const feed = db.getRecentAttendance(limit);
  res.json({ success: true, count: feed.length, feed });
});

app.get('/api/stats', (req, res) => {
  const members = db.getAllMembers();
  const todayCheckins = db.getTodayCheckinsCount();

  let active = 0;
  let due = 0;
  let expired = 0;

  for (const m of members) {
    if (m.status === 'paid') active++;
    else if (m.status === 'due') due++;
    else expired++;
  }

  res.json({
    success: true,
    stats: {
      totalMembers: members.length,
      todayCheckins,
      activeMembers: active,
      dueMembers: due,
      expiredMembers: expired,
      whatsappPending: db.getPendingWaCount(),
      whatsappSentToday: db.getWaSentTodayCount(),
    },
  });
});

// ── 6. WhatsApp Anti-Ban Automation Endpoints ──────────────────────────────

// Current status of the anti-ban engine & queue
app.get('/api/whatsapp/status', (req, res) => {
  res.json({
    success: true,
    ...whatsappService.getStatus(),
  });
});

// Anti-ban settings (delays, burst batch size, cooldowns)
app.get('/api/whatsapp/settings', (req, res) => {
  res.json({
    success: true,
    settings: whatsappService.getSettings(),
  });
});

app.post('/api/whatsapp/settings', (req, res) => {
  try {
    whatsappService.updateSettings(req.body);
    res.json({
      success: true,
      message: 'Anti-ban settings updated successfully',
      settings: whatsappService.getSettings(),
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Active & pending WhatsApp queue
app.get('/api/whatsapp/queue', (req, res) => {
  const limit = Math.min(parseInt(req.query.limit, 10) || 50, 100);
  const queue = db.getWaQueueList(limit);
  res.json({
    success: true,
    count: queue.length,
    pendingCount: db.getPendingWaCount(),
    queue,
  });
});

// WhatsApp historical sent logs
app.get('/api/whatsapp/logs', (req, res) => {
  const limit = Math.min(parseInt(req.query.limit, 10) || 50, 100);
  const logs = db.getRecentWaLogs(limit);
  res.json({
    success: true,
    count: logs.length,
    sentToday: db.getWaSentTodayCount(),
    logs,
  });
});

// Enqueue a single message (or standalone Pass Card image) with random anti-ban delay
app.post('/api/whatsapp/send', (req, res) => {
  try {
    const { member_id, phone, text, type, image_base64, image_path } = req.body;
    if (!phone || (!text && !image_base64 && !image_path)) {
      return res.status(400).json({ success: false, message: 'phone and either text or image are required' });
    }

    const item = whatsappService.enqueue({
      member_id: member_id || null,
      recipient_phone: phone,
      message_text: text || '',
      message_type: type || 'custom',
      image_base64: image_base64 || null,
      image_path: image_path || null,
    });

    res.json({
      success: true,
      message: 'Message added to Anti-Ban Queue with randomized time delay',
      item,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Quick anti-ban test message to demo random delay
app.post('/api/whatsapp/send-test', (req, res) => {
  try {
    const { phone } = req.body;
    const targetPhone = phone || '+92 300 1234567';
    const settings = whatsappService.getSettings();

    const sampleText =
      '{Salam|Hello|Hi} there! ⚡\n' +
      'This is a verified test dispatch from *' +
      settings.gym_name +
      '* Anti-Ban Delivery Engine.\n' +
      'Random human delay was applied successfully!';

    const item = whatsappService.enqueue({
      recipient_phone: targetPhone,
      message_text: sampleText,
      message_type: 'test',
    });

    res.json({
      success: true,
      message: `Test message enqueued for ${targetPhone}. Check live timer in web console!`,
      item,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Trigger automated expiry/due alerts for members due or expired
app.post('/api/whatsapp/send-expiry-alerts', (req, res) => {
  try {
    const result = whatsappService.sendExpiryAlerts(4);
    res.json({
      success: true,
      message: `Enqueued ${result.count} expiry reminders into Anti-Ban Queue`,
      count: result.count,
      items: result.items,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Broadcast custom announcement to filtered members safely
app.post('/api/whatsapp/broadcast', (req, res) => {
  try {
    const { target, template } = req.body;
    if (!template || !template.trim()) {
      return res.status(400).json({ success: false, message: 'template text is required' });
    }

    const result = whatsappService.sendBroadcast({
      target: target || 'all',
      templateText: template,
    });

    res.json({
      success: true,
      message: `Enqueued ${result.count} broadcast messages into Anti-Ban Queue`,
      target: result.target,
      count: result.count,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Pause / Resume / Clear Queue Controls
app.post('/api/whatsapp/pause', (req, res) => {
  whatsappService.pause();
  res.json({ success: true, message: 'WhatsApp queue paused' });
});

app.post('/api/whatsapp/resume', (req, res) => {
  whatsappService.resume();
  res.json({ success: true, message: 'WhatsApp queue resumed' });
});

app.post('/api/whatsapp/clear', (req, res) => {
  whatsappService.clearPending();
  res.json({ success: true, message: 'Pending WhatsApp queue cleared' });
});

// ── 7. Real WhatsApp Web Client Endpoints ─────────────────────────────────

// Get real WhatsApp connection status, connected phone number, and QR if pending
app.get('/api/whatsapp/real/status', (req, res) => {
  res.json({
    success: true,
    ...realWhatsAppManager.getStatus(),
  });
});

// Get latest QR code (Data URL & raw string) for phone pairing
app.get('/api/whatsapp/real/qr', (req, res) => {
  res.json({
    success: true,
    ...realWhatsAppManager.getStatus(),
  });
});

// Reconnect or manually initialize Real WhatsApp socket
app.post('/api/whatsapp/real/start', async (req, res) => {
  try {
    await realWhatsAppManager.init();
    res.json({
      success: true,
      message: 'WhatsApp Web initialization triggered',
      status: realWhatsAppManager.getStatus(),
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Log out active WhatsApp Web session and clear stored keys
app.post('/api/whatsapp/real/logout', async (req, res) => {
  try {
    const result = await realWhatsAppManager.logout();
    res.json(result);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Request 8-digit mobile pairing code instead of scanning QR
app.post('/api/whatsapp/real/pairing-code', async (req, res) => {
  try {
    const { phone } = req.body;
    if (!phone) {
      return res.status(400).json({ success: false, message: 'phone number is required' });
    }
    const result = await realWhatsAppManager.requestPairingCode(phone);
    res.json(result);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Direct or queued real WhatsApp message sender
app.post('/api/whatsapp/send-real', async (req, res) => {
  try {
    const { phone, text, immediate } = req.body;
    if (!phone || !text) {
      return res.status(400).json({ success: false, message: 'phone and text are required' });
    }

    if (immediate) {
      // Direct real dispatch
      const result = await realWhatsAppManager.sendRealMessage(phone, text);
      res.json({
        success: true,
        message: `Real WhatsApp message delivered to +${phone}`,
        result,
      });
    } else {
      // Queue through anti-ban safety engine
      const item = whatsappService.enqueue({
        recipient_phone: phone,
        message_text: text,
        message_type: 'real_direct',
      });
      res.json({
        success: true,
        message: `Real WhatsApp message enqueued into Anti-Ban Queue with random time delay`,
        item,
      });
    }
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── Startup & Seed ────────────────────────────────────────────────────────
async function start() {
  await seed();

  server.listen(PORT, '0.0.0.0', () => {
    const ips = getLocalIpAddresses();
    console.log('\n================================================================');
    console.log('   GYM SYSTEM LOCAL HUB & ANTI-BAN WHATSAPP ENGINE ONLINE');
    console.log(`   Port: ${PORT}`);
    console.log('----------------------------------------------------------------');
    console.log(`   Localhost Web Console:   http://localhost:${PORT}`);
    ips.forEach((ip) => {
      console.log(`   LAN / Wi-Fi Access:      http://${ip}:${PORT}`);
    });
    console.log('----------------------------------------------------------------');
    console.log('   TABLET CONNECTION CONFIG:');
    if (ips.length > 0) {
      console.log(`   -> Set Tablet Server Host IP to: http://${ips[0]}:${PORT}`);
      console.log(`   -> Auto-Connect QR & Setup:     http://${ips[0]}:${PORT}`);
    } else {
      console.log(`   -> Set Tablet Server Host IP to: http://192.168.1.50:${PORT}`);
    }
    console.log('----------------------------------------------------------------');
    console.log('   WHATSAPP ANTI-BAN ENGINE:');
    const waSettings = whatsappService.getSettings();
    console.log(`   -> Random Delay Range: ${waSettings.min_delay_sec}s - ${waSettings.max_delay_sec}s (+ jitter)`);
    console.log(`   -> Fatigue Cooldown:   ${waSettings.cooldown_sec}s break every ${waSettings.burst_batch_size} messages`);
    console.log(`   -> Daily Safety Limit: ${waSettings.daily_limit} messages`);
    console.log(`   -> Active Mode:        ${waSettings.provider_mode.toUpperCase()}`);
    console.log('================================================================\n');

    // Start background queue worker if any pending messages existed prior to restart
    whatsappService.startWorker();

    // Start Real WhatsApp multi-device connection in background
    realWhatsAppManager.init().catch((err) => {
      console.warn('[Real WhatsApp Startup Alert]:', err.message);
    });
  });
}

start().catch(console.error);

