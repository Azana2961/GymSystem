import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/member_item.dart';
import '../models/attendance_record.dart';
import 'offline_storage_service.dart';

class ScanResultInfo {
  final bool isOnline;
  final bool isRecognized;
  final String status; // 'paid', 'due', 'expired', 'visitor', 'unrecognized'
  final String memberName;
  final String plan;
  final String expiryDate;
  final String qrToken;
  final Uint8List? visitorPhotoBytes;

  const ScanResultInfo({
    required this.isOnline,
    required this.isRecognized,
    required this.status,
    required this.memberName,
    required this.plan,
    required this.expiryDate,
    required this.qrToken,
    this.visitorPhotoBytes,
  });

  bool get isGranted => status == 'paid';
  bool get isVisitor => status == 'visitor';
  bool get isDue => status == 'due';
  bool get isExpired => status == 'expired';
}

class KioskSyncService extends ChangeNotifier {
  static final KioskSyncService instance = KioskSyncService._internal();
  KioskSyncService._internal();

  final OfflineStorageService _storage = OfflineStorageService.instance;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  int get cachedMembersCount => _storage.cachedMembersCount;
  int get pendingScansCount => _storage.pendingScansCount;
  List<MemberItem> get cachedMembers => _storage.allMembers;
  String get serverUrl => _storage.serverUrl;

  Future<void> init() async {
    await _storage.init();
    await connect();
  }

  Future<bool> connect() async {
    _reconnectTimer?.cancel();

    // 1. Check HTTP Ping Reachability (with auto-discovery for Android Emulator 10.0.2.2 & LAN IP)
    final candidates = <String>{
      serverUrl,
      'http://10.0.2.2:5000',
      'http://10.5.49.144:5000',
      'http://10.5.40.52:5000',
      'http://localhost:5000',
      'http://127.0.0.1:5000',
    };

    bool reachable = false;
    for (final candidate in candidates) {
      if (candidate.trim().isEmpty) continue;
      try {
        final pingUri = Uri.parse('$candidate/api/ping');
        final res = await http.get(pingUri).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          if (candidate != serverUrl) {
            await _storage.setServerUrl(candidate);
          }
          reachable = true;
          break;
        }
      } catch (_) {}
    }

    if (reachable) {
      _isOnline = true;
      notifyListeners();

      // Sync latest members
      await syncMembersRoster();
      // Flush any queued offline scans (including visitor photos)
      await flushOfflineScans();
      // Open WebSocket Channel for instant live member updates
      _openWebSocket();
    } else {
      _isOnline = false;
      notifyListeners();
      _scheduleReconnect();
    }

    // 3. Heartbeat & Background Queue Monitor
    _startHeartbeat();
    return _isOnline;
  }

  void _openWebSocket() {
    _wsSub?.cancel();
    try {
      _wsChannel?.sink.close();
    } catch (_) {}

    try {
      final uri = Uri.parse(serverUrl);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final port = uri.hasPort ? uri.port : 5000;
      final wsUrl = '$wsScheme://${uri.host}:$port/ws';

      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannel = channel;
      channel.ready.catchError((_) {
        _isOnline = false;
        notifyListeners();
        _scheduleReconnect();
      });

      _wsSub = channel.stream.listen(
        (data) {
          _handleWsMessage(data.toString());
        },
        onDone: () {
          _isOnline = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onError: (_) {
          _isOnline = false;
          notifyListeners();
          _scheduleReconnect();
        },
      );

      _isOnline = true;
      notifyListeners();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () => connect());
  }

  void _handleWsMessage(String text) {
    try {
      final payload = jsonDecode(text) as Map<String, dynamic>;
      final type = payload['type'] as String?;
      final data = payload['data'];

      switch (type) {
        case 'member:new':
          // Once PC app adds a member, it immediately caches on the tablet/mobile!
          if (data is Map<String, dynamic>) {
            final newMember = MemberItem.fromJson(data);
            _storage.saveMember(newMember);
            notifyListeners();
            debugPrint('[KioskSync] Real-time member synced from PC: ${newMember.name}');
          }
          break;

        case 'member:updated':
          if (data is Map<String, dynamic>) {
            final updated = MemberItem.fromJson(data);
            _storage.saveMember(updated);
            notifyListeners();
          }
          break;

        case 'member:deleted':
          if (data is Map<String, dynamic>) {
            final id = data['id']?.toString() ?? data['qr_token']?.toString();
            if (id != null) {
              _storage.removeMember(id);
              notifyListeners();
            }
          }
          break;

        case 'sync:force':
          syncMembersRoster();
          break;

        default:
          break;
      }
    } catch (_) {}
  }

  /// Download complete member roster for offline caching
  Future<int> syncMembersRoster() async {
    _isSyncing = true;
    notifyListeners();
    try {
      final res = await http
          .get(Uri.parse('$serverUrl/api/members/sync'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if (json['members'] is List) {
          final list = (json['members'] as List)
              .map((m) => MemberItem.fromJson(m as Map<String, dynamic>))
              .toList();
          await _storage.saveMembersBatch(list);
          _isOnline = true;
          _isSyncing = false;
          notifyListeners();
          return list.length;
        }
      }
    } catch (_) {}
    _isSyncing = false;
    notifyListeners();
    return 0;
  }

  /// Upload queued offline check-ins (with visitor photos) to PC
  Future<int> flushOfflineScans() async {
    final pending = _storage.pendingScans;
    if (pending.isEmpty) return 0;

    try {
      final res = await http
          .post(
            Uri.parse('$serverUrl/api/attendance/batch'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'scans': pending.map((s) => s.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final processed = pending.length;
        await _storage.clearPendingScans();
        _isOnline = true;
        notifyListeners();
        return processed;
      }
    } catch (_) {}
    return 0;
  }

  /// Check if a QR token belongs to a Visitor Pass
  bool isVisitorToken(String qrToken) {
    final clean = qrToken.trim();
    if (clean.toUpperCase().startsWith('VIS-')) return true;
    final member = _storage.findMember(clean);
    if (member != null) {
      return member.status == 'visitor' ||
          (member.plan?.toLowerCase().contains('visitor') ?? false);
    }
    return false;
  }

  /// Process an attendance scan (Online with immediate PC sync, or Offline with local verification & queuing)
  Future<ScanResultInfo> processScan(String qrToken, {Uint8List? visitorPhotoBytes}) async {
    final cleanToken = qrToken.trim();
    final timestamp = DateTime.now().toIso8601String();
    final visitorPhotoBase64 =
        visitorPhotoBytes != null ? base64Encode(visitorPhotoBytes) : null;

    // 1. Try Online Scan
    if (_isOnline) {
      try {
        final res = await http
            .post(
              Uri.parse('$serverUrl/api/attendance/scan'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'qr_token': cleanToken,
                'scanned_at': timestamp,
                'device_id': _storage.deviceId,
                'visitor_photo_base64': ?visitorPhotoBase64,
              }),
            )
            .timeout(const Duration(seconds: 3));

        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final memberData = json['member'] as Map<String, dynamic>?;
          if (memberData != null) {
            await _storage.saveMember(MemberItem(
              id: memberData['id']?.toString() ?? cleanToken,
              qrToken: cleanToken,
              name: memberData['name']?.toString() ?? 'Member',
              status: json['status']?.toString() ?? 'paid',
              expiryDate: memberData['expiry_date']?.toString() ?? '',
              plan: memberData['plan']?.toString(),
            ));
          }
          // Flush any previously queued offline scans in background
          if (_storage.pendingScansCount > 0) {
            unawaited(flushOfflineScans());
          }
          notifyListeners();
          return ScanResultInfo(
            isOnline: true,
            isRecognized: true,
            status: json['status']?.toString() ?? 'paid',
            memberName: memberData?['name']?.toString() ?? 'Member',
            plan: memberData?['plan']?.toString() ?? 'Active Pass',
            expiryDate: memberData?['expiry_date']?.toString() ?? '',
            qrToken: cleanToken,
            visitorPhotoBytes: visitorPhotoBytes,
          );
        } else if (res.statusCode == 404) {
          // Server is online and explicitly reported token not found
          final localFallback = _storage.findMember(cleanToken);
          if (localFallback == null) {
            return ScanResultInfo(
              isOnline: true,
              isRecognized: false,
              status: 'unrecognized',
              memberName: 'Unrecognized Pass',
              plan: 'QR Code Not Found in System',
              expiryDate: '',
              qrToken: cleanToken,
            );
          }
        }
      } catch (_) {
        _isOnline = false;
        notifyListeners();
        _scheduleReconnect();
      }
    } else {
      _scheduleReconnect();
    }

    // 2. Offline Fallback: Verify against local cached member roster & queue scan + photo
    final member = _storage.findMember(cleanToken);
    if (member != null) {
      final isVis = member.status == 'visitor' ||
          cleanToken.toUpperCase().startsWith('VIS-') ||
          (member.plan?.toLowerCase().contains('visitor') ?? false);
      String status = isVis ? 'visitor' : member.status;
      if (!isVis && member.isExpired) {
        status = 'expired';
      }

      // Record locally to offline queue (with visitor photo if captured)
      await _storage.addPendingScan(AttendanceRecord(
        qrToken: cleanToken,
        memberName: member.name,
        status: status,
        scannedAt: timestamp,
        deviceId: _storage.deviceId,
        visitorPhoto: visitorPhotoBase64,
      ));

      notifyListeners();

      return ScanResultInfo(
        isOnline: false,
        isRecognized: true,
        status: status,
        memberName: member.name,
        plan: member.plan ?? (isVis ? 'Visitor Pass' : 'Standard Plan'),
        expiryDate: member.expiryDate,
        qrToken: cleanToken,
        visitorPhotoBytes: visitorPhotoBytes,
      );
    } else {
      return ScanResultInfo(
        isOnline: false,
        isRecognized: false,
        status: 'unrecognized',
        memberName: 'Unrecognized Member',
        plan: 'Not Found in Offline Roster',
        expiryDate: '',
        qrToken: cleanToken,
      );
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) async {
      if (!_isOnline) {
        await connect();
        return;
      }
      try {
        final res = await http
            .post(
              Uri.parse('$serverUrl/api/tablet/heartbeat'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'device_id': _storage.deviceId,
                'device_name': _storage.deviceName,
                'battery_level': 100,
                'app_version': '2.1.0-adaptive',
              }),
            )
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          if (_storage.pendingScansCount > 0) {
            await flushOfflineScans();
          }
        } else {
          _isOnline = false;
          notifyListeners();
          _scheduleReconnect();
        }
      } catch (_) {
        _isOnline = false;
        notifyListeners();
        _scheduleReconnect();
      }
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }
}
