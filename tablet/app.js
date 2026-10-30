/**
 * Gym Kiosk Tablet App — Offline-First Scanner & PC Live Sync Engine
 */

// ── 1. IndexedDB Offline Storage Layer ──────────────────────────────────────
class GymKioskDB {
  constructor() {
    this.dbName = 'GymKioskOfflineDB';
    this.version = 1;
    this.db = null;
  }

  async init() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.dbName, this.version);

      request.onupgradeneeded = (e) => {
        const db = e.target.result;
        if (!db.objectStoreNames.contains('members')) {
          const mStore = db.createObjectStore('members', { keyPath: 'qr_token' });
          mStore.createIndex('id', 'id', { unique: false });
        }
        if (!db.objectStoreNames.contains('pending_scans')) {
          db.createObjectStore('pending_scans', { keyPath: 'id', autoIncrement: true });
        }
        if (!db.objectStoreNames.contains('kv')) {
          db.createObjectStore('kv', { keyPath: 'key' });
        }
      };

      request.onsuccess = (e) => {
        this.db = e.target.result;
        resolve(this);
      };

      request.onerror = (e) => {
        console.error('[DB] Failed to open IndexedDB:', e.target.error);
        reject(e.target.error);
      };
    });
  }

  async upsertMember(member) {
    if (!this.db || !member) return;
    return new Promise((resolve, reject) => {
      const tx = this.db.transaction('members', 'readwrite');
      const store = tx.objectStore('members');
      store.put({
        qr_token: member.qr_token || member.id,
        id: member.id || member.qr_token,
        name: member.name || 'Member',
        status: member.status || 'paid',
        expiry_date: member.expiry_date || '',
        phone: member.phone || '',
        plan: member.plan || 'Standard',
        email: member.email || '',
        gender: member.gender || '',
        updated_at: new Date().toISOString()
      });
      tx.oncomplete = () => resolve();
      tx.onerror = (e) => reject(e.target.error);
    });
  }

  async upsertMembers(membersList) {
    if (!this.db || !Array.isArray(membersList)) return 0;
    return new Promise((resolve, reject) => {
      const tx = this.db.transaction('members', 'readwrite');
      const store = tx.objectStore('members');
      for (const m of membersList) {
        store.put({
          qr_token: m.qr_token || m.id,
          id: m.id || m.qr_token,
          name: m.name || 'Member',
          status: m.status || 'paid',
          expiry_date: m.expiry_date || '',
          phone: m.phone || '',
          plan: m.plan || 'Standard',
          email: m.email || '',
          gender: m.gender || '',
          updated_at: new Date().toISOString()
        });
      }
      tx.oncomplete = () => resolve(membersList.length);
      tx.onerror = (e) => reject(e.target.error);
    });
  }

  async findMember(token) {
    if (!this.db || !token) return null;
    return new Promise((resolve) => {
      const tx = this.db.transaction('members', 'readonly');
      const store = tx.objectStore('members');
      const req = store.get(token);
      req.onsuccess = () => {
        if (req.result) {
          resolve(req.result);
        } else {
          // Fallback search by ID index
          const idx = store.index('id');
          const idReq = idx.get(token);
          idReq.onsuccess = () => resolve(idReq.result || null);
          idReq.onerror = () => resolve(null);
        }
      };
      req.onerror = () => resolve(null);
    });
  }

  async deleteMember(tokenOrId) {
    if (!this.db) return;
    return new Promise((resolve) => {
      const tx = this.db.transaction('members', 'readwrite');
      const store = tx.objectStore('members');
      store.delete(tokenOrId);
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
    });
  }

  async countMembers() {
    if (!this.db) return 0;
    return new Promise((resolve) => {
      const tx = this.db.transaction('members', 'readonly');
      const store = tx.objectStore('members');
      const req = store.count();
      req.onsuccess = () => resolve(req.result || 0);
      req.onerror = () => resolve(0);
    });
  }

  async queuePendingScan(scan) {
    if (!this.db) return;
    return new Promise((resolve, reject) => {
      const tx = this.db.transaction('pending_scans', 'readwrite');
      const store = tx.objectStore('pending_scans');
      store.add({
        ...scan,
        created_at: new Date().toISOString()
      });
      tx.oncomplete = () => resolve();
      tx.onerror = (e) => reject(e.target.error);
    });
  }

  async getPendingScans() {
    if (!this.db) return [];
    return new Promise((resolve) => {
      const tx = this.db.transaction('pending_scans', 'readonly');
      const store = tx.objectStore('pending_scans');
      const req = store.getAll();
      req.onsuccess = () => resolve(req.result || []);
      req.onerror = () => resolve([]);
    });
  }

  async clearPendingScans() {
    if (!this.db) return;
    return new Promise((resolve) => {
      const tx = this.db.transaction('pending_scans', 'readwrite');
      const store = tx.objectStore('pending_scans');
      store.clear();
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
    });
  }
}

// ── 2. Audio Chime Synthesizer (Web Audio API) ──────────────────────────────
class KioskAudio {
  constructor() {
    this.ctx = null;
    this.enabled = true;
  }

  init() {
    if (!this.ctx && (window.AudioContext || window.webkitAudioContext)) {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    }
  }

  playGranted() {
    if (!this.enabled) return;
    try {
      this.init();
      if (!this.ctx) return;
      if (this.ctx.state === 'suspended') this.ctx.resume();

      const now = this.ctx.currentTime;
      const osc1 = this.ctx.createOscillator();
      const osc2 = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc1.type = 'sine';
      osc2.type = 'triangle';

      // Chime note 1 (E5 - 659.25Hz), note 2 (G#5 - 830.61Hz)
      osc1.frequency.setValueAtTime(659.25, now);
      osc1.frequency.exponentialRampToValueAtTime(830.61, now + 0.12);

      osc2.frequency.setValueAtTime(659.25 / 2, now);
      osc2.frequency.exponentialRampToValueAtTime(830.61 / 2, now + 0.12);

      gain.gain.setValueAtTime(0.25, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.45);

      osc1.connect(gain);
      osc2.connect(gain);
      gain.connect(this.ctx.destination);

      osc1.start(now);
      osc2.start(now);
      osc1.stop(now + 0.45);
      osc2.stop(now + 0.45);
    } catch (_) {}
  }

  playWarning() {
    if (!this.enabled) return;
    try {
      this.init();
      if (!this.ctx) return;
      if (this.ctx.state === 'suspended') this.ctx.resume();

      const now = this.ctx.currentTime;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();

      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(220, now);
      osc.frequency.setValueAtTime(180, now + 0.15);

      gain.gain.setValueAtTime(0.25, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.4);

      osc.connect(gain);
      gain.connect(this.ctx.destination);

      osc.start(now);
      osc.stop(now + 0.4);
    } catch (_) {}
  }
}

// ── 3. Application State & Controller ───────────────────────────────────────
class TabletKioskApp {
  constructor() {
    this.db = new GymKioskDB();
    this.audio = new KioskAudio();
    this.html5QrCode = null;
    
    // Connection config
    this.serverUrl = localStorage.getItem('gym_server_url') || window.location.origin;
    if (this.serverUrl.endsWith('/')) this.serverUrl = this.serverUrl.slice(0, -1);
    this.deviceId = localStorage.getItem('gym_tablet_device_id') || ('tablet-' + Math.random().toString(36).substring(2, 9));
    localStorage.setItem('gym_tablet_device_id', this.deviceId);
    this.deviceName = localStorage.getItem('gym_tablet_device_name') || 'Front Desk Tablet Kiosk';

    this.isOnline = false;
    this.ws = null;
    this.wsReconnectTimer = null;
    this.heartbeatTimer = null;
    this.cachedMembersCount = 0;
    this.pendingScansCount = 0;

    // Camera settings
    this.facingMode = localStorage.getItem('gym_camera_facing') || 'environment'; // 'user' for front, 'environment' for back
    this.isScanningPaused = false;
    this.scanCooldownMs = 2400;

    // DOM Elements
    this.statusPill = document.getElementById('status-pill');
    this.statusText = document.getElementById('status-text');
    this.cachedCountEl = document.getElementById('cached-count');
    this.queueCountEl = document.getElementById('queue-count');
    this.queuePill = document.getElementById('queue-pill');
    this.resultOverlay = document.getElementById('result-overlay');
    this.resultCard = document.getElementById('result-card');
    this.cooldownBar = document.getElementById('cooldown-bar');
    this.drawerBackdrop = document.getElementById('drawer-backdrop');
    this.toastContainer = document.getElementById('toast-container');
    this.serverUrlInput = document.getElementById('server-url-input');
    this.deviceNameInput = document.getElementById('device-name-input');
    this.facingSelect = document.getElementById('facing-select');
    this.gymTitleEl = document.getElementById('gym-title');
  }

  async start() {
    console.log('[Kiosk] Initializing Tablet Kiosk App...');
    await this.db.init();

    this.initUI();
    await this.updateCounters();
    await this.initCamera();

    // Connect to PC Server
    this.connectToServer();
    this.startHeartbeat();

    // Register service worker if available
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/tablet/sw.js').then((reg) => {
        console.log('[SW] ServiceWorker registered with scope:', reg.scope);
      }).catch((err) => {
        console.log('[SW] ServiceWorker registration failed:', err);
      });
    }

    // Network reachability listeners
    window.addEventListener('online', () => this.handleNetworkChange(true));
    window.addEventListener('offline', () => this.handleNetworkChange(false));
  }

  initUI() {
    this.serverUrlInput.value = this.serverUrl;
    this.deviceNameInput.value = this.deviceName;
    this.facingSelect.value = this.facingMode;

    // Settings drawer triggers
    document.getElementById('btn-open-settings').onclick = () => this.openDrawer();
    document.getElementById('btn-close-drawer').onclick = () => this.closeDrawer();
    this.drawerBackdrop.onclick = (e) => {
      if (e.target === this.drawerBackdrop) this.closeDrawer();
    };

    // Save settings
    document.getElementById('btn-save-settings').onclick = () => {
      let newUrl = this.serverUrlInput.value.trim();
      if (newUrl.endsWith('/')) newUrl = newUrl.slice(0, -1);
      this.serverUrl = newUrl;
      this.deviceName = this.deviceNameInput.value.trim() || 'Tablet Kiosk';
      this.facingMode = this.facingSelect.value;

      localStorage.setItem('gym_server_url', this.serverUrl);
      localStorage.setItem('gym_tablet_device_name', this.deviceName);
      localStorage.setItem('gym_camera_facing', this.facingMode);

      this.showToast('Settings saved. Reconnecting...');
      this.closeDrawer();
      this.connectToServer();
      this.restartCamera();
    };

    // Test Connection
    document.getElementById('btn-test-connection').onclick = async () => {
      const btn = document.getElementById('btn-test-connection');
      btn.innerText = 'Testing Reachability...';
      try {
        const start = performance.now();
        const res = await fetch(`${this.serverUrl}/api/ping`, { method: 'GET', cache: 'no-store' });
        const latency = Math.round(performance.now() - start);
        if (res.ok) {
          const json = await res.json();
          this.showToast(`Connected to PC App! Latency: ${latency}ms`);
        } else {
          this.showToast(`Server returned HTTP ${res.status}`);
        }
      } catch (err) {
        this.showToast(`Connection failed: Cannot reach ${this.serverUrl}`);
      } finally {
        btn.innerText = 'Test Ping Reachability';
      }
    };

    // Force Sync Members Now
    document.getElementById('btn-force-sync').onclick = async () => {
      await this.syncMembersFromPC(true);
    };

    // Force Flush Queue
    document.getElementById('btn-flush-queue').onclick = async () => {
      await this.flushPendingScans();
    };

    // Clear Local Database
    document.getElementById('btn-clear-db').onclick = async () => {
      if (confirm('Clear local offline members & queued attendance?')) {
        await this.db.clearPendingScans();
        indexedDB.deleteDatabase(this.db.dbName);
        this.showToast('Local database cleared. Re-syncing...');
        window.location.reload();
      }
    };

    // Flip Camera button on HUD
    document.getElementById('btn-flip-camera').onclick = () => {
      this.facingMode = (this.facingMode === 'user') ? 'environment' : 'user';
      localStorage.setItem('gym_camera_facing', this.facingMode);
      this.facingSelect.value = this.facingMode;
      this.showToast(`Switched to ${this.facingMode === 'user' ? 'Front' : 'Back'} Camera`);
      this.restartCamera();
    };

    // Fullscreen button
    document.getElementById('btn-fullscreen').onclick = () => {
      if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().catch(() => {});
      } else {
        document.exitFullscreen().catch(() => {});
      }
    };

    // Sound toggle
    const soundBtn = document.getElementById('btn-toggle-sound');
    soundBtn.onclick = () => {
      this.audio.enabled = !this.audio.enabled;
      soundBtn.style.opacity = this.audio.enabled ? '1' : '0.5';
      this.showToast(`Kiosk sound: ${this.audio.enabled ? 'Enabled' : 'Muted'}`);
    };
  }

  openDrawer() {
    this.drawerBackdrop.classList.add('active');
  }

  closeDrawer() {
    this.drawerBackdrop.classList.remove('active');
  }

  showToast(text) {
    const el = document.createElement('div');
    el.className = 'toast';
    el.innerText = text;
    this.toastContainer.appendChild(el);
    setTimeout(() => el.remove(), 3500);
  }

  async updateCounters() {
    this.cachedMembersCount = await this.db.countMembers();
    this.cachedCountEl.innerText = this.cachedMembersCount;

    const pending = await this.db.getPendingScans();
    this.pendingScansCount = pending.length;
    this.queueCountEl.innerText = this.pendingScansCount;
    if (this.pendingScansCount > 0) {
      this.queuePill.style.display = 'flex';
    } else {
      this.queuePill.style.display = 'none';
    }
  }

  setOnlineStatus(online, note = '') {
    this.isOnline = online;
    if (online) {
      this.statusPill.className = 'status-pill online';
      this.statusText.innerText = note || 'Live PC Sync Active';
    } else {
      this.statusPill.className = 'status-pill offline';
      this.statusText.innerText = note || 'Offline Scanner Active';
    }
  }

  handleNetworkChange(isUp) {
    if (isUp) {
      this.showToast('Wi-Fi restored. Reconnecting to PC...');
      this.connectToServer();
    } else {
      this.setOnlineStatus(false, 'Wi-Fi Disconnected');
      this.showToast('Offline Mode Active. Scans stored locally.');
    }
  }

  // ── 4. PC Server Connection & Real-time WebSocket ────────────────────────
  async connectToServer() {
    clearTimeout(this.wsReconnectTimer);

    // 1. Check HTTP reachability
    try {
      const res = await fetch(`${this.serverUrl}/api/ping`, { method: 'GET', cache: 'no-store' });
      if (res.ok) {
        this.setOnlineStatus(true, 'Connected to PC');
        // Initial sync of member roster
        await this.syncMembersFromPC();
        // Flush any scans that accumulated while offline
        await this.flushPendingScans();
      } else {
        this.setOnlineStatus(false, 'Offline (PC Unreachable)');
      }
    } catch (_) {
      this.setOnlineStatus(false, 'Offline (Local Database Active)');
    }

    // 2. Open WebSocket for instant push events
    this.openWebSocket();
  }

  openWebSocket() {
    if (this.ws) {
      try { this.ws.close(); } catch (_) {}
      this.ws = null;
    }

    try {
      const url = new URL(this.serverUrl);
      const wsProtocol = (url.protocol === 'https:') ? 'wss:' : 'ws:';
      const wsUrl = `${wsProtocol}//${url.host}/ws`;

      console.log(`[WS] Connecting to ${wsUrl}`);
      this.ws = new WebSocket(wsUrl);

      this.ws.onopen = () => {
        console.log('[WS] WebSocket connected to PC hub');
        this.setOnlineStatus(true, 'Live Connected to PC');
        this.showToast('Live Connected to PC App');
      };

      this.ws.onmessage = async (event) => {
        try {
          const payload = JSON.parse(event.data);
          this.handleServerEvent(payload);
        } catch (e) {
          console.warn('[WS] Parse error:', e);
        }
      };

      this.ws.onclose = () => {
        console.log('[WS] Connection closed. Will retry in 4s...');
        this.setOnlineStatus(false, 'Offline Scanner Active');
        this.wsReconnectTimer = setTimeout(() => this.connectToServer(), 4000);
      };

      this.ws.onerror = () => {
        this.setOnlineStatus(false, 'Offline Scanner Active');
      };
    } catch (err) {
      console.warn('[WS] Error setting up WebSocket:', err);
      this.wsReconnectTimer = setTimeout(() => this.connectToServer(), 4000);
    }
  }

  // ── Real-time Member Sync Handlers ──────────────────────────────────────
  async handleServerEvent(event) {
    if (!event || !event.type) return;

    switch (event.type) {
      case 'member:new':
        // Once PC app adds a member, it sends it to tablet!
        if (event.data) {
          console.log('[WS] Real-time new member received:', event.data.name);
          await this.db.upsertMember(event.data);
          await this.updateCounters();
          this.showToast(`New Member Synced: ${event.data.name} (Offline Ready)`);
          this.audio.playGranted();
        }
        break;

      case 'member:updated':
        if (event.data) {
          console.log('[WS] Real-time member updated:', event.data.name);
          await this.db.upsertMember(event.data);
          await this.updateCounters();
          this.showToast(`Member Updated: ${event.data.name}`);
        }
        break;

      case 'member:deleted':
        if (event.data && (event.data.qr_token || event.data.id)) {
          console.log('[WS] Real-time member deleted:', event.data);
          await this.db.deleteMember(event.data.qr_token || event.data.id);
          await this.updateCounters();
          this.showToast('Member removed from local cache');
        }
        break;

      case 'sync:force':
        console.log('[WS] Force sync signal received');
        await this.syncMembersFromPC();
        break;

      default:
        break;
    }
  }

  async syncMembersFromPC(manual = false) {
    try {
      const res = await fetch(`${this.serverUrl}/api/members/sync`, { method: 'GET', cache: 'no-store' });
      if (res.ok) {
        const json = await res.json();
        if (json.success && Array.isArray(json.members)) {
          const count = await this.db.upsertMembers(json.members);
          await this.updateCounters();
          if (manual) {
            this.showToast(`Synced ${count} members to tablet offline storage!`);
          }
          console.log(`[Sync] Saved ${count} members into local IndexedDB.`);
        }
      }
    } catch (e) {
      if (manual) this.showToast('Sync failed: Could not reach PC App');
    }
  }

  async flushPendingScans() {
    const pending = await this.db.getPendingScans();
    if (pending.length === 0) return;

    console.log(`[Flush] Uploading ${pending.length} offline check-ins to PC...`);
    try {
      const res = await fetch(`${this.serverUrl}/api/attendance/batch`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ scans: pending })
      });

      if (res.ok) {
        const json = await res.json();
        await this.db.clearPendingScans();
        await this.updateCounters();
        this.showToast(`Synced ${json.processed || pending.length} offline check-ins to PC App!`);
      }
    } catch (err) {
      console.warn('[Flush] Failed to flush queue, will retry on next reconnect:', err);
    }
  }

  startHeartbeat() {
    clearInterval(this.heartbeatTimer);
    const sendBeat = async () => {
      try {
        let batteryLevel = null;
        if (navigator.getBattery) {
          const b = await navigator.getBattery();
          batteryLevel = Math.round(b.level * 100);
        }

        await fetch(`${this.serverUrl}/api/tablet/heartbeat`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            device_id: this.deviceId,
            device_name: this.deviceName,
            battery_level: batteryLevel,
            app_version: '2.0.0-kiosk'
          })
        });
      } catch (_) {}
    };

    sendBeat();
    this.heartbeatTimer = setInterval(sendBeat, 35000);
  }

  // ── 5. Full-Screen QR Code Scanning Camera ────────────────────────────────
  async initCamera() {
    const placeholder = document.getElementById('camera-placeholder');
    try {
      placeholder.classList.remove('hidden');

      if (!window.Html5Qrcode) {
        throw new Error('Html5Qrcode scanner library not loaded');
      }

      this.html5QrCode = new Html5Qrcode('qr-video-container');

      const config = {
        fps: 20,
        qrbox: (viewWidth, viewHeight) => {
          const minDim = Math.min(viewWidth, viewHeight);
          const size = Math.floor(minDim * 0.72);
          return { width: size, height: size };
        },
        aspectRatio: window.innerWidth / window.innerHeight,
        showTorchButtonIfSupported: true
      };

      await this.html5QrCode.start(
        { facingMode: this.facingMode },
        config,
        (decodedText) => this.onQrCodeDetected(decodedText),
        () => {} // silent ignore frame scan misses
      );

      placeholder.classList.add('hidden');
      console.log('[Camera] Scanner camera initialized successfully.');
    } catch (err) {
      console.error('[Camera] Init error:', err);
      placeholder.classList.remove('hidden');
      document.getElementById('camera-error-msg').innerText = 'Camera access error: ' + (err.message || 'Please grant camera permission.');
    }
  }

  async restartCamera() {
    try {
      if (this.html5QrCode && this.html5QrCode.isScanning) {
        await this.html5QrCode.stop();
      }
    } catch (_) {}
    await this.initCamera();
  }

  // ── 6. Attendance Interaction & Offline Handling ──────────────────────────
  captureCameraSnapshot() {
    try {
      const video = document.querySelector('#qr-video-container video');
      if (!video || !video.videoWidth) return null;
      const canvas = document.createElement('canvas');
      const targetW = 360;
      const targetH = Math.round((video.videoHeight / video.videoWidth) * targetW) || 270;
      canvas.width = targetW;
      canvas.height = targetH;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(video, 0, 0, targetW, targetH);
      return canvas.toDataURL('image/jpeg', 0.82);
    } catch (_) {
      return null;
    }
  }

  async onQrCodeDetected(qrToken) {
    if (this.isScanningPaused) return;
    if (!qrToken || !qrToken.trim()) return;

    this.isScanningPaused = true;
    const cleanToken = qrToken.trim();
    console.log('[Scan] QR token detected:', cleanToken);

    // If QR is an auto-connect setup QR code from PC
    if (cleanToken.startsWith('{') && cleanToken.includes('serverUrl')) {
      try {
        const setup = JSON.parse(cleanToken);
        if (setup.serverUrl) {
          this.serverUrl = setup.serverUrl;
          localStorage.setItem('gym_server_url', this.serverUrl);
          this.serverUrlInput.value = this.serverUrl;
          this.showToast('Auto-configured PC IP from QR code! Connecting...');
          this.connectToServer();
          setTimeout(() => { this.isScanningPaused = false; }, 2000);
          return;
        }
      } catch (_) {}
    }

    const timestamp = new Date().toISOString();

    // Check if this is a Visitor QR (or check local cached member)
    const cachedMember = await this.db.findMember(cleanToken);
    const isVisitorQr =
      cleanToken.toUpperCase().startsWith('VIS-') ||
      (cachedMember && (cachedMember.status === 'visitor' || String(cachedMember.plan || '').toLowerCase().includes('visitor')));

    // Capture live photo from camera when scanning a Visitor QR
    const visitorPhotoBase64 = isVisitorQr ? this.captureCameraSnapshot() : null;

    // 1. Attempt ONLINE Scan via PC API
    if (this.isOnline) {
      try {
        const res = await fetch(`${this.serverUrl}/api/attendance/scan`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            qr_token: cleanToken,
            scanned_at: timestamp,
            device_id: this.deviceId,
            visitor_photo_base64: visitorPhotoBase64
          })
        });

        if (res.ok) {
          const json = await res.json();
          this.displayScanResult({
            isOnline: true,
            status: json.status || 'paid',
            memberName: json.member?.name || 'Member',
            plan: json.member?.plan || 'Active Pass',
            expiryDate: json.member?.expiry_date || '',
            qrToken: cleanToken,
            visitorPhoto: visitorPhotoBase64
          });
          return;
        }
      } catch (netErr) {
        console.warn('[Scan] Online request failed, falling back to local offline DB:', netErr);
        this.setOnlineStatus(false, 'Offline Scanner Active');
      }
    }

    // 2. OFFLINE Attendance Scan (Local IndexedDB Verification)
    await this.handleOfflineScan(cleanToken, timestamp, visitorPhotoBase64);
  }

  async handleOfflineScan(cleanToken, timestamp, visitorPhotoBase64 = null) {
    const member = await this.db.findMember(cleanToken);

    if (member) {
      // Determine membership status locally
      const isVis =
        member.status === 'visitor' ||
        cleanToken.toUpperCase().startsWith('VIS-') ||
        String(member.plan || '').toLowerCase().includes('visitor');
      let status = isVis ? 'visitor' : (member.status || 'paid');
      if (!isVis && member.expiry_date) {
        const expiry = new Date(member.expiry_date);
        if (expiry < new Date()) {
          status = 'expired';
        }
      }

      // Record offline attendance to local queue
      await this.db.queuePendingScan({
        member_id: member.id,
        member_name: member.name,
        qr_token: cleanToken,
        status: status,
        visitor_photo: visitorPhotoBase64,
        scanned_at: timestamp,
        device_id: this.deviceId
      });

      await this.updateCounters();

      this.displayScanResult({
        isOnline: false,
        status: status,
        memberName: member.name,
        plan: member.plan || 'Standard Plan',
        expiryDate: member.expiry_date || '',
        qrToken: cleanToken,
        visitorPhoto: visitorPhotoBase64
      });
    } else {
      // Member not found in offline DB
      this.displayScanResult({
        isOnline: false,
        status: 'unrecognized',
        memberName: 'Unrecognized Member',
        plan: 'Not Found in Offline Roster',
        expiryDate: '',
        qrToken: cleanToken
      });
    }
  }

  displayScanResult(data) {
    const { isOnline, status, memberName, plan, expiryDate, visitorPhoto } = data;

    // Reset card classes
    this.resultCard.className = 'result-card';
    const banner = document.getElementById('result-status-banner');
    const icon = document.getElementById('result-status-icon');
    const nameEl = document.getElementById('result-member-name');
    const planEl = document.getElementById('result-member-plan');
    const expiryEl = document.getElementById('result-member-expiry');
    const offlineTag = document.getElementById('result-offline-tag');
    const visitorPhotoWrap = document.getElementById('result-visitor-photo-wrap');
    const visitorPhotoImg = document.getElementById('result-visitor-photo');

    nameEl.innerText = memberName;
    planEl.innerText = plan;
    expiryEl.innerText = expiryDate ? `Valid until: ${expiryDate}` : '';

    if (visitorPhoto && visitorPhotoWrap && visitorPhotoImg) {
      visitorPhotoImg.src = visitorPhoto;
      visitorPhotoWrap.style.display = 'block';
    } else if (visitorPhotoWrap) {
      visitorPhotoWrap.style.display = 'none';
    }

    if (!isOnline) {
      offlineTag.style.display = 'inline-flex';
    } else {
      offlineTag.style.display = 'none';
    }

    if (status === 'visitor') {
      this.resultCard.classList.add('status-paid');
      banner.innerText = 'VISITOR PASS VERIFIED';
      icon.innerHTML = `<svg width="42" height="42" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>`;
      this.audio.playGranted();
    } else if (status === 'paid') {
      this.resultCard.classList.add('status-paid');
      banner.innerText = 'ACCESS GRANTED';
      icon.innerHTML = `<svg width="42" height="42" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>`;
      this.audio.playGranted();
    } else if (status === 'due') {
      this.resultCard.classList.add('status-due');
      banner.innerText = 'PAYMENT DUE';
      icon.innerHTML = `<svg width="42" height="42" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`;
      this.audio.playWarning();
    } else if (status === 'expired') {
      this.resultCard.classList.add('status-expired');
      banner.innerText = 'MEMBERSHIP EXPIRED';
      icon.innerHTML = `<svg width="42" height="42" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>`;
      this.audio.playWarning();
    } else {
      this.resultCard.classList.add('status-expired');
      banner.innerText = 'UNRECOGNIZED PASS';
      icon.innerHTML = `<svg width="42" height="42" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>`;
      this.audio.playWarning();
    }

    // Show overlay
    this.resultOverlay.classList.add('active');

    // Animate cooldown progress bar
    this.cooldownBar.style.transition = 'none';
    this.cooldownBar.style.transform = 'scaleX(1)';
    setTimeout(() => {
      this.cooldownBar.style.transition = `transform ${this.scanCooldownMs}ms linear`;
      this.cooldownBar.style.transform = 'scaleX(0)';
    }, 20);

    // Auto dismiss after cooldown
    setTimeout(() => {
      this.resultOverlay.classList.remove('active');
      this.isScanningPaused = false;
    }, this.scanCooldownMs);
  }
}

// ── Application Entrypoint ──────────────────────────────────────────────────
window.addEventListener('DOMContentLoaded', () => {
  const app = new TabletKioskApp();
  window.gymTabletApp = app;
  app.start();
});
