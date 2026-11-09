const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
  DEFAULT_CONNECTION_CONFIG,
  Browsers,
  delay,
} = require('@whiskeysockets/baileys');
const pino = require('pino');
const QRCode = require('qrcode');
const qrcodeTerminal = require('qrcode-terminal');
const fs = require('fs');
const path = require('path');
const dns = require('dns');

// Force IPv4 first and add DNS fallback for web.whatsapp.com when Windows/Emulator DNS blips
try {
  if (typeof dns.setDefaultResultOrder === 'function') {
    dns.setDefaultResultOrder('ipv4first');
  }
} catch (_) {}

const publicResolver = new dns.Resolver();
try {
  publicResolver.setServers(['8.8.8.8', '1.1.1.1', '8.8.4.4']);
} catch (_) {}

const dnsCache = new Map([
  ['web.whatsapp.com', '57.144.149.32'],
]);

const originalLookup = dns.lookup.bind(dns);
dns.lookup = function (hostname, options, callback) {
  let cb = callback;
  let opts = options;
  if (typeof options === 'function') {
    cb = options;
    opts = {};
  }
  return originalLookup(hostname, opts, (err, address, family) => {
    if (!err && address) {
      if (typeof address === 'string') {
        dnsCache.set(hostname, address);
      }
      return cb(null, address, family);
    }
    // Fallback to public DNS (8.8.8.8 / 1.1.1.1) if OS getaddrinfo fails with ENOTFOUND
    publicResolver.resolve4(hostname, (resolveErr, addresses) => {
      const ip = (!resolveErr && addresses && addresses[0]) || dnsCache.get(hostname);
      if (ip) {
        dnsCache.set(hostname, ip);
        if (opts && opts.all) {
          return cb(null, [{ address: ip, family: 4 }]);
        }
        return cb(null, ip, 4);
      }
      return cb(err, address, family);
    });
  });
};

/**
 * Real WhatsApp Web Connection Manager using Baileys Multi-Device Socket
 *
 * Capabilities:
 * - Scans QR code or pairs via 8-digit mobile code
 * - Persistent session storage in ./whatsapp_auth_session (re-connects on server restart)
 * - Checks recipient existence on WhatsApp network before dispatch
 * - Human typing presence emulation (composing -> delay -> paused -> message)
 * - Real-time QR streaming to Web UI & WebSockets
 * - Zero external monthly subscriptions or cloud gateway fees
 */
class RealWhatsAppManager {
  constructor() {
    this.authDir = path.join(__dirname, 'whatsapp_auth_session');
    this.sock = null;
    this.status = 'disconnected'; // 'disconnected' | 'connecting' | 'qr_ready' | 'connected'
    this.qrCodeRaw = null;
    this.qrCodeDataUrl = null;
    this.qrCodeGeneratedAt = null;
    this.connectedUser = null;
    this.lastError = null;
    this.lastConnectedAt = null;
    this.connectingSince = null;
    this.broadcastFn = null;
    this.isInitializing = false;
    this.reconnectTimer = null;
    this.reconnectAttempts = 0;

    // Ensure session directory exists
    if (!fs.existsSync(this.authDir)) {
      try {
        fs.mkdirSync(this.authDir, { recursive: true });
      } catch (e) {
        console.error('[Real WhatsApp] Failed to create auth directory:', e.message);
      }
    }

    // Load cached user info if already paired on disk
    this.restoreCachedUserFromDisk();

    // Persistent watchdog: ensures paired sessions stay connected 24/7 across sleep/wake & network drops
    this.watchdogTimer = setInterval(() => {
      this.runConnectionWatchdog();
    }, 15000);
    if (this.watchdogTimer && typeof this.watchdogTimer.unref === 'function') {
      this.watchdogTimer.unref();
    }
  }

  restoreCachedUserFromDisk() {
    try {
      const credsPath = path.join(this.authDir, 'creds.json');
      if (!fs.existsSync(credsPath)) return;
      const creds = JSON.parse(fs.readFileSync(credsPath, 'utf8'));
      if (creds && creds.me && creds.me.id) {
        const rawId = creds.me.id;
        const phone = rawId.split('@')[0].split(':')[0];
        this.connectedUser = {
          id: rawId,
          phone,
          name: creds.me.name || creds.me.notify || 'Gym WhatsApp',
        };
      }
    } catch (_) {}
  }

  isRegisteredSession() {
    try {
      const credsPath = path.join(this.authDir, 'creds.json');
      if (!fs.existsSync(credsPath)) return false;
      const creds = JSON.parse(fs.readFileSync(credsPath, 'utf8'));
      return Boolean(creds && (creds.registered === true || (creds.me && creds.me.id)));
    } catch (_) {
      return false;
    }
  }

  runConnectionWatchdog() {
    try {
      // 1. If stuck in 'connecting' for > 40s without opening or generating QR, force restart
      if (
        (this.status === 'connecting' || this.isInitializing) &&
        this.connectingSince &&
        Date.now() - this.connectingSince > 40000
      ) {
        console.warn('[Real WhatsApp Watchdog] Connection attempt stalled >40s. Forcing clean restart...');
        this.isInitializing = false;
        this.status = 'disconnected';
        this.init();
        return;
      }

      // 2. If disconnected and no reconnect timer is pending, trigger reconnect immediately
      if (this.status === 'disconnected' && !this.isInitializing && !this.reconnectTimer) {
        this.reconnectAttempts = 0;
        this.init();
      }
    } catch (_) {}
  }

  setBroadcaster(fn) {
    this.broadcastFn = fn;
  }

  broadcast(event, data) {
    if (this.broadcastFn) {
      try {
        this.broadcastFn(event, data);
      } catch (err) {
        console.error('[Real WhatsApp] Broadcast error:', err.message);
      }
    }
  }

  getStatus() {
    return {
      status: this.status,
      isConnected: this.status === 'connected',
      qrCodeDataUrl: this.qrCodeDataUrl,
      rawQr: this.qrCodeRaw,
      qrCodeGeneratedAt: this.qrCodeGeneratedAt,
      connectedUser: this.connectedUser,
      lastConnectedAt: this.lastConnectedAt,
      lastError: this.lastError,
      authDirExists: fs.existsSync(this.authDir),
      hasStoredSession: this.isRegisteredSession(),
    };
  }

  hasStoredSession() {
    return this.isRegisteredSession();
  }

  /**
   * Ensures a fresh, live QR session is started immediately when requested by the UI
   */
  async startFreshQrSession(forceReset = false) {
    if (this.status === 'connected') {
      return this.getStatus();
    }

    // If we already have a fresh QR (< 18s old) and caller didn't ask for a hard reset, keep it alive
    if (
      !forceReset &&
      this.status === 'qr_ready' &&
      this.qrCodeDataUrl &&
      this.qrCodeGeneratedAt &&
      Date.now() - this.qrCodeGeneratedAt < 18000
    ) {
      return this.getStatus();
    }

    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    this.reconnectAttempts = 0;

    // If not yet registered (or if forceReset requested while not connected), wipe any partial/corrupted auth files
    if (!this.isRegisteredSession()) {
      this.clearSessionFiles();
    }

    // If currently disconnected or forceReset requested, start fresh socket right away
    if (forceReset || this.status === 'disconnected' || !this.qrCodeDataUrl) {
      this.isInitializing = false;
      this.qrCodeRaw = null;
      this.qrCodeDataUrl = null;
      this.qrCodeGeneratedAt = null;
      await this.init();
    }

    return this.getStatus();
  }

  /**
   * Initializes the WhatsApp Web connection
   */
  async init() {
    if (this.isInitializing || this.status === 'connected') {
      return;
    }
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    this.isInitializing = true;
    this.status = 'connecting';
    this.connectingSince = Date.now();
    this.lastError = null;

    // Cleanly close any lingering previous socket before re-initializing
    if (this.sock) {
      try {
        this.sock.ev.removeAllListeners();
        if (this.sock.ws && typeof this.sock.ws.close === 'function') {
          this.sock.ws.close();
        }
      } catch (_) {}
      this.sock = null;
    }

    // If session on disk is incomplete/unregistered and not in the middle of a pairing handshake, start clean
    if (!this.isRegisteredSession()) {
      this.clearSessionFiles();
    } else {
      this.restoreCachedUserFromDisk();
    }

    console.log('[Real WhatsApp] Initializing multi-device connection...');
    this.broadcast('whatsapp:real:status', { status: 'connecting' });

    try {
      // 1. Load multi-file auth credentials
      const { state, saveCreds } = await useMultiFileAuthState(this.authDir);

      // 2. Fetch latest WhatsApp Web version (with fast fallback to built-in Baileys version)
      let version = (DEFAULT_CONNECTION_CONFIG && DEFAULT_CONNECTION_CONFIG.version) || [2, 3000, 1043857760];
      try {
        const versionInfo = await Promise.race([
          fetchLatestBaileysVersion(),
          new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 3000)),
        ]);
        if (versionInfo && versionInfo.version) {
          version = versionInfo.version;
        }
      } catch (_) {
        // Keep up-to-date built-in version
      }

      // 3. Create Baileys Socket with standard official Ubuntu/Chrome multi-device signature
      const activeSock = makeWASocket({
        version,
        logger: pino({ level: 'silent' }),
        printQRInTerminal: false,
        auth: state,
        browser: Browsers && typeof Browsers.ubuntu === 'function'
          ? Browsers.ubuntu('Chrome')
          : ['Ubuntu', 'Chrome', '22.04.4'],
        connectTimeoutMs: 60000,
        keepAliveIntervalMs: 25000,
        defaultQueryTimeoutMs: 60000,
        retryRequestDelayMs: 1000,
        markOnlineOnConnect: false,
        generateHighQualityLinkPreview: false,
        syncFullHistory: false,
      });

      this.sock = activeSock;

      // Prevent unhandled WebSocket errors from crashing the process on network changes
      if (activeSock.ws && typeof activeSock.ws.on === 'function') {
        activeSock.ws.on('error', (wsErr) => {
          console.warn('[Real WhatsApp WS Notice]:', wsErr.message);
        });
      }

      // 4. Bind credential updates
      activeSock.ev.on('creds.update', async () => {
        try {
          await saveCreds();
          this.restoreCachedUserFromDisk();
        } catch (err) {
          console.error('[Real WhatsApp] Failed to save creds:', err.message);
        }
      });

      // 5. Connection Updates (QR code, Open, Close)
      activeSock.ev.on('connection.update', async (update) => {
        // Ignore events from superseded sockets
        if (this.sock !== activeSock) return;

        const { connection, lastDisconnect, qr } = update;

        if (qr) {
          this.qrCodeRaw = qr;
          this.qrCodeGeneratedAt = Date.now();
          this.connectingSince = Date.now();
          try {
            this.qrCodeDataUrl = await QRCode.toDataURL(qr, {
              errorCorrectionLevel: 'M',
              margin: 3,
              width: 360,
              color: { dark: '#000000', light: '#ffffff' },
            });
          } catch (e) {
            console.error('[Real WhatsApp] QR DataURL error:', e.message);
          }

          this.status = 'qr_ready';
          console.log('\n============================================================');
          console.log('  [WHATSAPP WEB PAIRING] SCAN THIS QR CODE WITH YOUR PHONE:');
          console.log('  Open WhatsApp -> Settings / Menu -> Linked Devices -> Link a Device');
          console.log('============================================================\n');
          try {
            qrcodeTerminal.generate(qr, { small: true });
          } catch (_) {}

          this.broadcast('whatsapp:real:qr', {
            qrCodeDataUrl: this.qrCodeDataUrl,
            rawQr: qr,
            status: 'qr_ready',
          });
        }

        if (connection === 'open') {
          this.status = 'connected';
          this.reconnectAttempts = 0;
          this.connectingSince = null;
          this.qrCodeRaw = null;
          this.qrCodeDataUrl = null;
          this.qrCodeGeneratedAt = null;
          this.lastError = null;
          this.lastConnectedAt = new Date().toISOString();

          const user = activeSock.user || state.creds?.me || {};
          const rawId = user.id || '';
          const phone = rawId.split('@')[0].split(':')[0];

          this.connectedUser = {
            id: rawId,
            phone: phone,
            name: user.name || user.notify || 'Gym WhatsApp',
          };

          console.log(`\n✅ [Real WhatsApp Connected] Authenticated as +${phone} (${this.connectedUser.name})`);
          console.log('   Real WhatsApp message sending is now ACTIVE!\n');

          this.broadcast('whatsapp:real:connected', {
            status: 'connected',
            user: this.connectedUser,
            lastConnectedAt: this.lastConnectedAt,
          });
        }

        if (connection === 'close') {
          const statusCode = lastDisconnect?.error?.output?.statusCode;
          const isRegistered = this.isRegisteredSession();

          // Always clear expired QR code immediately so a dead QR is never shown
          this.qrCodeRaw = null;
          this.qrCodeDataUrl = null;
          this.qrCodeGeneratedAt = null;
          this.connectingSince = null;
          this.status = 'disconnected';
          this.lastError = lastDisconnect?.error?.message || `Closed with code ${statusCode}`;

          console.warn(
            `[Real WhatsApp] Connection closed (code: ${statusCode}, registered: ${isRegistered}, reason: ${this.lastError})`
          );

          // Case 1: Post-QR scan handshake (515 restartRequired) -> Reconnect IMMEDIATELY (<200ms)
          if (statusCode === DisconnectReason.restartRequired || statusCode === 515) {
            console.log('[Real WhatsApp] Pairing handshake restart required (515) — reconnecting immediately...');
            this.reconnectAttempts = 0;
            this.scheduleReconnect(150);
            return;
          }

          // Case 2: Explicitly logged out from phone (401) -> Clean credentials and prepare fresh QR
          if (statusCode === DisconnectReason.loggedOut || statusCode === 401) {
            console.log('[Real WhatsApp] Logged out by device (401). Cleaning session credentials...');
            this.clearSessionFiles();
            this.connectedUser = null;
            this.reconnectAttempts = 0;
            this.broadcast('whatsapp:real:logged_out', { message: 'Logged out by device' });
            this.scheduleReconnect(1000);
            return;
          }

          // Case 3: Unregistered session failed with bad/rejected auth -> Clean partial files and get fresh QR
          if (!isRegistered && (statusCode === 403 || statusCode === 405 || statusCode === 500)) {
            console.log(`[Real WhatsApp] Unregistered session rejected (${statusCode}). Resetting for fresh QR...`);
            this.clearSessionFiles();
            this.reconnectAttempts = 0;
            this.scheduleReconnect(800);
            return;
          }

          // Case 4: All other disconnects (network drop, Wi-Fi blip, QR timeout, 408, 428, 503)
          // Keep session intact and reconnect automatically without ever giving up!
          this.scheduleReconnect();
        }
      });
    } catch (err) {
      this.status = 'disconnected';
      this.connectingSince = null;
      this.lastError = err.message;
      console.error('[Real WhatsApp Init Error]:', err.message);
      this.scheduleReconnect();
    } finally {
      this.isInitializing = false;
    }
  }

  scheduleReconnect(customDelayMs = null) {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    let delayMs = customDelayMs;
    if (delayMs === null) {
      this.reconnectAttempts++;
      if (this.isRegisteredSession()) {
        // Already paired phone: reconnect very quickly (1s -> 2s -> max 8s) and NEVER stop trying
        delayMs = Math.min(1000 * Math.pow(1.4, this.reconnectAttempts - 1), 8000);
      } else {
        // Waiting for QR scan: refresh QR socket quickly (1.5s -> max 6s)
        delayMs = Math.min(1500 * Math.pow(1.3, this.reconnectAttempts - 1), 6000);
      }
    }

    console.log(
      `[Real WhatsApp] Reconnecting in ${(delayMs / 1000).toFixed(2)}s (attempt ${this.reconnectAttempts || 1})...`
    );
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.init();
    }, delayMs);
  }

  /**
   * Cleans session auth folder
   */
  clearSessionFiles() {
    try {
      if (fs.existsSync(this.authDir)) {
        const files = fs.readdirSync(this.authDir);
        for (const file of files) {
          const filePath = path.join(this.authDir, file);
          try {
            if (fs.lstatSync(filePath).isDirectory()) {
              fs.rmSync(filePath, { recursive: true, force: true });
            } else {
              fs.unlinkSync(filePath);
            }
          } catch (_) {}
        }
      } else {
        fs.mkdirSync(this.authDir, { recursive: true });
      }
    } catch (err) {
      console.error('[Real WhatsApp] Error clearing session:', err.message);
    }
  }

  /**
   * Request an 8-digit mobile pairing code instead of scanning a QR code
   */
  async requestPairingCode(phoneNumber) {
    if (!phoneNumber) {
      throw new Error('Valid phone number is required for pairing code');
    }
    const clean = String(phoneNumber).replace(/[^0-9]/g, '');
    if (!this.sock) {
      await this.init();
      // Wait for socket readiness
      await delay(2000);
    }
    if (!this.sock || typeof this.sock.requestPairingCode !== 'function') {
      throw new Error('Pairing code not supported in current socket state');
    }

    try {
      const code = await this.sock.requestPairingCode(clean);
      console.log(`[Real WhatsApp] Pairing code generated for +${clean}: ${code}`);
      return { success: true, code, phone: clean };
    } catch (err) {
      throw new Error(`Failed to request pairing code: ${err.message}`);
    }
  }

  /**
   * Waits for an active WhatsApp socket connection (e.g. if reconnecting after a brief network blip)
   */
  async waitForConnection(timeoutMs = 25000) {
    if (this.status === 'connected' && this.sock) return true;
    if (!this.hasStoredSession() && this.status === 'qr_ready') return false;

    if (this.status === 'disconnected' && !this.isInitializing) {
      if (this.reconnectTimer) {
        clearTimeout(this.reconnectTimer);
        this.reconnectTimer = null;
      }
      this.init();
    }

    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
      if (this.status === 'connected' && this.sock) return true;
      await delay(500);
    }
    return this.status === 'connected' && !!this.sock;
  }

  /**
   * Sends a real WhatsApp message (or Image + Caption) to an international phone number
   * Includes human typing simulation and recipient existence verification.
   */
  async sendRealMessage(phone, messageText, options = {}) {
    if (this.status !== 'connected' || !this.sock) {
      if (this.hasStoredSession()) {
        console.log('[Real WhatsApp] Waiting for active session reconnection before sending message...');
        await this.waitForConnection(25000);
      }
    }

    if (this.status !== 'connected' || !this.sock) {
      throw new Error(
        'Real WhatsApp Web is NOT connected. Please link your phone by scanning the QR code in the Gym Control Center.'
      );
    }

    let clean = String(phone).replace(/[^0-9+]/g, '');
    if (clean.startsWith('0092')) {
      clean = '92' + clean.slice(4);
    } else if (clean.startsWith('+92')) {
      clean = '92' + clean.slice(3);
    } else if (clean.startsWith('03')) {
      clean = '92' + clean.slice(1);
    } else if (clean.startsWith('3') && clean.length === 10) {
      clean = '92' + clean;
    } else if (clean.startsWith('+')) {
      clean = clean.slice(1);
    }
    clean = clean.replace(/[^0-9]/g, '');

    if (clean.length < 9) {
      throw new Error(`Invalid phone number format: "${phone}"`);
    }

    const jid = `${clean}@s.whatsapp.net`;

    try {
      // 1. Resolve canonical JID if available (without blocking or failing on privacy-protected numbers)
      let targetJid = jid;
      try {
        const results = await Promise.race([
          this.sock.onWhatsApp(jid),
          new Promise((resolve) => setTimeout(() => resolve(null), 3000)),
        ]);
        if (results && results.length > 0) {
          const matched = results[0];
          if (matched && matched.exists && matched.jid && String(matched.jid).endsWith('@s.whatsapp.net')) {
            targetJid = matched.jid;
          }
        }
      } catch (_) {}

      // 2. Anti-Ban Human Emulation: Send 'composing' typing indicator
      try {
        await this.sock.sendPresenceUpdate('composing', targetJid);
      } catch (_) {}

      // 3. Human typing delay (600ms - 1200ms)
      const textLen = (messageText || '').length;
      const typingTime = Math.min(1200, Math.max(600, textLen * 10));
      await delay(typingTime);

      // 4. Send 'paused' typing indicator
      try {
        await this.sock.sendPresenceUpdate('paused', targetJid);
      } catch (_) {}

      // 5. Resolve optional image attachment (Full Member Pass Card PNG or QR Code PNG)
      let imageBuffer = options.imageBuffer || null;
      if (!imageBuffer && options.imagePath) {
        try {
          const publicCandidate = path.join(
            __dirname,
            'public',
            String(options.imagePath).replace(/^[/\\]+/, '')
          );
          if (fs.existsSync(publicCandidate)) {
            imageBuffer = fs.readFileSync(publicCandidate);
          } else if (fs.existsSync(options.imagePath)) {
            imageBuffer = fs.readFileSync(options.imagePath);
          } else {
            console.warn('[Real WhatsApp] Image file not found on disk:', publicCandidate);
          }
        } catch (imgErr) {
          console.warn('[Real WhatsApp] Could not read image attachment:', imgErr.message);
        }
      }

      // 6. Send actual message (Standalone Pass Image OR Text) over WhatsApp socket
      let sent;
      if (imageBuffer) {
        let finalBuffer = imageBuffer;
        let finalMime = 'image/jpeg';

        try {
          const sharpMod = await import('sharp');
          const sharpFn = sharpMod.default || sharpMod;
          if (typeof sharpFn === 'function') {
            finalBuffer = await sharpFn(imageBuffer)
              .flatten({ background: '#0F0F13' })
              .jpeg({ quality: 92 })
              .toBuffer();
            finalMime = 'image/jpeg';
          }
        } catch (sharpErr) {
          console.warn('[Real WhatsApp] Sharp conversion fallback to raw buffer:', sharpErr.message);
          finalMime = 'image/png';
        }

        const mediaPayload = {
          image: finalBuffer,
          mimetype: finalMime,
        };
        // Only attach caption if non-empty text was explicitly provided
        if (messageText && messageText.trim().length > 0) {
          mediaPayload.caption = messageText.trim();
        }

        sent = await this.sock.sendMessage(targetJid, mediaPayload);
        console.log(`[Real WhatsApp] Standalone Pass Image (${finalMime}, ${finalBuffer.length} bytes) delivered to +${clean} (ID: ${sent?.key?.id})`);
      } else {
        if (!messageText || !messageText.trim()) {
          throw new Error('Cannot send empty WhatsApp message: image attachment could not be loaded.');
        }
        sent = await this.sock.sendMessage(targetJid, {
          text: messageText,
        });
        console.log(`[Real WhatsApp] Message successfully delivered to +${clean} (ID: ${sent?.key?.id})`);
      }

      return {
        success: true,
        status: 'delivered',
        messageId: sent?.key?.id,
        to: clean,
        targetJid,
        timestamp: sent?.messageTimestamp || Math.floor(Date.now() / 1000),
      };
    } catch (err) {
      console.error(`[Real WhatsApp Send Failed] to +${clean}:`, err.message);
      throw err;
    }
  }

  /**
   * Logs out current device session and triggers fresh pairing QR
   */
  async logout() {
    try {
      if (this.sock) {
        try {
          await this.sock.logout();
        } catch (_) {}
      }
    } finally {
      this.clearSessionFiles();
      this.connectedUser = null;
      this.status = 'disconnected';
      this.qrCodeRaw = null;
      this.qrCodeDataUrl = null;
      this.lastConnectedAt = null;
      this.broadcast('whatsapp:real:logged_out', { message: 'Logged out successfully' });

      // Restart socket to generate new QR
      setTimeout(() => this.init(), 1500);
      return { success: true, message: 'WhatsApp session cleared. Scan new QR code.' };
    }
  }
}

// Singleton instance
const realWhatsAppManager = new RealWhatsAppManager();

module.exports = realWhatsAppManager;
