# Titan Gym Local Backend Hub & WhatsApp Anti-Ban Automation

A high-performance Node.js & Express server with SQLite persistence, QR pass generation, real-time WebSocket live feed, **Tablet IP network discovery**, and an **Intelligent Anti-Ban WhatsApp Message Engine** with randomized delays and fatigue cooldown breaks.

---

## Key Features

### 1. Tablet IP Connectivity & Diagnostics
- **Local Wi-Fi / LAN Binding:** Listens on `0.0.0.0:5000` with permissive CORS so tablets can connect effortlessly.
- **Network Info & Auto-Connect QR (`GET /api/network/info`):** Automatically detects your machine's primary LAN IP (e.g. `http://192.168.1.50:5000` or `http://10.5.125.80:5000`) and generates an auto-configuration QR code for the tablet kiosk.
- **Instant Ping Probe (`GET /api/ping`):** Ultra-fast reachability check for the tablet "Test Connection" button.
- **Offline-First Member Sync (`GET /api/members/sync`):** Full member roster for tablet local SQLite caching (`gym_kiosk.db`), enabling offline attendance check-ins.
- **Batch Attendance Sync (`POST /api/attendance/batch`):** Syncs scans accumulated while the tablet was offline.
- **Tablet Heartbeat & Device Tracking (`POST /api/tablet/heartbeat`):** Reports tablet battery level, app version, and last seen status.

---

### 2. WhatsApp Anti-Ban Message Automation Engine
To completely prevent phone number bans from Meta/WhatsApp:
1. **Human Timing Mimicry (Random Delays):**
   - Every message waits a dynamically randomized interval (e.g. **5s to 14s + micro-jitter**).
   - Never sends at uniform or fixed intervals.
2. **Fatigue Simulation (Batch Cooldown Breaks):**
   - After every **5 messages** (configurable), the queue pauses for a **30s–60s rest break**, emulating natural human texting fatigue.
3. **Zero Concurrency (FIFO Queue):**
   - Strictly 1 message processed at a time through a persistent SQLite queue (`whatsapp_queue`).
4. **Spintax & Hash Variation:**
   - Evaluates spintax patterns like `{Salam|Hello|Hi} {name}! {Your plan is due|Membership expiring}` to ensure no two messages share identical content or cryptographic hashes.
5. **Daily Safety Ceiling:**
   - Auto-pauses if the daily limit (default: 150 messages) is reached.
6. **Multi-Mode Dispatch:**
   - **High-Fidelity Safe Simulation:** Tests exact random delays, countdown timers, logs, and UI without burning numbers.
   - **HTTP Gateway / Webhook / Cloud API:** Dispatches via Baileys, UltraMsg, Twilio, or local WhatsApp gateways.
7. **Automated Event Triggers:**
   - Welcome WhatsApp notification upon member registration.
   - Expiry and Due payment reminders with 1-click trigger (`POST /api/whatsapp/send-expiry-alerts`).
   - Payment / renewal receipt generation.

---

## Getting Started

### 1. Run the Backend Server
```powershell
cd D:\GYMSYSTEM\backend
npm start
```

For live auto-reloading during development:
```powershell
npm run dev
```

### 2. View the Live Web Console
Open your browser to:
```
http://localhost:5000
```
Features available in the console:
- **Tablet IP Banner:** Copy Host IP or click **"📷 View Tablet Setup QR"** to scan with the tablet camera.
- **WhatsApp Anti-Ban Center:** Real-time countdown timer showing random delays in action, pause/resume controls, and anti-ban settings sliders.
- **Live Attendance Feed:** Instant check-in updates over WebSockets.
- **Member Passes:** Scannable QR cards with **"⚡ Test Scan"** button to simulate tablet scans in 1 click.

---

## Tablet Setup Instructions

1. Connect both your laptop and tablet to the **same Wi-Fi** or mobile hotspot network.
2. Check your laptop's IP displayed on startup (or in the web console banner), e.g.:
   ```
   http://10.5.125.80:5000
   ```
3. On the tablet kiosk app:
   - Tap **Admin** (top-right, default PIN: `0000` or `1234`).
   - In **Settings**, enter the Server Host IP / Base URL: `http://<YOUR_IP>:5000`
   - *(Or scan the setup QR code displayed in the web console)*.
   - Tap **"Test Connection (Ping)"** — you will get an instant green confirmation!
   - Tap **"Sync Members Now"** to cache the member database offline.
4. You are ready to scan check-ins!

---

## API Reference

### Tablet & Connectivity Endpoints
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/ping` | Fast ping probe for tablet connection test |
| `GET` | `/api/health` | Server health check probe |
| `GET` | `/api/network/info` | Hostname, primary IP, full LAN URLs, and tablet auto-connect QR |
| `GET` | `/api/tablet/config` | Tablet configuration (gym name, sync interval, scan cooldown) |
| `POST` | `/api/tablet/heartbeat` | Tablet reports battery, IP, version, and device name |
| `GET` | `/api/tablet/devices` | List registered/connected tablet devices |
| `GET` | `/api/members/sync` | Full roster of members for tablet offline SQLite caching |
| `POST` | `/api/attendance/scan` | Scans member QR token and logs real-time attendance |
| `POST` | `/api/attendance/batch` | Offline sync: uploads queued check-ins from tablet |

### WhatsApp Anti-Ban Endpoints
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/whatsapp/status` | Current queue status, active random delay, and sent counters |
| `GET` | `/api/whatsapp/settings` | Anti-ban settings (min/max delays, batch cooldown, daily cap) |
| `POST` | `/api/whatsapp/settings` | Updates anti-ban parameters |
| `GET` | `/api/whatsapp/queue` | List pending and active messages in SQLite queue |
| `GET` | `/api/whatsapp/logs` | Historical audit logs with delay used and delivery status |
| `POST` | `/api/whatsapp/send` | Enqueue single message with random anti-ban delay |
| `POST` | `/api/whatsapp/send-test` | Enqueue verified test message with live countdown timer |
| `POST` | `/api/whatsapp/send-expiry-alerts` | Enqueues personalized reminders for due/expired members |
| `POST` | `/api/whatsapp/broadcast` | Broadcast announcement with Spintax to target members |
| `POST` | `/api/whatsapp/pause` | Pause queue processing |
| `POST` | `/api/whatsapp/resume` | Resume queue processing |
| `POST` | `/api/whatsapp/clear` | Clear all pending messages from queue |

### Real WhatsApp Web Client Endpoints
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/whatsapp/real/status` | Live connection status, connected phone number, and auth state |
| `GET` | `/api/whatsapp/real/qr` | Latest pairing QR code Data URL & raw string |
| `POST` | `/api/whatsapp/real/start` | Trigger/reconnect Real WhatsApp socket |
| `POST` | `/api/whatsapp/real/logout` | Disconnect and clear saved credentials |
| `POST` | `/api/whatsapp/real/pairing-code` | Request 8-digit mobile pairing code |
| `POST` | `/api/whatsapp/send-real` | Send real WhatsApp message (immediate or queued with anti-ban) |

---

## Real WhatsApp Quick Pairing Guide

1. Start the server (`npm start`).
2. Open the Web Console at `http://localhost:5000` (or in Flutter desktop app Settings).
3. In the **"Real WhatsApp Engine"** banner, click **"📷 View Pairing QR"** (or scan the terminal ASCII QR).
4. On your mobile phone:
   - Open **WhatsApp**
   - Tap **Settings** (or three dots) → **Linked Devices**
   - Tap **Link a Device**
   - Scan the QR code shown on screen
5. Once scanned, the status instantly turns green:
   `Real WhatsApp Connected: +92 300 1234567 • ONLINE & READY`
6. All automated expiry reminders, welcome notes, and receipts are now sent **directly to real WhatsApp numbers** while remaining completely protected by random delays and batch cooldown breaks!

### Core Member & Stats Endpoints
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/members` | List all members |
| `GET` | `/api/members/:id` | Get member details by ID |
| `POST` | `/api/members/register` | Registers new member, generates QR pass, and queues welcome WhatsApp |
| `PUT` | `/api/members/:id` | Update member |
| `DELETE` | `/api/members/:id` | Delete member |
| `GET` | `/api/attendance/feed` | Recent check-ins list |
| `GET` | `/api/stats` | Dashboard KPIs (check-ins, active, dues, WhatsApp sent) |
| `GET` | `/qrcodes/:token.png` | Download member QR code PNG |
| `WS` | `/ws` | WebSocket for real-time live events |
| `GET` | `/api/attendance/stream` | Server-Sent Events stream for attendance |
