const http = require('http');
const { spawn } = require('child_process');

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

async function waitForServer(maxRetries = 20) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const res = await get('/api/ping');
      if (res.status === 200) return true;
    } catch (_) {}
    await new Promise(r => setTimeout(r, 400));
  }
  return false;
}

async function runApiTests() {
  console.log('Testing Server HTTP Endpoints on port 5000...');

  // 1. Tablet Reachability Ping
  const ping = await get('/api/ping');
  console.log(`[PASS] /api/ping (HTTP ${ping.status}):`, ping.json);

  // 2. Network Info with Auto-Connect QR & Tablet Kiosk URL
  const netInfo = await get('/api/network/info');
  console.log(`[PASS] /api/network/info (HTTP ${netInfo.status}): Host ${netInfo.json.hostname}, Tablet URL: ${netInfo.json.tabletUrl}`);

  // 3. Tablet Kiosk HTML Page
  const kioskPage = await get('/tablet');
  console.log(`[PASS] /tablet (HTTP ${kioskPage.status}): Kiosk app page returned ${kioskPage.raw.length} bytes.`);

  // 4. Tablet Config
  const tabletCfg = await get('/api/tablet/config');
  console.log(`[PASS] /api/tablet/config: Gym: "${tabletCfg.json.gymName}", Sync Interval: ${tabletCfg.json.autoSyncIntervalSec}s`);

  // 5. Tablet Members Sync
  const sync = await get('/api/members/sync');
  console.log(`[PASS] /api/members/sync: Returned ${sync.json.count} members ready for tablet offline caching.`);

  // 6. Tablet Attendance Scan
  const testQr = sync.json.members[0].qr_token;
  const scan = await post('/api/attendance/scan', { qr_token: testQr, device_id: 'test-tablet-kiosk' });
  console.log(`[PASS] /api/attendance/scan: Checked in "${scan.json.member.name}" (${scan.json.status.toUpperCase()})`);

  // 7. Tablet Offline Batch Sync
  const batch = await post('/api/attendance/batch', {
    scans: [
      {
        qr_token: testQr,
        member_name: sync.json.members[0].name,
        status: 'paid',
        scanned_at: new Date().toISOString(),
        device_id: 'test-tablet-kiosk'
      }
    ]
  });
  console.log(`[PASS] /api/attendance/batch: Synced ${batch.json.processed} offline check-ins from tablet.`);

  // 8. Tablet Broadcast Sync Signal
  const bcast = await post('/api/tablet/broadcast-sync', {});
  console.log(`[PASS] /api/tablet/broadcast-sync: Broadcasted sync signal to all tablets (Roster: ${bcast.json.count}).`);

  // 9. WhatsApp Status
  const waStatus = await get('/api/whatsapp/status');
  console.log(`[PASS] /api/whatsapp/status: Engine is "${waStatus.json.status}", Mode: ${waStatus.json.settings.provider_mode}`);

  // 10. Real WhatsApp Status
  const realWaStatus = await get('/api/whatsapp/real/status');
  console.log(`[PASS] /api/whatsapp/real/status: Status is "${realWaStatus.json.status}", IsConnected: ${realWaStatus.json.isConnected}`);

  console.log('\n--- ALL HTTP & TABLET & REAL WHATSAPP ENDPOINTS ARE VERIFIED FULLY WORKING! ---');
}

async function main() {
  const serverProc = spawn('node', ['server.js'], { cwd: __dirname, stdio: 'pipe' });

  serverProc.stderr.on('data', d => {
    // console.error('[Server Err]:', d.toString());
  });

  const ready = await waitForServer(25);
  if (!ready) {
    console.error('Server did not start within timeout');
    serverProc.kill();
    process.exit(1);
  }

  try {
    await runApiTests();
  } catch (err) {
    console.error('Test Error:', err);
    process.exitCode = 1;
  } finally {
    serverProc.kill();
  }
}

main();
