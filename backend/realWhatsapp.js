const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
  delay,
} = require('@whiskeysockets/baileys');
const pino = require('pino');
const QRCode = require('qrcode');
const qrcodeTerminal = require('qrcode-terminal');
const fs = require('fs');
const path = require('path');

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
    this.connectedUser = null;
    this.lastError = null;
    this.lastConnectedAt = null;
    this.broadcastFn = null;
    this.isInitializing = false;
    this.reconnectTimer = null;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 10;

    // Ensure session directory exists
    if (!fs.existsSync(this.authDir)) {
      try {
        fs.mkdirSync(this.authDir, { recursive: true });
      } catch (e) {
        console.error('[Real WhatsApp] Failed to create auth directory:', e.message);
      }
    }
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
      connectedUser: this.connectedUser,
      lastConnectedAt: this.lastConnectedAt,
      lastError: this.lastError,
      authDirExists: fs.existsSync(this.authDir),
      hasStoredSession: this.hasStoredSession(),
    };
  }

  hasStoredSession() {
    try {
      if (!fs.existsSync(this.authDir)) return false;
      const files = fs.readdirSync(this.authDir);
      return files.some((f) => f.startsWith('creds.json'));
    } catch (_) {
      return false;
    }
  }

  /**
   * Initializes the WhatsApp Web connection
   */
  async init() {
    if (this.isInitializing || this.status === 'connected') {
      return;
    }
    this.isInitializing = true;
    this.status = 'connecting';
    this.lastError = null;

    console.log('[Real WhatsApp] Initializing multi-device connection...');
    this.broadcast('whatsapp:real:status', { status: 'connecting' });

    try {
      // 1. Load multi-file auth credentials
      const { state, saveCreds } = await useMultiFileAuthState(this.authDir);

      // 2. Fetch latest WhatsApp Web version
      let version;
      try {
        const versionInfo = await fetchLatestBaileysVersion();
        version = versionInfo.version;
      } catch (err) {
        // Fallback version if offline or registry timeout
        version = [2, 3000, 1015901307];
      }

      // 3. Create Baileys Socket
      this.sock = makeWASocket({
        version,
        logger: pino({ level: 'silent' }), // Suppress internal protocol trace
        printQRInTerminal: false, // We render via qrcodeTerminal manually for clean formatting
        auth: state,
        browser: ['Titan Gym System', 'Chrome', '124.0.0.0'],
        connectTimeoutMs: 60000,
        keepAliveIntervalMs: 30000,
        defaultQueryTimeoutMs: 60000,
        generateHighQualityLinkPreview: true,
        syncFullHistory: false,
      });

      // 4. Bind credential updates
      this.sock.ev.on('creds.update', saveCreds);

      // 5. Connection Updates (QR code, Open, Close)
      this.sock.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect, qr } = update;

        if (qr) {
          this.qrCodeRaw = qr;
          try {
            this.qrCodeDataUrl = await QRCode.toDataURL(qr, {
              margin: 2,
              width: 320,
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
          this.qrCodeRaw = null;
          this.qrCodeDataUrl = null;
          this.lastConnectedAt = new Date().toISOString();

          const user = this.sock.user || {};
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
          const shouldReconnect = statusCode !== DisconnectReason.loggedOut;
          this.status = 'disconnected';
          this.lastError = lastDisconnect?.error?.message || `Closed with code ${statusCode}`;

          console.warn(`[Real WhatsApp] Connection closed (code: ${statusCode}, reason: ${this.lastError})`);

          if (statusCode === DisconnectReason.loggedOut) {
            console.log('[Real WhatsApp] Logged out by device. Cleaning session credentials...');
            this.clearSessionFiles();
            this.connectedUser = null;
            this.qrCodeRaw = null;
            this.qrCodeDataUrl = null;
            this.broadcast('whatsapp:real:logged_out', { message: 'Logged out by device' });
            // Prepare a fresh QR code
            setTimeout(() => this.init(), 2000);
          } else if (shouldReconnect) {
            this.scheduleReconnect();
          }
        }
      });
    } catch (err) {
      this.status = 'disconnected';
      this.lastError = err.message;
      console.error('[Real WhatsApp Init Error]:', err.message);
      this.scheduleReconnect();
    } finally {
      this.isInitializing = false;
    }
  }

  scheduleReconnect() {
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.warn(`[Real WhatsApp] Reached max reconnect attempts (${this.maxReconnectAttempts}). Standing by.`);
      return;
    }
    this.reconnectAttempts++;
    const delayMs = Math.min(3000 * Math.pow(1.5, this.reconnectAttempts - 1), 30000);
    console.log(`[Real WhatsApp] Reconnecting in ${(delayMs / 1000).toFixed(1)}s (attempt ${this.reconnectAttempts})...`);
    this.reconnectTimer = setTimeout(() => {
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
   * Sends a real WhatsApp message to an international phone number
   * Includes human typing simulation and recipient existence verification.
   */
  async sendRealMessage(phone, messageText) {
    if (this.status !== 'connected' || !this.sock) {
      throw new Error(
        'Real WhatsApp Web is NOT connected. Please link your phone by scanning the QR code in the Gym Control Center.'
      );
    }

    const clean = String(phone).replace(/[^0-9]/g, '');
    if (clean.length < 9) {
      throw new Error(`Invalid phone number format: "${phone}"`);
    }

    const jid = `${clean}@s.whatsapp.net`;

    try {
      // 1. Verify recipient is registered on WhatsApp
      let targetJid = jid;
      try {
        const results = await this.sock.onWhatsApp(jid);
        if (results && results.length > 0) {
          const matched = results[0];
          if (matched.exists) {
            targetJid = matched.jid;
          } else {
            throw new Error(`Recipient +${clean} is not registered on WhatsApp.`);
          }
        }
      } catch (err) {
        // If check failed with a non-fatal error, continue with targetJid
        if (err.message.includes('not registered')) {
          throw err;
        }
      }

      // 2. Anti-Ban Human Emulation: Send 'composing' typing indicator
      try {
        await this.sock.sendPresenceUpdate('composing', targetJid);
      } catch (_) {}

      // 3. Human typing delay based on message length (1.2s - 2.8s)
      const typingTime = Math.min(2800, Math.max(1200, messageText.length * 20));
      await delay(typingTime);

      // 4. Send 'paused' typing indicator
      try {
        await this.sock.sendPresenceUpdate('paused', targetJid);
      } catch (_) {}

      // 5. Send actual message over WhatsApp socket
      const sent = await this.sock.sendMessage(targetJid, {
        text: messageText,
      });

      console.log(`[Real WhatsApp] Message successfully delivered to +${clean} (ID: ${sent?.key?.id})`);

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
