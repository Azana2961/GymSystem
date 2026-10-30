import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member_item.dart';
import '../models/attendance_record.dart';

class OfflineStorageService {
  static const String _keyMembers = 'gym_cached_members';
  static const String _keyPendingScans = 'gym_pending_scans';
  static const String _keyServerUrl = 'gym_server_url';
  static const String _keyDeviceId = 'gym_tablet_device_id';
  static const String _keyDeviceName = 'gym_tablet_device_name';

  static final OfflineStorageService instance = OfflineStorageService._internal();
  OfflineStorageService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  final Map<String, MemberItem> _membersCache = {};
  final List<AttendanceRecord> _pendingScans = [];

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _loadFromDisk();
    _initialized = true;
  }

  void _loadFromDisk() {
    // 1. Members Cache
    final membersJson = _prefs.getString(_keyMembers);
    if (membersJson != null && membersJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(membersJson) as List<dynamic>;
        _membersCache.clear();
        for (final item in decoded) {
          final m = MemberItem.fromJson(item as Map<String, dynamic>);
          _membersCache[m.qrToken] = m;
          _membersCache[m.id] = m; // Also index by ID
        }
      } catch (e) {
        // Silent error recovery
      }
    }

    // 2. Pending Offline Scans
    final pendingJson = _prefs.getString(_keyPendingScans);
    if (pendingJson != null && pendingJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(pendingJson) as List<dynamic>;
        _pendingScans.clear();
        for (final item in decoded) {
          _pendingScans.add(AttendanceRecord.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
  }

  // ── Member Offline Cache ──────────────────────────────────────────────────

  int get cachedMembersCount => _membersCache.values.map((m) => m.id).toSet().length;

  MemberItem? findMember(String tokenOrId) {
    return _membersCache[tokenOrId];
  }

  Future<void> saveMember(MemberItem member) async {
    _membersCache[member.qrToken] = member;
    _membersCache[member.id] = member;
    await _persistMembers();
  }

  Future<void> saveMembersBatch(List<MemberItem> list) async {
    for (final m in list) {
      _membersCache[m.qrToken] = m;
      _membersCache[m.id] = m;
    }
    await _persistMembers();
  }

  Future<void> removeMember(String tokenOrId) async {
    final m = _membersCache[tokenOrId];
    if (m != null) {
      _membersCache.remove(m.qrToken);
      _membersCache.remove(m.id);
      await _persistMembers();
    }
  }

  Future<void> _persistMembers() async {
    // Unique list by ID
    final uniqueMembers = _membersCache.values.map((m) => m.id).toSet().map((id) => _membersCache[id]!).toList();
    final jsonStr = jsonEncode(uniqueMembers.map((m) => m.toJson()).toList());
    await _prefs.setString(_keyMembers, jsonStr);
  }

  // ── Pending Offline Attendance Scans ─────────────────────────────────────

  int get pendingScansCount => _pendingScans.length;

  List<AttendanceRecord> get pendingScans => List.unmodifiable(_pendingScans);

  Future<void> addPendingScan(AttendanceRecord scan) async {
    _pendingScans.add(scan);
    await _persistPendingScans();
  }

  Future<void> clearPendingScans() async {
    _pendingScans.clear();
    await _prefs.remove(_keyPendingScans);
  }

  Future<void> _persistPendingScans() async {
    final jsonStr = jsonEncode(_pendingScans.map((s) => s.toJson()).toList());
    await _prefs.setString(_keyPendingScans, jsonStr);
  }

  // ── Server & Device Configuration ────────────────────────────────────────

  String get serverUrl => _prefs.getString(_keyServerUrl) ?? 'http://10.0.2.2:5000';

  Future<void> setServerUrl(String url) async {
    var clean = url.trim();
    if (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
    await _prefs.setString(_keyServerUrl, clean);
  }

  String get deviceId {
    var id = _prefs.getString(_keyDeviceId);
    if (id == null) {
      id = 'tablet-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  String get deviceName => _prefs.getString(_keyDeviceName) ?? 'Gym Tablet Kiosk';

  Future<void> setDeviceName(String name) async {
    await _prefs.setString(_keyDeviceName, name.trim());
  }
}
