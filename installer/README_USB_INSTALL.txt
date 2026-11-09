================================================================================
                    LÁ FITNESS - GYM MANAGEMENT & TABLET KIOSK
                           USB DISTRIBUTION PACKAGE
================================================================================

This folder is ready to be copied directly onto a USB drive for client installation.
No developer tools (Node.js, Flutter, Git, or Python) are required on the client PC!

--------------------------------------------------------------------------------
1. PACKAGE CONTENTS
--------------------------------------------------------------------------------
1. LaFitnessSetup.exe
   - Complete, self-contained Windows installer for the Gym Reception PC.
   - Automatically bundles the embedded Node.js runtime, local SQLite database,
     automated WhatsApp engine, and the modern desktop management application.
   - Creates a Desktop shortcut and Start Menu entry: "Lá Fitness Gym Management".
   - Starts everything silently in the background with a single click.

2. LaFitnessKiosk.apk
   - High-performance Android APK for the Front-Desk Tablet Kiosk.
   - Handles real-time member QR check-ins, automated visitor photo captures,
     and instant sound/visual feedback.

3. README_USB_INSTALL.txt
   - This setup and installation guide.

--------------------------------------------------------------------------------
2. STEP-BY-STEP RECEPTION PC SETUP
--------------------------------------------------------------------------------
Step 1: Copy "LaFitnessSetup.exe" to the gym reception Windows PC (or run directly from USB).
Step 2: Double-click "LaFitnessSetup.exe".
Step 3: Follow the setup wizard (default path: C:\Program Files\La Fitness Gym Management).
Step 4: Check "Create a desktop shortcut" and click "Install".
Step 5: Click "Finish" to launch "Lá Fitness Gym Management".

That's it! The background SQLite database and local server will start silently,
and the management dashboard will appear on screen.

--------------------------------------------------------------------------------
3. STEP-BY-STEP TABLET KIOSK SETUP
--------------------------------------------------------------------------------
Step 1: Copy "LaFitnessKiosk.apk" to your Android Tablet via USB cable, Google Drive,
        or local network share.
Step 2: On the tablet, open your Files / Downloads app and tap "LaFitnessKiosk.apk".
Step 3: When prompted, enable "Allow installation from unknown sources".
Step 4: Tap "Install", then open "Lá Fitness Kiosk".

--------------------------------------------------------------------------------
4. INITIAL ONE-TIME PAIRING (ZERO-CONFIGURATION)
--------------------------------------------------------------------------------
Step 1: Ensure both the Reception PC and the Android Tablet are connected to the
        same Wi-Fi router / local network.
Step 2: On the PC dashboard, click the "Tablet Kiosk" button in the top action bar.
        A popup showing the local connection QR code will appear.
Step 3: On the tablet, tap "Connect via QR". Point the tablet camera at the PC screen.
Step 4: The tablet instantly binds to the PC's local server IP.
        The "Tablet Kiosk" status indicator on the PC will turn bright yellow,
        confirming live synchronization is active!

* Note: The tablet saves the server address in its local storage. You do NOT need
  to scan the QR code every morning. As soon as the kiosk app opens, it automatically
  re-establishes the connection.

--------------------------------------------------------------------------------
5. RECOMMENDED BEST PRACTICES (ROUTER SETUP)
--------------------------------------------------------------------------------
- For 100% uninterrupted operation, assign a "Static IP" or "DHCP Reservation"
  to the reception PC in your gym's Wi-Fi router settings (e.g. 192.168.1.100).
- This ensures the PC keeps the exact same IP address even after power outages or
  router restarts, so the tablet never loses connection.
- If the gym Wi-Fi router ever changes, simply click "Tablet Kiosk" on the PC
  and scan the QR once more with the tablet to re-link to the new network.

================================================================================
                    Technical Support & Gym Software Suite
================================================================================

