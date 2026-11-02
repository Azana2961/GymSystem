import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/member_item.dart';
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
  bool _isCapturingPhoto = false;
  int _photoCountdown = 2;
  String? _activeScanStatus; // 'paid', 'visitor', 'due', 'expired'
  String? _activeScanName;
  ScanResultInfo? _activeResult;
  Timer? _cooldownTimer;

  // Status Color Palette:
  // Regular (Active): Green | Visitor: Blue | Due (Udhaar): Orange | Expired: Red | Connected: OG Yellow
  static const Color _bgDark = Color(0xFF07090C);
  static const Color _regularGreen = Color(0xFF00E676);
  static const Color _visitorBlue = Color(0xFF00B0FF);
  static const Color _dueOrange = Color(0xFFFF9100);
  static const Color _expiredRed = Color(0xFFFF1744);
  static const Color _ogYellow = Color(0xFFFFB703);

  Color _colorForStatus(String? status) {
    switch (status) {
      case 'expired':
      case 'unrecognized':
        return _expiredRed;
      case 'due':
        return _dueOrange;
      case 'visitor':
        return _visitorBlue;
      case 'paid':
      default:
        return _regularGreen;
    }
  }

  String _labelForStatus(String? status) {
    switch (status) {
      case 'expired':
        return 'MEMBERSHIP EXPIRED';
      case 'due':
        return 'UDHAAR / PAYMENT DUE';
      case 'visitor':
        return 'VISITOR PASS';
      case 'paid':
      default:
        return 'REGULAR MEMBER • ACTIVE';
    }
  }

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
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _cameraRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _triggerTokenCheckIn(String rawValue, {Uint8List? capturedImage}) async {
    if (_isProcessingScan) return;
    final clean = rawValue.trim();
    if (clean.isEmpty) return;

    final previewStatus = _sync.previewMemberStatus(clean);
    final cachedMember = _sync.findMember(clean);
    final needsPhoto =
        previewStatus == 'visitor' || previewStatus == 'due' || previewStatus == 'expired';

    setState(() {
      _isProcessingScan = true;
      _activeScanStatus = previewStatus;
      _activeScanName = cachedMember?.name ??
          (previewStatus == 'visitor' ? 'Visitor Pass' : clean);
    });

    Uint8List? verificationPhotoBytes;

    // For Due (Orange), Visitor (Blue), and Expired (Red):
    // Show status screen & wait 5 seconds with countdown before taking verification photo!
    if (needsPhoto) {
      setState(() {
        _isCapturingPhoto = true;
        _photoCountdown = 5;
      });
      for (int i = 5; i >= 1; i--) {
        if (!mounted) return;
        setState(() => _photoCountdown = i);
        await Future.delayed(const Duration(seconds: 1));
      }
      if (!mounted) return;

      // Capture live frame after 5 seconds wait
      verificationPhotoBytes = await _captureCameraFallback() ?? capturedImage;
      if (mounted) {
        setState(() => _isCapturingPhoto = false);
      }
    }

    final result = await _sync.processScan(clean, visitorPhotoBytes: verificationPhotoBytes);

    if (mounted) {
      setState(() {
        _activeScanStatus = result.status;
        _activeResult = result;
      });

      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(const Duration(milliseconds: 3000), () {
        if (mounted) {
          setState(() {
            _activeResult = null;
            _activeScanStatus = null;
            _activeScanName = null;
            _isCapturingPhoto = false;
            _isProcessingScan = false;
          });
        }
      });
    }
  }

  void _dismissResultModal() {
    _cooldownTimer?.cancel();
    setState(() {
      _activeResult = null;
      _activeScanStatus = null;
      _activeScanName = null;
      _isCapturingPhoto = false;
      _isProcessingScan = false;
    });
  }

  bool _isServerConfigQr(String raw) {
    final clean = raw.trim();
    if (clean.contains('"serverUrl"') || clean.contains('"tabletUrl"')) return true;
    if (clean.contains('/tablet') && clean.contains('http')) return true;
    return false;
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    if (_isServerConfigQr(rawValue)) {
      await _handleServerQrScanned(rawValue);
      return;
    }

    await _triggerTokenCheckIn(rawValue, capturedImage: capture.image);
  }

  void _openManualAndRosterSheet() {
    final tokenCtrl = TextEditingController();
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0F1318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final media = MediaQuery.of(ctx);
          final allMembers = _sync.cachedMembers;
          final filtered = searchQuery.isEmpty
              ? allMembers
              : allMembers.where((m) {
                  final q = searchQuery.toLowerCase();
                  return m.name.toLowerCase().contains(q) ||
                      m.qrToken.toLowerCase().contains(q) ||
                      m.id.toLowerCase().contains(q) ||
                      (m.phone?.toLowerCase().contains(q) ?? false);
                }).toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: media.viewInsets.bottom + 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: media.size.height * 0.82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Manual Check-In & Offline Roster',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${allMembers.length} synced members available offline',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Manual QR Token / Member ID Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tokenCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          onChanged: (val) => setModalState(() => searchQuery = val.trim()),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              Navigator.pop(ctx);
                              _triggerTokenCheckIn(val.trim());
                            }
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: _visitorBlue,
                              size: 20,
                            ),
                            hintText: 'Search name or enter QR token (e.g. GYM-... / VIS-...)',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final txt = tokenCtrl.text.trim();
                          if (txt.isNotEmpty) {
                            Navigator.pop(ctx);
                            _triggerTokenCheckIn(txt);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _regularGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Check In',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: Text(
                                allMembers.isEmpty
                                    ? 'No cached members yet. Connect to PC server to sync roster.'
                                    : 'No matching member in local cache. Tap "Check In" to scan raw token.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (context, index) {
                              final MemberItem m = filtered[index];
                              final isVis = m.isVisitor;
                              final Color badgeColor = isVis
                                  ? _visitorBlue
                                  : (m.isExpired
                                      ? _expiredRed
                                      : (m.isDue ? _dueOrange : _regularGreen));
                              final String badgeLabel = isVis
                                  ? 'VISITOR'
                                  : (m.isExpired
                                      ? 'EXPIRED'
                                      : (m.isDue
                                          ? (m.dueAmount > 0
                                              ? 'DUE Rs.${m.dueAmount.toInt()}'
                                              : 'DUE')
                                          : 'ACTIVE'));

                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: badgeColor.withValues(alpha: 0.15),
                                  child: Icon(
                                    isVis
                                        ? Icons.camera_alt_rounded
                                        : Icons.person_rounded,
                                    color: badgeColor,
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  m.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  '${m.qrToken} • ${m.plan ?? "Member"} • Exp: ${m.expiryDate}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: badgeColor.withValues(alpha: 0.45)),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _triggerTokenCheckIn(m.qrToken);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String? _parseServerUrl(String raw) {
    try {
      final clean = raw.trim();
      if (clean.isEmpty) return null;

      // JSON payload from dashboard: { "serverUrl": "http://<PC-LAN-IP>:5000", ... }
      if (clean.startsWith('{') && clean.endsWith('}')) {
        final decoded = jsonDecode(clean);
        if (decoded is Map) {
           if (decoded['serverUrl'] != null && decoded['serverUrl'].toString().isNotEmpty) {
            return _normalizeUrl(decoded['serverUrl'].toString());
          }
          if (decoded['tabletUrl'] != null && decoded['tabletUrl'].toString().isNotEmpty) {
            return _normalizeUrl(decoded['tabletUrl'].toString().replaceAll(RegExp(r'/tablet/?$'), ''));
          }
          if (decoded['primaryIp'] != null && decoded['primaryIp'].toString().isNotEmpty) {
            return 'http://${decoded['primaryIp']}:5000';
          }
        }
      }

      // Direct URL e.g. http://10.5.41.32:5000/tablet or http://10.5.41.32:5000
      if (clean.contains('/tablet')) {
        return _normalizeUrl(clean.replaceAll(RegExp(r'/tablet/?$'), ''));
      }

      if (clean.startsWith('http://') || clean.startsWith('https://')) {
        return _normalizeUrl(clean);
      }

      // Bare IP:port or IP
      if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$').hasMatch(clean)) {
        return clean.contains(':') ? 'http://$clean' : 'http://$clean:5000';
      }

      return _normalizeUrl(clean);
    } catch (_) {
      return null;
    }
  }

  String _normalizeUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    return u;
  }

  Future<void> _handleServerQrScanned(String raw) async {
    final parsed = _parseServerUrl(raw);
    if (parsed == null || parsed.isEmpty) return;

    setState(() {
      _isProcessingScan = true;
    });

    await _storage.setServerUrl(parsed);
    final isConnected = await _sync.connect();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isConnected ? _ogYellow : _expiredRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              Icon(
                isConnected ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: isConnected ? Colors.black : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isConnected
                      ? 'Connected to Dashboard ($parsed)!\nSynced ${_sync.cachedMembersCount} members.'
                      : 'Saved $parsed, but could not reach PC.\nEnsure both devices are on the same Wi-Fi.',
                  style: TextStyle(
                    color: isConnected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isProcessingScan = false;
      });
    }
  }

  Future<void> _openServerQrScanner(
    TextEditingController hostCtrl,
    StateSetter setModalState,
  ) async {
    try {
      await _cameraController.stop();
    } catch (_) {}

    if (!mounted) return;

    final scannedUrl = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _ServerQrScannerScreen(
          initialUrl: hostCtrl.text,
        ),
        fullscreenDialog: true,
      ),
    );

    try {
      await _cameraController.start();
    } catch (_) {}

    if (!mounted) return;

    if (scannedUrl != null && scannedUrl.isNotEmpty) {
      hostCtrl.text = scannedUrl;
      await _storage.setServerUrl(scannedUrl);
      setModalState(() {});

      final isConnected = await _sync.connect();
      if (!mounted) return;
      setModalState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isConnected ? _ogYellow : _expiredRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              Icon(
                isConnected ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: isConnected ? Colors.black : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isConnected
                      ? 'Connected to Dashboard ($scannedUrl)!\nSynced ${_sync.cachedMembersCount} members.'
                      : 'Saved $scannedUrl, but could not reach PC.\nEnsure both devices are on the same Wi-Fi.',
                  style: TextStyle(
                    color: isConnected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _openSettingsDialog() {
    final hostCtrl = TextEditingController(text: _storage.serverUrl);
    final nameCtrl = TextEditingController(text: _storage.deviceName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF0F1318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(      
        builder: (context, setModalState) {
          final viewInsets = MediaQuery.of(ctx).viewInsets;
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 22,
              right: 22,
              top: 20,
              bottom: viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Kiosk Connection & Offline Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 1. Live Connection Status Banner (Red = Disconnected, OG Yellow = Connected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _sync.isOnline
                        ? _ogYellow.withValues(alpha: 0.12)
                        : _expiredRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _sync.isOnline ? _ogYellow : _expiredRed,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_sync.isOnline ? _ogYellow : _expiredRed).withValues(alpha: 0.2),
                        ),
                        child: Icon(
                          _sync.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                          color: _sync.isOnline ? _ogYellow : _expiredRed,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sync.isOnline ? 'CONNECTED TO DASHBOARD' : 'NOT CONNECTED (OFFLINE)',
                              style: TextStyle(
                                color: _sync.isOnline ? _ogYellow : _expiredRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _sync.isOnline
                                  ? '${_sync.serverUrl} • ${_sync.cachedMembersCount} cached members'
                                  : 'Scan the dashboard QR code below to connect over Wi-Fi',
                              style: TextStyle(
                                color: _sync.isOnline ? Colors.white70 : Colors.white60,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Scan Dashboard QR to Connect Button
                ElevatedButton.icon(
                  onPressed: () => _openServerQrScanner(hostCtrl, setModalState),
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.black, size: 22),
                  label: const Text(
                    'Scan Dashboard QR Code to Connect',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ogYellow,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(50),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Kiosk Device Name',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    hintText: 'Front Desk Kiosk',
                    hintStyle: const TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final sm = ScaffoldMessenger.of(context);
                        final n = await _sync.syncMembersRoster();
                        setModalState(() {});
                        sm.showSnackBar(
                          SnackBar(
                            content: Text('Synced $n members to offline cache!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: Text('Sync Roster (${_sync.cachedMembersCount})'),
                      style: OutlinedButton.styleFrom(foregroundColor: _regularGreen),
                    ),
                    if (_sync.pendingScansCount > 0)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final sm = ScaffoldMessenger.of(context);
                          final flushed = await _sync.flushOfflineScans();
                          setModalState(() {});
                          sm.showSnackBar(
                            SnackBar(
                              content: Text(
                                flushed > 0
                                    ? 'Uploaded $flushed queued offline scans to PC!'
                                    : 'Still offline — ${_sync.pendingScansCount} scans safely queued.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                        label: Text('Upload Queued (${_sync.pendingScansCount})'),
                        style: OutlinedButton.styleFrom(foregroundColor: _dueOrange),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () async {
                    final nav = Navigator.of(ctx);
                    await _storage.setDeviceName(nameCtrl.text);
                    nav.pop();
                  },
                  icon: const Icon(Icons.check_rounded, color: Colors.black),
                  label: const Text(
                    'Done',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ogYellow,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeThemeColor = _colorForStatus(_activeScanStatus);

    return Scaffold(
      backgroundColor: _bgDark,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, screenConstraints) {
          final screenW = screenConstraints.maxWidth;
          final isCompact = screenW < 420;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Sleek Web App Background Theme (Graphite Gradient)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0F141C),
                      Color(0xFF0A0D12),
                    ],
                  ),
                ),
              ),

              // 1b. Status-Colored Frame Glow when active scan triggers (Red/Orange/Blue/Green)
              if (_activeScanStatus != null)
                IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: activeThemeColor.withValues(alpha: 0.8),
                        width: isCompact ? 6 : 8,
                      ),
                    ),
                  ),
                ),

              // 2. Main Content Column: Top HUD + Middle Scanner Window + Bottom Controls
              SafeArea(
                child: Column(
                  children: [
                    // Top HUD Status Bar (Lá Fitness Logo & Connection Badge)
                    _buildTopHudBar(isCompact),

                    // Middle Section: ONLY This Box Shows the Camera!
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, middleConstraints) {
                          final availW = middleConstraints.maxWidth;
                          final availH = middleConstraints.maxHeight;
                          final isShortLandscape = availH < 320 && availW > availH;

                          final double scannerBoxSize = isShortLandscape
                              ? (availH * 0.72).clamp(160.0, 260.0)
                              : math.min(availW * 0.78, availH * 0.65).clamp(190.0, 320.0);

                          final scannerCard = Container(
                            width: scannerBoxSize,
                            height: scannerBoxSize,
                            decoration: BoxDecoration(
                              color: const Color(0xFF141922),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: activeThemeColor.withValues(alpha: 0.85),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: activeThemeColor.withValues(alpha: 0.22),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(21),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Live Camera Feed strictly confined to this window
                                  RepaintBoundary(
                                    key: _cameraRepaintKey,
                                    child: MobileScanner(
                                      controller: _cameraController,
                                      fit: BoxFit.cover,
                                      onDetect: _handleBarcode,
                                      errorBuilder: (ctx, err) => Container(
                                        color: const Color(0xFF141922),
                                        padding: const EdgeInsets.all(16.0),
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.videocam_off_rounded,
                                              color: _expiredRed,
                                              size: 38,
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Camera Inactive',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Corner reticle guides
                                  CustomPaint(
                                    size: Size(scannerBoxSize, scannerBoxSize),
                                    painter: _ReticlePainter(color: activeThemeColor),
                                  ),

                                  // Photo verification 5-second countdown overlay
                                  if (_isCapturingPhoto)
                                    Container(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 58,
                                            height: 58,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.black.withValues(alpha: 0.7),
                                              border: Border.all(color: activeThemeColor, width: 3),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: activeThemeColor.withValues(alpha: 0.4),
                                                  blurRadius: 14,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '$_photoCountdown',
                                              style: TextStyle(
                                                color: activeThemeColor,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 28,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: activeThemeColor,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _labelForStatus(_activeScanStatus),
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 10.5,
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          if (_activeScanName != null) ...[
                                            Text(
                                              _activeScanName!,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                          ],
                                          Text(
                                            'HOLD STILL • PHOTO IN ${_photoCountdown}s',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: activeThemeColor,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'Taking verification photo...',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    AnimatedBuilder(
                                      animation: _laserController,
                                      builder: (context, child) {
                                        final minTop = scannerBoxSize * 0.06;
                                        final maxTravel = scannerBoxSize * 0.86;
                                        return Positioned(
                                          top: minTop + (_laserController.value * maxTravel),
                                          left: scannerBoxSize * 0.04,
                                          right: scannerBoxSize * 0.04,
                                          child: Container(
                                            height: 3,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  activeThemeColor,
                                                  Colors.white,
                                                  activeThemeColor,
                                                  Colors.transparent,
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: activeThemeColor.withValues(alpha: 0.8),
                                                  blurRadius: 10,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );

                          final promptWidget = Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 14 : 20,
                              vertical: isCompact ? 7 : 9,
                            ),
                            decoration: BoxDecoration(
                              color: _isCapturingPhoto
                                  ? activeThemeColor.withValues(alpha: 0.9)
                                  : const Color(0xFF141922),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: _isCapturingPhoto
                                    ? Colors.white
                                    : activeThemeColor.withValues(alpha: 0.45),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isCapturingPhoto
                                      ? Icons.camera_front_rounded
                                      : Icons.qr_code_scanner_rounded,
                                  color: _isCapturingPhoto ? Colors.black : activeThemeColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _isCapturingPhoto
                                        ? 'LOOK AT CAMERA — PHOTO IN ${_photoCountdown}s...'
                                        : 'Align Member / Visitor Pass QR in Frame',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _isCapturingPhoto ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: isCompact ? 12 : 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (isShortLandscape) {
                            return Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  scannerCard,
                                  const SizedBox(width: 20),
                                  Flexible(child: promptWidget),
                                ],
                              ),
                            );
                          }

                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                promptWidget,
                                SizedBox(height: (availH * 0.04).clamp(10.0, 22.0)),
                                scannerCard,
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Bottom Adaptive Controls
                    _buildBottomControls(isCompact),
                  ],
                ),
              ),

              // 3. Adaptive Scan Result Card Modal (Green / Blue / Orange / Red)
              if (_activeResult != null) _buildResultModal(_activeResult!),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopHudBar(bool isCompact) {
    final pendingCount = _sync.pendingScansCount;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 18,
        vertical: isCompact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF10151E),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Brand Logo & Title: Lá Fitness
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isCompact ? 36 : 42,
                  height: isCompact ? 36 : 42,
                  decoration: BoxDecoration(
                    color: _ogYellow.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _ogYellow, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _ogYellow.withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: _ogYellow,
                    size: isCompact ? 19 : 22,
                  ),
                ),
                SizedBox(width: isCompact ? 10 : 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LÁ FITNESS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: isCompact ? 15 : 18,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'ATTENDANCE KIOSK',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ogYellow.withValues(alpha: 0.9),
                          fontSize: isCompact ? 9 : 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status Badges & Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Online / Offline Status Pill (Red = Disconnected, OG Yellow = Connected)
              GestureDetector(
                onTap: () => _sync.connect(),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 8 : 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141922),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _sync.isOnline
                          ? _ogYellow.withValues(alpha: 0.75)
                          : _expiredRed.withValues(alpha: 0.75),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sync.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        color: _sync.isOnline ? _ogYellow : _expiredRed,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _sync.isOnline ? _ogYellow : _expiredRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _sync.isOnline ? 'Connected' : 'Not Connected',
                        style: TextStyle(
                          color: _sync.isOnline ? _ogYellow : _expiredRed,
                          fontSize: isCompact ? 11 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: isCompact ? 6 : 8),

              // Cached Members Count (Tap to view offline roster)
              GestureDetector(
                onTap: _openManualAndRosterSheet,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 8 : 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141922),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_alt_rounded, color: _visitorBlue, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        '${_sync.cachedMembersCount}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 11 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Pending Offline Queue Badge
              if (pendingCount > 0) ...[
                SizedBox(width: isCompact ? 6 : 8),
                GestureDetector(
                  onTap: () => _sync.flushOfflineScans(),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _dueOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _dueOrange.withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_upload_rounded,
                          color: _dueOrange,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$pendingCount',
                          style: TextStyle(
                            color: _dueOrange,
                            fontSize: isCompact ? 11 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              SizedBox(width: isCompact ? 6 : 8),

              // Settings Icon (Red = Disconnected, OG Yellow = Connected)
              IconButton(
                onPressed: _openSettingsDialog,
                visualDensity: isCompact ? VisualDensity.compact : VisualDensity.standard,
                icon: Icon(
                  Icons.settings_rounded,
                  color: _sync.isOnline ? _ogYellow : _expiredRed,
                  size: isCompact ? 20 : 22,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF141922),
                  side: BorderSide(
                    color: (_sync.isOnline ? _ogYellow : _expiredRed).withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(bool isCompact) {
    final btnPadding = EdgeInsets.symmetric(
      horizontal: isCompact ? 13 : 16,
      vertical: isCompact ? 9 : 11,
    );
    final labelStyle = TextStyle(fontSize: isCompact ? 12 : 13, fontWeight: FontWeight.w600);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, 8, 12, isCompact ? 12 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: isCompact ? 8 : 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _cameraController.switchCamera(),
            icon: const Icon(Icons.cameraswitch_rounded, size: 17),
            label: Text('Flip Camera', style: labelStyle),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black.withValues(alpha: 0.65),
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: btnPadding,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _cameraController.toggleTorch(),
            icon: const Icon(Icons.flash_on_rounded, size: 17),
            label: Text('Flashlight', style: labelStyle),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black.withValues(alpha: 0.65),
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: btnPadding,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _openManualAndRosterSheet,
            icon: const Icon(Icons.fact_check_rounded, size: 17, color: _visitorBlue),
            label: Text('Manual / Roster', style: labelStyle),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black.withValues(alpha: 0.65),
              side: BorderSide(color: _visitorBlue.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: btnPadding,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultModal(ScanResultInfo res) {
    // Status Colors:
    // Regular -> Green | Visitor -> Blue | Due -> Orange | Expired -> Red
    Color themeColor = _regularGreen;
    String bannerText = 'REGULAR MEMBER • ACCESS GRANTED';
    IconData icon = Icons.check_circle_rounded;

    if (res.isVisitor) {
      themeColor = _visitorBlue;
      bannerText = 'VISITOR PASS • PHOTO CAPTURED';
      icon = Icons.camera_alt_rounded;
    } else if (res.isDue) {
      themeColor = _dueOrange;
      bannerText = res.dueAmount > 0
          ? 'UDHAAR DUE (Rs. ${res.dueAmount.toInt()}) • PHOTO CAPTURED'
          : 'PAYMENT DUE • PHOTO CAPTURED';
      icon = Icons.warning_amber_rounded;
    } else if (res.isExpired) {
      themeColor = _expiredRed;
      bannerText = 'MEMBERSHIP EXPIRED • PHOTO CAPTURED';
      icon = Icons.cancel_rounded;
    } else if (!res.isRecognized) {
      themeColor = _expiredRed;
      bannerText = 'UNRECOGNIZED PASS';
      icon = Icons.help_outline_rounded;
    }

    return GestureDetector(
      onTap: _dismissResultModal,
      child: Container(
        decoration: BoxDecoration(
          color: themeColor.withValues(alpha: 0.28),
          border: Border.all(color: themeColor, width: 10),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardMaxW = math.min(constraints.maxWidth * 0.92, 410.0);
            final isSmall = constraints.maxHeight < 420 || constraints.maxWidth < 360;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardMaxW),
                child: Container(
                  padding: EdgeInsets.all(isSmall ? 18 : 26),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E131A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: themeColor,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.45),
                        blurRadius: 45,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (res.visitorPhotoBytes != null) ...[
                        Container(
                          width: isSmall ? 82 : 104,
                          height: isSmall ? 82 : 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: themeColor, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: themeColor.withValues(alpha: 0.4),
                                blurRadius: 16,
                              ),
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
                        Icon(icon, color: themeColor, size: isSmall ? 52 : 66),
                      SizedBox(height: isSmall ? 10 : 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: themeColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          bannerText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: themeColor,
                            fontWeight: FontWeight.w900,
                            fontSize: isSmall ? 11 : 12.5,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      SizedBox(height: isSmall ? 10 : 14),
                      if (!res.isOnline)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _dueOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Offline Check-in Queued (${_sync.pendingScansCount} pending)',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _dueOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        res.memberName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmall ? 20 : 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${res.plan}${res.expiryDate.isNotEmpty ? " • Valid: ${res.expiryDate}" : ""}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      if (res.dueAmount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: _dueOrange.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _dueOrange.withValues(alpha: 0.45)),
                          ),
                          child: Text(
                            'Pending Udhaar: Rs. ${res.dueAmount.toInt()}',
                            style: const TextStyle(
                              color: _dueOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: isSmall ? 14 : 20),
                      LinearProgressIndicator(
                        backgroundColor: Colors.white10,
                        color: themeColor,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cornerLength = (size.width * 0.12).clamp(18.0, 36.0);

    // Top Left
    canvas.drawLine(const Offset(0, 0), Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, cornerLength), paint);

    // Top Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom Left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom Right
    canvas.drawLine(
        Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(
        Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) => oldDelegate.color != color;
}

/// Dedicated Scanner Screen to auto-pair with the Dashboard Tablet Kiosk QR Code
class _ServerQrScannerScreen extends StatefulWidget {
  final String initialUrl;
  const _ServerQrScannerScreen({required this.initialUrl});

  @override
  State<_ServerQrScannerScreen> createState() => _ServerQrScannerScreenState();
}

class _ServerQrScannerScreenState extends State<_ServerQrScannerScreen> {
  late final MobileScannerController _controller;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isNotEmpty) {
        final parsed = _parseUrl(raw);
        if (parsed != null && parsed.isNotEmpty) {
          _scanned = true;
          Navigator.pop(context, parsed);
          break;
        }
      }
    }
  }

  String? _parseUrl(String raw) {
    try {
      final clean = raw.trim();
      if (clean.isEmpty) return null;
      if (clean.startsWith('{') && clean.endsWith('}')) {
        final decoded = jsonDecode(clean);
        if (decoded is Map) {
          if (decoded['serverUrl'] != null && decoded['serverUrl'].toString().isNotEmpty) {
            return _normalize(decoded['serverUrl'].toString());
          }
          if (decoded['tabletUrl'] != null && decoded['tabletUrl'].toString().isNotEmpty) {
            return _normalize(decoded['tabletUrl'].toString().replaceAll(RegExp(r'/tablet/?$'), ''));
          }
          if (decoded['primaryIp'] != null && decoded['primaryIp'].toString().isNotEmpty) {
            return 'http://${decoded['primaryIp']}:5000';
          }
        }
      }
      if (clean.contains('/tablet')) {
        return _normalize(clean.replaceAll(RegExp(r'/tablet/?$'), ''));
      }
      if (clean.startsWith('http://') || clean.startsWith('https://')) {
        return _normalize(clean);
      }
      if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$').hasMatch(clean)) {
        return clean.contains(':') ? 'http://$clean' : 'http://$clean:5000';
      }
      return _normalize(clean);
    } catch (_) {
      return null;
    }
  }

  String _normalize(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    return u;
  }

  @override
  Widget build(BuildContext context) {
    const ogYellow = Color(0xFFFFB703);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: _onDetect,
          ),
          // Center Reticle Viewport
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: ogYellow, width: 3),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: ogYellow.withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    color: ogYellow.withValues(alpha: 0.35),
                    size: 80,
                  ),
                ],
              ),
            ),
          ),
          // Top Navigation Bar
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ogYellow.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_rounded, color: ogYellow, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Scan Dashboard QR',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.flip_camera_android_rounded, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.6),
                          ),
                          onPressed: () => _controller.switchCamera(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.6),
                          ),
                          onPressed: () => _controller.toggleTorch(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom Explanation Box
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Point camera at the Tablet Kiosk QR code on PC Dashboard',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Both devices must be connected to the SAME Wi-Fi or hotspot',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
