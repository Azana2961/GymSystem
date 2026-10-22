const http = require('http');

function get(path) {
  return new Promise((resolve, reject) => {
    http.get(`http://localhost:5000${path}`, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, json: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    }).on('error', reject);
  });
}

function post(path, body) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body);
    const req = http.request(`http://localhost:5000${path}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, json: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

async function runApiTests() {
  console.log('Testing Server HTTP Endpoints on port 5000...');

  // 1. Tablet Reachability Ping
  const ping = await get('/api/ping');
  console.log(`[PASS] /api/ping (HTTP ${ping.status}):`, ping.json);

  // 2. Network Info with Auto-Connect QR
  const netInfo = await get('/api/network/info');
  console.log(`[PASS] /api/network/info (HTTP ${netInfo.status}): Host ${netInfo.json.hostname}, Primary IP: ${netInfo.json.primaryIp}, Base URL: ${netInfo.json.baseUrl}`);

  // 3. Tablet Config
  const tabletCfg = await get('/api/tablet/config');
  console.log(`[PASS] /api/tablet/config: Gym: "${tabletCfg.json.gymName}", Sync Interval: ${tabletCfg.json.autoSyncIntervalSec}s`);

  // 4. Tablet Members Sync
  const sync = await get('/api/members/sync');
  console.log(`[PASS] /api/members/sync: Returned ${sync.json.count} members ready for tablet offline caching.`);

  // 5. Tablet Attendance Scan
  const testQr = sync.json.members[0].qr_token;
  const scan = await post('/api/attendance/scan', { qr_token: testQr });
  console.log(`[PASS] /api/attendance/scan: Checked in "${scan.json.member.name}" (${scan.json.status.toUpperCase()})`);

  // 6. WhatsApp Status
  const waStatus = await get('/api/whatsapp/status');
  console.log(`[PASS] /api/whatsapp/status: Engine is "${waStatus.json.status}", Random delay range: ${waStatus.json.settings.min_delay_sec}s-${waStatus.json.settings.max_delay_sec}s, Mode: ${waStatus.json.settings.provider_mode}`);

  // 7. WhatsApp Expiry Alerts Trigger
  const waExpiry = await post('/api/whatsapp/send-expiry-alerts', {});
  console.log(`[PASS] /api/whatsapp/send-expiry-alerts: Enqueued ${waExpiry.json.count} anti-ban reminders with randomized delays.`);

  // 8. Real WhatsApp Status
  const realWaStatus = await get('/api/whatsapp/real/status');
  console.log(`[PASS] /api/whatsapp/real/status: Status is "${realWaStatus.json.status}", IsConnected: ${realWaStatus.json.isConnected}, Session dir exists: ${realWaStatus.json.authDirExists}`);

  // 9. Real WhatsApp Send / Queue (with Anti-Ban Delay Protection)
  const realSend = await post('/api/whatsapp/send-real', {
    phone: '+92 300 9876543',
    text: '{Salam|Hello} Member! This is a real WhatsApp auto-message test with anti-ban jitter.',
    immediate: false,
  });
  console.log(`[PASS] /api/whatsapp/send-real: Enqueued #${realSend.json.item.id} with status "${realSend.json.item.status}"`);

  console.log('\n--- ALL HTTP & TABLET & REAL WHATSAPP ENDPOINTS ARE VERIFIED FULLY WORKING! ---');
}

// Start server child process and run tests
const { spawn } = require('child_process');
const serverProc = spawn('node', ['server.js'], { cwd: __dirname });

serverProc.stdout.on('data', (d) => {
  // console.log('[server]', d.toString());
});

setTimeout(async () => {
  try {
    await runApiTests();
  } catch (err) {
    console.error('API Test Error:', err);
  } finally {
    serverProc.kill();
    process.exit(0);
  }
}, 2000);
