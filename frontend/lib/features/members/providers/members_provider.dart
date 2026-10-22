import 'package:flutter/material.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/core/constants/dummy_data.dart';
import 'package:gym_system/core/services/api_service.dart';

enum MemberSortOption { name, expiryDate, id }
enum MemberStatusFilter { all, active, inactive, expiringSoon }
enum MemberPlanFilter { all, basic, silver, gold, platinum }

class MembersProvider extends ChangeNotifier {
  static final MembersProvider _instance = MembersProvider._internal();
  factory MembersProvider() => _instance;
  static MembersProvider get instance => _instance;

  List<MemberModel> _members = [];
  
  String _searchQuery = '';
  MemberSortOption _sortOption = MemberSortOption.name;
  bool _sortAscending = true;
  
  MemberStatusFilter _statusFilter = MemberStatusFilter.all;
  MemberPlanFilter _planFilter = MemberPlanFilter.all;
  
  int _currentPage = 0;
  int _rowsPerPage = 10;
  
  bool _isLoading = true;
  
  // Undo support
  MemberModel? _lastDeletedMember;
  int? _lastDeletedIndex;

  MembersProvider._internal() {
    refresh();
  }

  /// Initialize and fetch latest members from SQLite database
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      final list = await ApiService.instance.getMembers();
      if (list.isNotEmpty) {
        _members = list;
        _syncDummyData();
        _isLoading = false;
        notifyListeners();
        return;
      }
    } catch (_) {}

    if (_members.isEmpty) {
      _members = List.from(DummyData.members);
    }
    _isLoading = false;
    notifyListeners();
  }

  void _syncDummyData() {
    DummyData.members.clear();
    DummyData.members.addAll(_members);
  }
  
  // Getters
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  MemberSortOption get sortOption => _sortOption;
  bool get sortAscending => _sortAscending;
  MemberStatusFilter get statusFilter => _statusFilter;
  MemberPlanFilter get planFilter => _planFilter;
  int get currentPage => _currentPage;
  int get rowsPerPage => _rowsPerPage;
  List<MemberModel> get allMembers => _members;

  List<MemberModel> get filteredAndSortedMembers {
    List<MemberModel> result = _members.where((m) {
      // 1. Search Filter
      final matchesSearch = _searchQuery.isEmpty || 
          m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.plan.toLowerCase().contains(_searchQuery.toLowerCase());
          
      if (!matchesSearch) return false;
      
      // 2. Status Filter
      bool isExpired = m.expiryDate.isBefore(DateTime.now());
      bool isInactive = !m.isActive || m.isPaymentPending || isExpired;
      bool isExpiringSoon = !isInactive && m.expiryDate.isAfter(DateTime.now()) && m.expiryDate.isBefore(DateTime.now().add(const Duration(days: 7)));
      
      if (_statusFilter == MemberStatusFilter.active && isInactive) return false;
      if (_statusFilter == MemberStatusFilter.inactive && !isInactive) return false;
      if (_statusFilter == MemberStatusFilter.expiringSoon && !isExpiringSoon) return false;
      
      // 3. Plan Filter
      if (_planFilter != MemberPlanFilter.all) {
        String planName = _planFilter.name.toLowerCase();
        if (!m.plan.toLowerCase().contains(planName)) return false;
      }
      
      return true;
    }).toList();
    
    // Sort
    result.sort((a, b) {
      int comparison;
      switch (_sortOption) {
        case MemberSortOption.name:
          comparison = a.name.compareTo(b.name);
          break;
        case MemberSortOption.expiryDate:
          comparison = a.expiryDate.compareTo(b.expiryDate);
          break;
        case MemberSortOption.id:
          comparison = a.id.compareTo(b.id);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
    
    return result;
  }
  
  // Paginated getter
  List<MemberModel> get paginatedMembers {
    final filtered = filteredAndSortedMembers;
    final startIndex = _currentPage * _rowsPerPage;
    if (startIndex >= filtered.length) return [];
    final endIndex = (startIndex + _rowsPerPage).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }
  
  int get totalFilteredMembers => filteredAndSortedMembers.length;
  int get totalPages => (totalFilteredMembers / _rowsPerPage).ceil();

  // Summary Card Stats
  int get totalMembersCount => _members.length;
  
  int get activeMembersCount => _members.where((m) {
    return m.isActive && !m.isPaymentPending && !m.isExpired;
  }).length;
  
  int get expiringSoonCount => _members.where((m) {
    return !m.isExpired && 
           !m.isPaymentPending && 
           m.expiryDate.isAfter(DateTime.now()) && 
           m.expiryDate.isBefore(DateTime.now().add(const Duration(days: 7)));
  }).length;
  
  int get inactiveMembersCount => _members.where((m) {
    return !m.isActive || m.isPaymentPending || m.isExpired;
  }).length;

  int get pendingPaymentCount => _members.where((m) {
    return m.isPaymentPending || m.isExpired;
  }).length;

  // Setters & Actions
  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 0;
    notifyListeners();
  }
  
  void setSortOption(MemberSortOption option) {
    if (_sortOption == option) {
      _sortAscending = !_sortAscending;
    } else {
      _sortOption = option;
      _sortAscending = true;
    }
    _currentPage = 0;
    notifyListeners();
  }
  
  void setStatusFilter(MemberStatusFilter filter) {
    _statusFilter = filter;
    _currentPage = 0;
    notifyListeners();
  }
  
  void setPlanFilter(MemberPlanFilter filter) {
    _planFilter = filter;
    _currentPage = 0;
    notifyListeners();
  }
  
  void setPage(int page) {
    if (page >= 0 && page < totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }
  
  void setRowsPerPage(int rows) {
    _rowsPerPage = rows;
    _currentPage = 0;
    notifyListeners();
  }
  
  // ── SQLite CRUD Operations ──────────────────────────────────────────────

  /// Add member to UI and persist to SQLite database
  Future<void> addMember(MemberModel member, {bool sendWelcome = true}) async {
    _members.insert(0, member);
    _syncDummyData();
    notifyListeners();

    try {
      final res = await ApiService.instance.registerMember(member, sendWelcome: sendWelcome);
      if (res != null && res['member'] != null) {
        final serverMember = res['member'];
        final idx = _members.indexWhere((m) => m.id == member.id);
        if (idx != -1) {
          _members[idx] = _members[idx].copyWith(
            id: serverMember['id'] ?? member.id,
            qrToken: serverMember['qr_token'],
          );
          _syncDummyData();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Update member in UI and persist to SQLite database
  Future<void> updateMember(
    MemberModel member, {
    bool sendReceipt = false,
    double? paidAmount,
    String? paymentMethod,
  }) async {
    final index = _members.indexWhere((m) => m.id == member.id);
    if (index != -1) {
      _members[index] = member;
      _syncDummyData();
      notifyListeners();
    }

    try {
      await ApiService.instance.updateMember(
        member,
        sendReceipt: sendReceipt,
        paidAmount: paidAmount,
        paymentMethod: paymentMethod,
      );
    } catch (_) {}
  }
  
  /// Delete member from UI and SQLite database
  Future<void> deleteMember(String id) async {
    final index = _members.indexWhere((m) => m.id == id);
    if (index != -1) {
      _lastDeletedMember = _members[index];
      _lastDeletedIndex = index;
      _members.removeAt(index);
      _syncDummyData();
      
      if (_currentPage >= totalPages && totalPages > 0) {
        _currentPage = totalPages - 1;
      }
      notifyListeners();

      try {
        await ApiService.instance.deleteMember(id);
      } catch (_) {}
    }
  }

  void undoDelete() {
    if (_lastDeletedMember != null && _lastDeletedIndex != null) {
      if (_lastDeletedIndex! <= _members.length) {
         _members.insert(_lastDeletedIndex!, _lastDeletedMember!);
      } else {
         _members.add(_lastDeletedMember!);
      }
      _syncDummyData();
      addMember(_lastDeletedMember!, sendWelcome: false);
      _lastDeletedMember = null;
      _lastDeletedIndex = null;
      notifyListeners();
    }
  }
}
