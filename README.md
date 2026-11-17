# 🏋️ GymSystem

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-18+-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![Express](https://img.shields.io/badge/Express-4.x-000000?logo=express&logoColor=white)](https://expressjs.com/)
[![SQLite](https://img.shields.io/badge/SQLite-3-003B57?logo=sqlite&logoColor=white)](https://www.sqlite.org/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/Azana2961/GymSystem/pulls)

A modern, full-stack Gym Management and Kiosk Attendance System designed for fitness centers, gym administrators, and member self-service check-ins. It delivers real-time attendance tracking, QR-based visitor passes, offline-first tablet kiosk support, and an intelligent WhatsApp anti-ban notification engine.

---

## 🌟 Key Features

### 🖥️ Management Dashboard (`frontend/`)
- **Real-Time KPI Dashboard:** Live stats on active members, daily visits, revenue, and renewal alerts.
- **Member Management:** Full lifecycle management including registration, plan assignment, renewals, and photo capture.
- **Attendance Hub:** 4-column live attendance tracking with real-time check-in feeds and history logs.
- **Visitor Pass Engine:** Auto-photo scan and automated WhatsApp visitor pass generator.
- **WhatsApp Anti-Ban Messaging Center:** Campaign management, batch sending controls, and spintax messaging.
- **Financial Analytics & Reports:** Revenue tracking, expiring memberships, and due payment tracking.

### ⚙️ Backend Hub & Local Server (`backend/`)
- **Fast RESTful API & Persistence:** Built on Node.js, Express, and high-performance SQLite.
- **Intelligent WhatsApp Anti-Ban Engine:**
  - **Human Timing Mimicry:** Dynamic randomized delays (5s–14s + micro-jitter).
  - **Fatigue Simulation:** Cooldown breaks after message batches to protect numbers.
  - **FIFO Queue & Spintax:** Zero-concurrency SQLite queue with dynamic template evaluation.
  - **Daily Safety Caps:** Automated pausing when safe daily thresholds are reached.
- **LAN Auto-Discovery & Diagnostics:** Auto-detects local host IP, provides ping probes (`GET /api/ping`), and generates auto-connect QR codes for tablets.
- **WebSocket Live Stream:** Real-time push updates for check-ins and device heartbeats.

### 📱 Tablet Kiosk App (`tablet_app/`)
- **Offline-First Attendance Scanner:** Fast QR code member scanning using `mobile_scanner`.
- **Local SQLite Caching:** Stores member rosters locally (`gym_kiosk.db`) to enable seamless check-ins during internet or network outages.
- **Batch Sync:** Automatically queues check-in records and pushes them in batches once the connection is restored.
- **Admin Diagnostics:** PIN-protected settings, battery reporting, and instant Wi-Fi host configuration via QR scan.

### 🌐 Web Kiosk (`tablet/`)
- Lightweight browser-based check-in interface for quick deployment on any device with a web browser.

---

## 📁 Repository Structure

```plaintext
GymSystem/
├── backend/       # Node.js & Express API, SQLite database, WebSocket server, WhatsApp engine
├── frontend/      # Flutter desktop & web administrative management dashboard
├── tablet/        # Lightweight web-based attendance kiosk client
└── tablet_app/    # Flutter mobile & tablet kiosk app with offline SQLite sync & QR scanner
```

---

## 🚀 Quick Start Guide

### Prerequisites
- [Node.js](https://nodejs.org/) (v18 or newer)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19 or newer)
- [Git](https://git-scm.com/)

---

### 1. Backend Setup
```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Start the server
npm start

# For auto-reloading during development
npm run dev
```
The server will start at `http://localhost:5000`. You can access the diagnostic web console directly in your browser.

---

### 2. Management Dashboard (`frontend/`)
```bash
# Navigate to frontend directory
cd frontend

# Install Flutter dependencies
flutter pub get

# Run on Chrome or Desktop
flutter run -d chrome
# or for Windows Desktop
flutter run -d windows
```

---

### 3. Tablet Kiosk App (`tablet_app/`)
```bash
# Navigate to tablet app directory
cd tablet_app

# Install Flutter dependencies
flutter pub get

# Run on connected tablet or emulator
flutter run
```

---

## 🤝 How to Contribute

Contributions make the open-source community a fantastic place to learn, inspire, and create. Any contributions you make are **greatly appreciated**!

1. **Fork the Repository**
2. **Create a Feature Branch**
   ```bash
   git checkout -b feature/AmazingFeature
   ```
3. **Commit your Changes**
   ```bash
   git commit -m "feat: add AmazingFeature"
   ```
4. **Push to the Branch**
   ```bash
   git push origin feature/AmazingFeature
   ```
5. **Open a Pull Request**

---

## 👥 Contributors

Thanks to everyone who has contributed to building and improving GymSystem!

- **[Azan Muhamad (Azana2961)](https://github.com/Azana2961)** — Project Maintainer & Core Developer
- **[Waris Abbas (warisabbas)](https://github.com/warisabbas)** — Contributor
- **[zaidS28](https://github.com/zaidS28)** — Contributor
- **[umerusmanprince65-eng](https://github.com/umerusmanprince65-eng)** — Contributor
- **[Abdullah Umer](https://github.com/abdullahumer7519)** — Contributor

---

## 📄 License

This project is licensed under the terms specified in the repository. See `LICENSE` for more details.
