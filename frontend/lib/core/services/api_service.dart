import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:gym_system/core/constants/app_settings.dart';
import 'package:gym_system/features/members/models/member_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static ApiService get instance => _instance;

  String get baseUrl => AppSettings.instance.backendUrl;

  HttpClient _createClient() {
    return HttpClient()..connectionTimeout = const Duration(seconds: 4);
  }

  // ── 1. Members SQLite CRUD ──────────────────────────────────────────────

  /// Fetch all registered members from SQLite database
  Future<List<MemberModel>> getMembers() async {
    final client = _createClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/api/members'));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;

        if (json['members'] is List) {
          return (json['members'] as List).map((m) {
            final expiry = DateTime.tryParse(m['expiry_date'] ?? '') ??
                DateTime.now().add(const Duration(days: 30));
            final dueAmt = (m['due_amount'] is num)
                ? (m['due_amount'] as num).toDouble()
                : (double.tryParse(m['due_amount']?.toString() ?? '0') ?? 0.0);
            final paidAmt = (m['paid_amount'] is num)
                ? (m['paid_amount'] as num).toDouble()
                : (double.tryParse(m['paid_amount']?.toString() ?? '0') ?? 0.0);
            final isDue = m['status'] == 'due' || dueAmt > 0;
            final isExpired = m['status'] == 'expired' || expiry.isBefore(DateTime.now());

            return MemberModel(
              id: m['id'] ?? m['qr_token'] ?? 'M000',
              name: m['name'] ?? 'Member',
              plan: m['plan'] ?? 'Basic Plan',
              expiryDate: expiry,
              isPaymentPending: isDue,
              dueAmount: dueAmt,
              paidAmount: paidAmt,
              phone: m['phone'],
              email: m['email'],
              gender: m['gender'],
              notes: m['notes'],
              isActive: !isExpired && !isDue,
              qrToken: m['qr_token'] ?? m['id'],
            );
          }).toList();
        }
      }
    } catch (e) {
      // Return empty list on connection error so caller can fallback
    } finally {
      client.close();
    }
    return [];
  }

  /// Register a new member and generate QR pass in SQLite
  Future<Map<String, dynamic>?> registerMember(
    MemberModel member, {
    bool sendWelcome = true,
  }) async {
    final client = _createClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/members/register'));
      request.headers.contentType = ContentType.json;

      final status = member.isVisitor
          ? 'visitor'
          : ((member.isPaymentPending || member.dueAmount > 0)
              ? 'due'
              : (member.isExpired ? 'expired' : 'paid'));

      final payload = jsonEncode({
        'id': member.id,
        'qr_token': member.qrToken ?? member.id,
        'name': member.name,
        'phone': member.phone,
        'email': member.email,
        'plan': member.plan,
        'expiry_date': member.expiryDate.toIso8601String().split('T')[0],
        'status': status,
        'gender': member.gender,
        'notes': member.notes,
        'due_amount': member.dueAmount,
        'paid_amount': member.paidAmount,
        'send_welcome': sendWelcome,
      });

      request.write(payload);
      final response = await request.close();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return null;
  }

  /// Update an existing member record in SQLite
  Future<bool> updateMember(
    MemberModel member, {
    bool sendReceipt = false,
    double? paidAmount,
    String? paymentMethod,
  }) async {
    final client = _createClient();
    try {
      final request = await client.putUrl(Uri.parse('$baseUrl/api/members/${member.id}'));
      request.headers.contentType = ContentType.json;

      final status = member.isVisitor
          ? 'visitor'
          : ((member.isPaymentPending || member.dueAmount > 0)
              ? 'due'
              : (member.isExpired ? 'expired' : 'paid'));

      final payload = jsonEncode({
        'name': member.name,
        'phone': member.phone,
        'email': member.email,
        'plan': member.plan,
        'expiry_date': member.expiryDate.toIso8601String().split('T')[0],
        'status': status,
        'gender': member.gender,
        'notes': member.notes,
        'due_amount': member.dueAmount,
        'paid_amount': paidAmount?.toInt() ?? member.paidAmount.toInt(),
        'send_receipt': sendReceipt,
        'payment_method': paymentMethod,
      });

      request.write(payload);
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Delete a member from SQLite
  Future<bool> deleteMember(String id) async {
    final client = _createClient();
    try {
      final request = await client.deleteUrl(Uri.parse('$baseUrl/api/members/$id'));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  // ── 2. Live Dashboard & Attendance Stats ─────────────────────────────────

  /// Fetch dashboard KPIs directly from SQLite
  Future<Map<String, dynamic>?> getStats() async {
    final client = _createClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/api/stats'));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['stats'] as Map<String, dynamic>?;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return null;
  }

  /// Record an attendance scan in SQLite and broadcast to live feed
  Future<Map<String, dynamic>?> recordAttendanceScan(String qrToken) async {
    final client = _createClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/attendance/scan'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'qr_token': qrToken,
        'scanned_at': DateTime.now().toIso8601String(),
      }));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return null;
  }

  // ── 3. WhatsApp Anti-Ban Automation ─────────────────────────────────────

  /// Trigger automated anti-ban WhatsApp reminders for all due and expired members
  Future<int> sendWhatsAppExpiryAlerts() async {
    final client = _createClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/whatsapp/send-expiry-alerts'));
      request.headers.contentType = ContentType.json;
      request.write('{}');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['count'] as int? ?? 0;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return 0;
  }

  /// Enqueue a single verified test WhatsApp message with live delay countdown
  Future<bool> sendWhatsAppTest(String phone) async {
    final client = _createClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/whatsapp/send-test'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'phone': phone}));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Enqueue custom WhatsApp message (with optional Pass Card PNG image) into anti-ban queue
  Future<bool> sendWhatsAppMessage({
    String? memberId,
    required String phone,
    required String text,
    String type = 'custom',
    String? imageBase64,
  }) async {
    final client = _createClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/whatsapp/send'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'member_id': memberId,
        'phone': phone,
        'text': text,
        'type': type,
        'image_base64': ?imageBase64,
      }));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Fetch WhatsApp settings & custom message templates from backend
  Future<Map<String, dynamic>?> getWhatsAppSettings() async {
    final client = _createClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/api/whatsapp/settings'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['settings'] as Map<String, dynamic>?;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return null;
  }

  /// Save custom WhatsApp settings & message templates to backend
  Future<bool> updateWhatsAppSettings(Map<String, dynamic> settings) async {
    final client = _createClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/whatsapp/settings'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(settings));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Fetch anti-ban WhatsApp queue and engine status
  Future<Map<String, dynamic>?> getWhatsAppStatus() async {
    final client = _createClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/api/whatsapp/status'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return null;
  }

  /// Fetch real WhatsApp Web client status and connected user details
  Future<Map<String, dynamic>?> getRealWhatsAppStatus() async {
    final client = _createClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/api/whatsapp/real/status'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return null;
  }

  /// Fetch pairing QR code for Real WhatsApp Web
  Future<Map<String, dynamic>?> getRealWhatsAppQr() async {
    final client = _createClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/api/whatsapp/real/qr'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return null;
  }

  /// Disconnect / logout real WhatsApp session
  Future<bool> disconnectRealWhatsApp() async {
    final client = _createClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/whatsapp/real/logout'));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Directly send a real WhatsApp message to a phone number
  Future<bool> sendRealWhatsAppDirect({
    required String phone,
    required String text,
    bool immediate = false,
  }) async {
    final client = _createClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/whatsapp/send-real'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'phone': phone,
        'text': text,
        'immediate': immediate,
      }));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  // ── 4. Tablet IP Network Info ───────────────────────────────────────────

  /// Fetch local LAN IPs and tablet auto-connect details
  Future<Map<String, dynamic>?> getNetworkInfo() async {
    final client = _createClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/api/network/info'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return null;
  }

  /// Instant reachability ping probe
  Future<bool> ping() async {
    final client = _createClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/api/ping'));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Fetch registered tablet kiosk devices and their status
  Future<List<Map<String, dynamic>>> getTabletDevices() async {
    final client = _createClient();
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl/api/tablet/devices'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        if (json['devices'] is List) {
          return List<Map<String, dynamic>>.from(json['devices'] as List);
        }
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return [];
  }

  /// Signal all connected tablets to re-sync member roster
  Future<bool> triggerTabletSync() async {
    final client = _createClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/tablet/broadcast-sync'));
      request.headers.contentType = ContentType.json;
      request.write('{}');
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }
}
