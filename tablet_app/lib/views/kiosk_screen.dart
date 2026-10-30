import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/kiosk_sync_service.dart';
import '../services/offline_storage_service.dart';

class KioskScreen extends StatefulWidget {
  const KioskScreen({super.key});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> with SingleTickerProviderStateMixin {
  final KioskSyncService _sync = KioskSyncService.instance;
  final OfflineStorageService _storage = OfflineStorageService.instance;
  final GlobalKey _cameraRepaintKey = GlobalKey();

  late MobileScannerController _cameraController;
  late AnimationController _laserController;

  bool _isProcessingScan = false;
  ScanResultInfo? _activeResult;
  Timer? _cooldownTimer;

  // Visual Palette
  static const Color _bgDark = Color(0xFF07090C);
  static const Color _primaryNeon = Color(0xFF00E676);
  static const Color _cyanNeon = Color(0xFF00E5FF);
  static const Color _warningNeon = Color(0xFFFFB300);
  static const Color _dangerNeon = Color(0xFFFF1744);

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      torchEnabled: false,
      returnImage: true,
    );

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _sync.addListener(_onSyncUpdate);
  }

  void _onSyncUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncUpdate);
    _cameraController.dispose();
    _laserController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<Uint8List?> _captureCameraFallback() async {
    try {
      final boundary = _cameraRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() => _isProcessingScan = true);

    // If this QR belongs to a Visitor Pass, capture the visitor's photo from camera
    Uint8List? visitorPhotoBytes;
    if (_sync.isVisitorToken(rawValue)) {
      visitorPhotoBytes = capture.image ?? await _captureCameraFallback();
    }

    final result = await _sync.processScan(rawValue, visitorPhotoBytes: visitorPhotoBytes);

    if (mounted) {
      setState(() => _activeResult = result);

      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(const Duration(milliseconds: 2800), () {
        if (mounted) {
          setState(() {
            _activeResult = null;
            _isProcessingScan = false;
          });
        }
      });
    }
  }

  void _openSettingsDialog() {
    final hostCtrl = TextEditingController(text: _storage.serverUrl);
    final nameCtrl = TextEditingController(text: _storage.deviceName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tablet Kiosk Settings',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('PC App Host IP / Server URL', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: hostCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  hintText: 'http://192.168.1.50:5000',
                  hintStyle: const TextStyle(color: Colors.white38),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final sm = ScaffoldMessenger.of(context);
                        await _sync.connect();
                        sm.showSnackBar(
                          SnackBar(content: Text(_sync.isOnline ? 'Connected to PC!' : 'PC unreachable')),
                        );
                      },
                      icon: const Icon(Icons.network_check_rounded, size: 16),
                      label: const Text('Test Ping'),
                      style: OutlinedButton.styleFrom(foregroundColor: _cyanNeon),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final sm = ScaffoldMessenger.of(context);
                        final n = await _sync.syncMembersRoster();
                        sm.showSnackBar(
                          SnackBar(content: Text('Downloaded $n members to offline cache!')),
                        );
                      },
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Sync Now'),
                      style: OutlinedButton.styleFrom(foregroundColor: _primaryNeon),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () async {
                  final nav = Navigator.of(ctx);
                  await _storage.setServerUrl(hostCtrl.text);
                  await _storage.setDeviceName(nameCtrl.text);
                  await _sync.connect();
                  nav.pop();
                },
                icon: const Icon(Icons.check_rounded, color: Colors.black),
                label: const Text('Save & Reconnect', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNeon,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fullscreen Camera Viewport
          RepaintBoundary(
            key: _cameraRepaintKey,
            child: MobileScanner(
              controller: _cameraController,
              onDetect: _handleBarcode,
              errorBuilder: (ctx, err) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded, color: _dangerNeon, size: 54),
                      const SizedBox(height: 14),
                      const Text('Camera Access Error', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(err.errorDetails?.message ?? 'Please check camera permissions in tablet settings', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Center Scanning Reticle Frame with Sweeping Laser
          Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                children: [
                  // 4 Corner Guides
                  CustomPaint(
                    size: const Size(300, 300),
                    painter: _ReticlePainter(color: _primaryNeon),
                  ),
                  // Sweeping Neon Laser
                  AnimatedBuilder(
                    animation: _laserController,
                    builder: (context, child) => Positioned(
                      top: 15 + (_laserController.value * 270),
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.transparent, _primaryNeon, Colors.white, _primaryNeon, Colors.transparent],
                          ),
                          boxShadow: [
                            BoxShadow(color: _primaryNeon.withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center Scan Prompt
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).size.height / 2 + 170,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: _primaryNeon, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Hold Gym Pass QR Code in Center',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Top Floating HUD Status Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Logo
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _primaryNeon.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _primaryNeon),
                          ),
                          child: const Icon(Icons.fitness_center_rounded, color: _primaryNeon, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LÁ FITNESS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                            Text('TABLET KIOSK SCANNER', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 0.5)),
                          ],
                        ),
                      ],
                    ),

                    // Status Badges & Action Buttons
                    Row(
                      children: [
                        // Online / Offline Status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _sync.isOnline ? _primaryNeon.withValues(alpha: 0.5) : _warningNeon.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _sync.isOnline ? _primaryNeon : _warningNeon,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _sync.isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: _sync.isOnline ? _primaryNeon : _warningNeon,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Cached Count
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people_alt_rounded, color: _cyanNeon, size: 14),
                              const SizedBox(width: 4),
                              Text('${_sync.cachedMembersCount}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Settings Icon
                        IconButton(
                          onPressed: _openSettingsDialog,
                          icon: const Icon(Icons.settings_rounded, color: Colors.white),
                          style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Bottom Controls (Flip Camera / Torch)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _cameraController.switchCamera(),
                  icon: const Icon(Icons.cameraswitch_rounded, size: 18),
                  label: const Text('Flip Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
                const SizedBox(width: 14),
                OutlinedButton.icon(
                  onPressed: () => _cameraController.toggleTorch(),
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: const Text('Flashlight'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // 5. Scan Result Card Modal
          if (_activeResult != null)
            _buildResultModal(_activeResult!),
        ],
      ),
    );
  }

  Widget _buildResultModal(ScanResultInfo res) {
    Color themeColor = _primaryNeon;
    String bannerText = 'ACCESS GRANTED';
    IconData icon = Icons.check_circle_rounded;

    if (res.isVisitor) {
      themeColor = _cyanNeon;
      bannerText = 'VISITOR PASS • PHOTO CAPTURED';
      icon = Icons.camera_alt_rounded;
    } else if (res.isDue) {
      themeColor = _warningNeon;
      bannerText = 'PAYMENT DUE';
      icon = Icons.warning_amber_rounded;
    } else if (res.isExpired) {
      themeColor = _dangerNeon;
      bannerText = 'MEMBERSHIP EXPIRED';
      icon = Icons.cancel_rounded;
    } else if (!res.isRecognized) {
      themeColor = _dangerNeon;
      bannerText = 'UNRECOGNIZED PASS';
      icon = Icons.help_outline_rounded;
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF131922),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: themeColor.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(color: themeColor.withValues(alpha: 0.25), blurRadius: 40, spreadRadius: 4),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (res.visitorPhotoBytes != null) ...[
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _cyanNeon, width: 2.5),
                  boxShadow: [
                    BoxShadow(color: _cyanNeon.withValues(alpha: 0.35), blurRadius: 16),
                  ],
                ),
                child: ClipOval(
                  child: Image.memory(
                    res.visitorPhotoBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ] else
              Icon(icon, color: themeColor, size: 64),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: themeColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                bannerText,
                style: TextStyle(color: themeColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 14),
            if (!res.isOnline)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _warningNeon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Offline Check-in Saved Locally', style: TextStyle(color: _warningNeon, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            Text(
              res.memberName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${res.plan} • ${res.expiryDate.isNotEmpty ? "Valid: ${res.expiryDate}" : ""}',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              backgroundColor: Colors.white10,
              color: themeColor,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Color color;
  _ReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const cornerLength = 32.0;

    // Top Left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom Left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
