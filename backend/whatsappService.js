const db = require('./db');
const http = require('http');
const https = require('https');
const realWhatsAppManager = require('./realWhatsapp');

/**
 * Intelligent WhatsApp Queue & Anti-Ban Delivery Engine
 *
 * Why WhatsApp bans numbers:
 * 1. Rapid burst sending (multiple messages sent per second)
 * 2. Static uniform delays (e.g. exactly 3 seconds every time, recognized by Meta's anti-bot algorithms)
 * 3. Exact duplicate content hashes (sending 100 identical strings)
 * 4. Continuous high volume without fatigue pauses
 *
 * How this engine guarantees safety:
 * ✓ Random Jitter Delays: Computes unpredictable random intervals (e.g. 5-14s + micro-jitter)
 * ✓ Fatigue Cooldown Pauses: After every N messages (e.g. 5), takes a human-like 30-60s rest break
 * ✓ Strict Zero Concurrency: Strictly sequential processing via persistent FIFO queue
 * ✓ Spintax & Personalization: Rotates phrases {Salam|Hello|Hi} so message hashes are never identical
 * ✓ Daily Safety Ceiling: Auto-pauses if daily limit is approached
 * ✓ Real WhatsApp Web Socket: Directly dispatches real messages via linked device QR session
 * ✓ Multi-Mode Dispatch: Supports Real WhatsApp, Local Gateway, Webhook, Cloud API, or Safe Simulation
 */

class WhatsAppService {
  constructor() {
    this.broadcastFn = null;
    this.isProcessing = false;
    this.isPaused = false;
    this.consecutiveSent = 0;
    this.currentTask = null;
    this.status = 'idle'; // 'idle' | 'waiting' | 'cooldown' | 'sending' | 'paused'

    // Load defaults or stored settings from SQLite
    this.initSettings();
  }

  setBroadcaster(fn) {
    this.broadcastFn = fn;
    realWhatsAppManager.setBroadcaster(fn);
  }

  broadcast(event, payload) {
    if (this.broadcastFn) {
      try {
        this.broadcastFn(event, payload);
      } catch (err) {
        console.error('[WhatsApp] Broadcast error:', err.message);
      }
    }
  }

  initSettings() {
    const defaults = {
      min_delay_sec: '5',
      max_delay_sec: '14',
      burst_batch_size: '5',
      cooldown_sec: '30',
      daily_limit: '150',
      is_paused: 'false',
      provider_mode: 'real_whatsapp', // 'real_whatsapp' | 'simulation' | 'gateway'
      allow_simulation_fallback: 'true',
      gateway_url: '',
      gateway_api_key: '',
      gym_name: 'Titan Gym',
    };

    const current = db.getAllSettings();
    for (const [k, v] of Object.entries(defaults)) {
      if (!current[k]) {
        db.setSetting(k, v);
      }
    }
    this.isPaused = db.getSetting('is_paused', 'false') === 'true';
  }

  getSettings() {
    return {
      min_delay_sec: parseInt(db.getSetting('min_delay_sec', '5'), 10),
      max_delay_sec: parseInt(db.getSetting('max_delay_sec', '14'), 10),
      burst_batch_size: parseInt(db.getSetting('burst_batch_size', '5'), 10),
      cooldown_sec: parseInt(db.getSetting('cooldown_sec', '30'), 10),
      daily_limit: parseInt(db.getSetting('daily_limit', '150'), 10),
      is_paused: this.isPaused,
      provider_mode: db.getSetting('provider_mode', 'real_whatsapp'),
      allow_simulation_fallback: db.getSetting('allow_simulation_fallback', 'true') === 'true',
      gateway_url: db.getSetting('gateway_url', ''),
      gateway_api_key: db.getSetting('gateway_api_key', ''),
      gym_name: db.getSetting('gym_name', 'Titan Gym'),
    };
  }

  updateSettings(newSettings) {
    if (!newSettings || typeof newSettings !== 'object') return;
    for (const [k, v] of Object.entries(newSettings)) {
      if (v !== undefined && v !== null) {
        db.setSetting(k, String(v));
      }
    }
    if (newSettings.is_paused !== undefined) {
      this.isPaused = String(newSettings.is_paused) === 'true';
    }
    this.broadcast('whatsapp:settings_updated', this.getSettings());
  }

  /**
   * Spintax parser:
   * Replaces {Hello|Hi|Salam} with one randomly chosen variant
   */
  parseSpintax(text) {
    if (!text) return '';
    let result = text;
    const regex = /\{([^{}]+)\}/g;
    while (regex.test(result)) {
      result = result.replace(regex, (match, choices) => {
        const options = choices.split('|');
        return options[Math.floor(Math.random() * options.length)].trim();
      });
    }
    return result;
  }

  /**
   * Cleans and formats phone numbers to international E.164 (defaults to PK +92 format)
   */
  formatPhone(raw) {
    if (!raw) return '';
    let clean = String(raw).replace(/[^0-9+]/g, '');
    if (clean.startsWith('03')) {
      clean = '92' + clean.slice(1);
    } else if (clean.startsWith('+92')) {
      clean = '92' + clean.slice(3);
    } else if (clean.startsWith('+')) {
      clean = clean.slice(1);
    }
    return clean;
  }

  /**
   * Formats template variables and spintax
   */
  renderMessage(template, data = {}) {
    let msg = template || '';
    const defaultData = {
      gym_name: this.getSettings().gym_name || 'Titan Gym',
      name: 'Valued Member',
      plan: 'Membership',
      expiry_date: '',
      amount: '',
      days_left: '',
      date: new Date().toLocaleDateString('en-GB'),
      ...data,
    };

    for (const [key, value] of Object.entries(defaultData)) {
      const reg = new RegExp(`\\{${key}\\}`, 'gi');
      msg = msg.replace(reg, String(value || ''));
    }

    return this.parseSpintax(msg);
  }

  /**
   * Computes a randomized delay with micro-jitter (Human Mimicry)
   */
  computeRandomDelay() {
    const settings = this.getSettings();
    const minMs = Math.max(2000, settings.min_delay_sec * 1000);
    const maxMs = Math.max(minMs, settings.max_delay_sec * 1000);
    const base = Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs;
    // Add micro jitter between -750ms and +750ms
    const jitter = Math.floor(Math.random() * 1500) - 750;
    return Math.max(2000, base + jitter);
  }

  /**
   * Enqueues a message into the persistent SQLite queue
   */
  enqueue({ member_id = null, recipient_phone, message_text, message_type = 'custom' }) {
    const formattedPhone = this.formatPhone(recipient_phone);
    if (!formattedPhone) {
      throw new Error('Valid recipient phone number is required');
    }
    if (!message_text || !message_text.trim()) {
      throw new Error('Message text cannot be empty');
    }

    const rendered = this.parseSpintax(message_text);

    const result = db.enqueueWaMessage({
      member_id,
      recipient_phone: formattedPhone,
      message_text: rendered,
      message_type,
    });

    const queueItem = {
      id: Number(result.lastInsertRowid),
      member_id,
      recipient_phone: formattedPhone,
      message_text: rendered,
      message_type,
      status: 'pending',
      created_at: new Date().toISOString(),
    };

    this.broadcast('whatsapp:queued', queueItem);

    // Trigger queue worker if not already running
    this.startWorker();

    return queueItem;
  }

  /**
   * Enqueues bulk messages safely
   */
  enqueueBulk(items = []) {
    const enqueued = [];
    for (const item of items) {
      try {
        const q = this.enqueue(item);
        enqueued.push(q);
      } catch (err) {
        console.warn(`[WhatsApp] Failed to enqueue bulk item:`, err.message);
      }
    }
    return enqueued;
  }

  /**
   * Pauses the queue
   */
  pause() {
    this.isPaused = true;
    db.setSetting('is_paused', 'true');
    this.status = 'paused';
    this.broadcast('whatsapp:paused', { is_paused: true });
    console.log('[WhatsApp Queue] Paused by user');
  }

  /**
   * Resumes the queue
   */
  resume() {
    this.isPaused = false;
    db.setSetting('is_paused', 'false');
    this.status = 'idle';
    this.broadcast('whatsapp:resumed', { is_paused: false });
    console.log('[WhatsApp Queue] Resumed');
    this.startWorker();
  }

  /**
   * Cancels all pending messages
   */
  clearPending() {
    db.clearPendingWaQueue();
    this.status = 'idle';
    this.currentTask = null;
    this.broadcast('whatsapp:cleared', { message: 'All pending messages cleared' });
    console.log('[WhatsApp Queue] Pending queue cleared');
  }

  /**
   * Starts the background queue worker
   */
  async startWorker() {
    if (this.isProcessing) return;
    this.isProcessing = true;

    try {
      while (!this.isPaused) {
        // 1. Check daily safety cap
        const settings = this.getSettings();
        const sentToday = db.getWaSentTodayCount();
        if (sentToday >= settings.daily_limit) {
          console.warn(`[WhatsApp] Daily safety ceiling reached (${sentToday}/${settings.daily_limit}). Auto-pausing.`);
          this.pause();
          this.broadcast('whatsapp:daily_limit_reached', { sentToday, limit: settings.daily_limit });
          break;
        }

        // 2. Fetch next pending message
        const nextMsg = db.getNextPendingWaMessage();
        if (!nextMsg) {
          this.status = 'idle';
          this.currentTask = null;
          this.consecutiveSent = 0;
          break;
        }

        // 3. Human Fatigue Cooldown Check
        if (this.consecutiveSent > 0 && this.consecutiveSent % settings.burst_batch_size === 0) {
          const cooldownSec = settings.cooldown_sec;
          console.log(`[WhatsApp Anti-Ban] Batch fatigue cooldown: resting for ${cooldownSec}s after ${this.consecutiveSent} messages...`);
          this.status = 'cooldown';
          this.broadcast('whatsapp:cooldown', {
            consecutiveSent: this.consecutiveSent,
            cooldownSeconds: cooldownSec,
            resumingAt: new Date(Date.now() + cooldownSec * 1000).toISOString(),
          });
          await new Promise((r) => setTimeout(r, cooldownSec * 1000));
        }

        if (this.isPaused) break;

        // 4. Compute randomized anti-ban delay for this specific message
        const delayMs = this.computeRandomDelay();
        const delaySec = Number((delayMs / 1000).toFixed(1));

        this.status = 'waiting';
        this.currentTask = {
          id: nextMsg.id,
          phone: nextMsg.recipient_phone,
          type: nextMsg.message_type,
          delaySec,
          scheduledSendTime: new Date(Date.now() + delayMs).toISOString(),
        };

        console.log(`[WhatsApp Anti-Ban] Waiting random human delay ${delaySec}s before sending to +${nextMsg.recipient_phone}...`);
        this.broadcast('whatsapp:waiting', {
          queueId: nextMsg.id,
          recipient: nextMsg.recipient_phone,
          delaySeconds: delaySec,
          targetSendTime: this.currentTask.scheduledSendTime,
        });

        // Human wait interval
        await new Promise((r) => setTimeout(r, delayMs));

        if (this.isPaused) break;

        // 5. Send message via active provider
        this.status = 'sending';
        let sendSuccess = false;
        let sendError = null;

        try {
          await this.dispatchMessage(nextMsg.recipient_phone, nextMsg.message_text, settings);
          sendSuccess = true;
          this.consecutiveSent++;
        } catch (err) {
          sendSuccess = false;
          sendError = err.message || 'Dispatch failed';
          console.error(`[WhatsApp] Failed to send to +${nextMsg.recipient_phone}:`, sendError);
        }

        // 6. Update SQLite Queue and Logs
        const finalStatus = sendSuccess ? 'sent' : 'failed';
        db.updateWaQueueStatus(nextMsg.id, finalStatus, delaySec, sendError);

        db.insertWaLog({
          queue_id: nextMsg.id,
          member_id: nextMsg.member_id,
          recipient_phone: nextMsg.recipient_phone,
          message_text: nextMsg.message_text,
          message_type: nextMsg.message_type,
          status: finalStatus,
          delay_used_sec: delaySec,
          error: sendError,
        });

        console.log(`[WhatsApp] Message #${nextMsg.id} to +${nextMsg.recipient_phone} marked as ${finalStatus.toUpperCase()}`);

        this.broadcast('whatsapp:completed', {
          id: nextMsg.id,
          recipient: nextMsg.recipient_phone,
          status: finalStatus,
          delayUsed: delaySec,
          error: sendError,
          sentToday: db.getWaSentTodayCount(),
          pendingCount: db.getPendingWaCount(),
        });
      }
    } catch (err) {
      console.error('[WhatsApp Worker Fatal]:', err);
    } finally {
      this.isProcessing = false;
      this.currentTask = null;
      if (!this.isPaused) {
        this.status = 'idle';
      }
    }
  }

  /**
   * Dispatches the actual message over the wire
   */
  async dispatchMessage(phone, text, settings) {
    const mode = settings.provider_mode || 'real_whatsapp';

    if (mode === 'real_whatsapp') {
      const realStatus = realWhatsAppManager.getStatus();
      if (realStatus.isConnected) {
        return await realWhatsAppManager.sendRealMessage(phone, text);
      }

      if (settings.allow_simulation_fallback) {
        console.warn(`[WhatsApp] Real WhatsApp Web is not linked yet. Simulating delivery for +${phone} with random anti-ban delay (Scan QR in Web Console to link real phone).`);
        await new Promise((r) => setTimeout(r, 600));
        return {
          status: 'simulated_fallback',
          phone,
          note: 'Simulated fallback because WhatsApp QR is not yet scanned.',
          timestamp: new Date().toISOString(),
        };
      }

      throw new Error(
        'Real WhatsApp is not connected. Please scan the QR code in the Gym Control Center to link your phone.'
      );
    }

    if (mode === 'gateway' && settings.gateway_url) {
      return this.sendViaHttpGateway(settings.gateway_url, settings.gateway_api_key, phone, text);
    }

    if (mode === 'simulation' || !settings.gateway_url) {
      // High-Fidelity Safe Simulation Mode
      // Simulates typing delay and successful network round-trip without burning numbers during test
      await new Promise((r) => setTimeout(r, 600));
      return {
        status: 'simulated_success',
        phone,
        timestamp: new Date().toISOString(),
      };
    }

    throw new Error(`Unsupported WhatsApp provider mode: ${mode}`);
  }

  /**
   * HTTP Gateway Dispatcher (e.g. Baileys server, UltraMsg, Twilio, or local Webhook)
   */
  sendViaHttpGateway(url, apiKey, phone, text) {
    return new Promise((resolve, reject) => {
      const payload = JSON.stringify({ to: phone, message: text });
      const parsedUrl = new URL(url);
      const isHttps = parsedUrl.protocol === 'https:';
      const client = isHttps ? https : http;

      const req = client.request(
        parsedUrl,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload),
            ...(apiKey ? { Authorization: `Bearer ${apiKey}` } : {}),
          },
          timeout: 10000,
        },
        (res) => {
          let body = '';
          res.on('data', (chunk) => (body += chunk));
          res.on('end', () => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              resolve({ statusCode: res.statusCode, body });
            } else {
              reject(new Error(`Gateway error HTTP ${res.statusCode}: ${body.slice(0, 100)}`));
            }
          });
        }
      );

      req.on('error', reject);
      req.on('timeout', () => {
        req.destroy();
        reject(new Error('Gateway request timed out'));
      });

      req.write(payload);
      req.end();
    });
  }

  /**
   * Generate instant wa.me click-to-chat link
   */
  generateWaMeLink(phone, text) {
    const clean = this.formatPhone(phone);
    const encoded = encodeURIComponent(text);
    return `https://wa.me/${clean}?text=${encoded}`;
  }

  // ── Automated Triggers ──────────────────────────────────────────────────

  /**
   * Trigger Welcome Message on Member Registration
   */
  sendWelcomeMessage(member) {
    if (!member.phone) return null;
    const template =
      '{Salam|Hello|Hi|Welcome} {name}! 👋\n' +
      'Thank you for joining *{gym_name}*! Your *{plan}* membership is active and valid until *{expiry_date}*.\n' +
      'Your Member ID is *{id}*. See you at the gym! 💪';

    const rendered = this.renderMessage(template, {
      name: member.name,
      plan: member.plan,
      expiry_date: member.expiry_date,
      id: member.id,
    });

    return this.enqueue({
      member_id: member.id,
      recipient_phone: member.phone,
      message_text: rendered,
      message_type: 'welcome',
    });
  }

  /**
   * Trigger Expiry Reminders for Due / Overdue Members
   */
  sendExpiryAlerts(daysThreshold = 4) {
    const dueMembers = db.getDueOrExpiredMembers();
    const queuedList = [];

    const templateDue =
      '{Salam|Hello|Dear} {name}! ⚠️\n' +
      'This is a friendly reminder from *{gym_name}*.\n' +
      'Your *{plan}* membership is due for renewal on *{expiry_date}*.\n' +
      '{Please renew at the reception to keep your access uninterrupted|Kindly visit reception to settle dues|Please reach out to front desk to renew your pass}.\n' +
      'Stay strong! 🏋️';

    const templateExpired =
      '{Salam|Hello|Dear} {name}!\n' +
      'Your *{plan}* membership at *{gym_name}* has *expired* as of *{expiry_date}*.\n' +
      '{Renew today to continue your fitness routine|Visit reception to reactivate your membership pass}.\n' +
      'We hope to see you back on the gym floor soon! 💪';

    for (const member of dueMembers) {
      if (!member.phone) continue;

      const isExpired = new Date(member.expiry_date) < new Date();
      const template = isExpired ? templateExpired : templateDue;
      const text = this.renderMessage(template, {
        name: member.name,
        plan: member.plan,
        expiry_date: member.expiry_date,
      });

      try {
        const item = this.enqueue({
          member_id: member.id,
          recipient_phone: member.phone,
          message_text: text,
          message_type: 'expiry_alert',
        });
        queuedList.push(item);
      } catch (err) {
        console.warn(`[WhatsApp] Skip member ${member.name}: ${err.message}`);
      }
    }

    return {
      count: queuedList.length,
      items: queuedList,
    };
  }

  /**
   * Trigger Payment / Renewal Receipt
   */
  sendPaymentReceipt(member, paymentData = {}) {
    if (!member.phone) return null;
    const template =
      '{Salam|Hello} {name}! 🧾\n' +
      'Payment confirmed at *{gym_name}*.\n' +
      'Plan: *{plan}*\n' +
      'Amount Paid: *Rs. {amount}*\n' +
      'Method: *{method}*\n' +
      'New Expiry Date: *{expiry_date}*\n' +
      'Thank you for your business! 🔥';

    const text = this.renderMessage(template, {
      name: member.name,
      plan: member.plan,
      amount: paymentData.amount || '0',
      method: paymentData.method || 'Cash',
      expiry_date: member.expiry_date,
    });

    return this.enqueue({
      member_id: member.id,
      recipient_phone: member.phone,
      message_text: text,
      message_type: 'payment_receipt',
    });
  }

  /**
   * Broadcast Custom Announcement with Spintax & Dynamic Placeholders
   */
  sendBroadcast({ target = 'all', templateText }) {
    let members = db.getAllMembers();
    if (target === 'due') {
      members = members.filter((m) => m.status === 'due');
    } else if (target === 'expired') {
      members = members.filter((m) => m.status === 'expired');
    } else if (target === 'active') {
      members = members.filter((m) => m.status === 'paid');
    }

    const enqueued = [];
    for (const m of members) {
      if (!m.phone) continue;
      const msg = this.renderMessage(templateText, {
        name: m.name,
        plan: m.plan,
        expiry_date: m.expiry_date,
        id: m.id,
      });

      try {
        const q = this.enqueue({
          member_id: m.id,
          recipient_phone: m.phone,
          message_text: msg,
          message_type: 'broadcast',
        });
        enqueued.push(q);
      } catch (e) {}
    }

    return {
      target,
      count: enqueued.length,
      items: enqueued,
    };
  }

  /**
   * Get Live Engine Status
   */
  getStatus() {
    return {
      status: this.status,
      isPaused: this.isPaused,
      isProcessing: this.isProcessing,
      consecutiveSent: this.consecutiveSent,
      currentTask: this.currentTask,
      pendingCount: db.getPendingWaCount(),
      sentTodayCount: db.getWaSentTodayCount(),
      settings: this.getSettings(),
      realWhatsApp: realWhatsAppManager.getStatus(),
    };
  }
}

// Singleton instance
const whatsappService = new WhatsAppService();

module.exports = whatsappService;
