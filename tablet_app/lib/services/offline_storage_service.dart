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

  SharedPreferences? _prefs;
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
    final prefs = _prefs;
    if (prefs == null) return;
    // 1. Members Cache
    final membersJson = prefs.getString(_keyMembers);
    if (membersJson != null && membersJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(membersJson) as List<dynamic>;
        _membersCache.clear();
        for (final item in decoded) {
          final m = MemberItem.fromJson(item as Map<String, dynamic>);
          _indexMember(m);
        }
      } catch (_) {
        // Silent error recovery
      }
    }

    // 2. Pending Offline Scans
    final pendingJson = prefs.getString(_keyPendingScans);
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

  void _indexMember(MemberItem m) {
    final token = m.qrToken.trim();
    final id = m.id.trim();
    if (token.isNotEmpty) {
      _membersCache[token] = m;
      _membersCache[token.toUpperCase()] = m;
    }
    if (id.isNotEmpty) {
      _membersCache[id] = m;
      _membersCache[id.toUpperCase()] = m;
    }
  }

  // ── Member Offline Cache ──────────────────────────────────────────────────

  List<MemberItem> get allMembers {
    final byId = <String, MemberItem>{};
    for (final m in _membersCache.values) {
      byId[m.id] = m;
    }
    final list = byId.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  int get cachedMembersCount => allMembers.length;

  MemberItem? findMember(String tokenOrId) {
    final clean = tokenOrId.trim();
    if (clean.isEmpty) return null;
    final direct = _membersCache[clean] ?? _membersCache[clean.toUpperCase()];
    if (direct != null) return direct;

    final lower = clean.toLowerCase();
    for (final m in _membersCache.values) {
      if (m.qrToken.toLowerCase() == lower || m.id.toLowerCase() == lower) {
        return m;
      }
    }
    return null;
  }

  Future<void> saveMember(MemberItem member) async {
    _indexMember(member);
    await _persistMembers();
  }

  Future<void> saveMembersBatch(List<MemberItem> list) async {
    _membersCache.clear();
    for (final m in list) {
      _indexMember(m);
    }
    await _persistMembers();
  }

  Future<void> removeMember(String tokenOrId) async {
    final m = findMember(tokenOrId);
    if (m != null) {
      _membersCache.remove(m.qrToken);
      _membersCache.remove(m.qrToken.toUpperCase());
      _membersCache.remove(m.id);
      _membersCache.remove(m.id.toUpperCase());
      await _persistMembers();
    }
  }

  Future<void> _persistMembers() async {
    final uniqueMembers = allMembers;
    final jsonStr = jsonEncode(uniqueMembers.map((m) => m.toJson()).toList());
    await _prefs?.setString(_keyMembers, jsonStr);
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
    await _prefs?.remove(_keyPendingScans);
  }

  Future<void> _persistPendingScans() async {
    final jsonStr = jsonEncode(_pendingScans.map((s) => s.toJson()).toList());
    await _prefs?.setString(_keyPendingScans, jsonStr);
  }

  // ── Server & Device Configuration ────────────────────────────────────────

  String get serverUrl => _prefs?.getString(_keyServerUrl) ?? 'http://10.0.2.2:5000';

  Future<void> setServerUrl(String url) async {
    var clean = url.trim();
    if (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
    if (clean.isNotEmpty && !clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    await _prefs?.setString(_keyServerUrl, clean);
  }

  String get deviceId {
    var id = _prefs?.getString(_keyDeviceId);
    if (id == null) {
      id = 'tablet-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _prefs?.setString(_keyDeviceId, id);
    }
    return id;
  }

  String get deviceName => _prefs?.getString(_keyDeviceName) ?? 'Lá Fitness Kiosk';

  Future<void> setDeviceName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      await _prefs?.setString(_keyDeviceName, trimmed);
    }
  }
}
