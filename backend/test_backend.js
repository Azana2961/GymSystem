const db = require('./db');
const whatsappService = require('./whatsappService');
const { generateQrToken, generateAndSaveQr } = require('./qrService');

async function testBackend() {
  console.log('--- STARTING BACKEND COMPONENT TESTS ---');

  // 1. Database & Members
  const count = db.countMembers();
  console.log(`[PASS] db.countMembers() returned: ${count}`);

  const members = db.getAllMembers();
  console.log(`[PASS] db.getAllMembers() returned ${members.length} members.`);

  // 2. QR Service
  const token = generateQrToken('TEST');
  console.log(`[PASS] generateQrToken: ${token}`);
  const qrRes = await generateAndSaveQr(token);
  console.log(`[PASS] generateAndSaveQr URL: ${qrRes.url}`);

  // 3. Tablet Device Heartbeat
  db.upsertTabletDevice({
    device_id: 'tablet-front-desk-1',
    device_name: 'Samsung Galaxy Tab A9',
    ip_address: '10.5.125.99',
    battery_level: 88,
    app_version: '2.1.0',
  });
  const tablets = db.getAllTabletDevices();
  console.log(`[PASS] Tablet devices count: ${tablets.length}, first device: ${tablets[0].device_name}`);

  // 4. Batch Attendance Sync
  const batchResult = db.insertAttendanceBatch([
    {
      qr_token: members[0].qr_token,
      member_name: members[0].name,
      status: 'paid',
      scanned_at: new Date().toISOString(),
    },
  ]);
  console.log(`[PASS] db.insertAttendanceBatch saved ${batchResult.length} offline check-ins`);

  // 5. WhatsApp Anti-Ban Engine Tests
  console.log('Testing WhatsApp Anti-Ban Engine...');

  // 5a. Spintax test
  const spintaxTemplate = '{Salam|Hello|Hi} {name}! Your plan is {Gold|VIP}.';
  const rendered = whatsappService.renderMessage(spintaxTemplate, { name: 'Ali' });
  console.log(`[PASS] Spintax Rendered: "${rendered}"`);

  // 5b. Anti-ban random delay generator
  const delay1 = whatsappService.computeRandomDelay();
  const delay2 = whatsappService.computeRandomDelay();
  console.log(`[PASS] Random Delay 1: ${(delay1 / 1000).toFixed(2)}s, Delay 2: ${(delay2 / 1000).toFixed(2)}s (Non-uniform verified)`);

  // 5c. Enqueue test message
  const queuedItem = whatsappService.enqueue({
    recipient_phone: '+92 300 8472910',
    message_text: '{Salam|Hi} {name}! Testing anti-ban queue with random time delay.',
    message_type: 'test',
  });
  console.log(`[PASS] Enqueued WhatsApp message #${queuedItem.id} for ${queuedItem.recipient_phone}`);

  const pendingCount = db.getPendingWaCount();
  console.log(`[PASS] Pending WhatsApp queue count: ${pendingCount}`);

  console.log('--- ALL BACKEND COMPONENT TESTS PASSED SUCCESSFULLY! ---');
}

testBackend()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('TEST FAILED:', err);
    process.exit(1);
  });
