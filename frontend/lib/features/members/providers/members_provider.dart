import 'package:flutter/material.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/core/constants/dummy_data.dart';

enum MemberSortOption { name, expiryDate, id }
enum MemberStatusFilter { all, active, inactive, expiringSoon }
enum MemberPlanFilter { all, basic, silver, gold, platinum }

class MembersProvider extends ChangeNotifier {
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

  MembersProvider() {
    _init();
  }

  Future<void> _init() async {
    // Simulate network delay for shimmer effect
    await Future.delayed(const Duration(milliseconds: 1500));
    _members = List.from(DummyData.members);
    _isLoading = false;
    notifyListeners();
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

  // Summary Getters
  int get totalMembersCount => _members.length;
  int get activeMembersCount => _members.where((m) {
    bool isExpired = m.expiryDate.isBefore(DateTime.now());
    return m.isActive && !m.isPaymentPending && !isExpired;
  }).length;
  int get inactiveMembersCount => _members.where((m) {
    bool isExpired = m.expiryDate.isBefore(DateTime.now());
    return !m.isActive || m.isPaymentPending || isExpired;
  }).length;
  int get expiringSoonCount => _members.where((m) {
    bool isExpired = m.expiryDate.isBefore(DateTime.now());
    bool isInactive = !m.isActive || m.isPaymentPending || isExpired;
    return !isInactive && m.expiryDate.isAfter(DateTime.now()) && m.expiryDate.isBefore(DateTime.now().add(const Duration(days: 7)));
  }).length;

  // Actions
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
  
  // CRUD
  void addMember(MemberModel member) {
    _members.add(member);
    notifyListeners();
  }
  
  void updateMember(MemberModel member) {
    final index = _members.indexWhere((m) => m.id == member.id);
    if (index != -1) {
      _members[index] = member;
      notifyListeners();
    }
  }
  
  void deleteMember(String id) {
    final index = _members.indexWhere((m) => m.id == id);
    if (index != -1) {
      _lastDeletedMember = _members[index];
      _lastDeletedIndex = index;
      _members.removeAt(index);
      
      // adjust current page if necessary
      if (_currentPage >= totalPages && totalPages > 0) {
        _currentPage = totalPages - 1;
      }
      notifyListeners();
    }
  }

  void undoDelete() {
    if (_lastDeletedMember != null && _lastDeletedIndex != null) {
      if (_lastDeletedIndex! <= _members.length) {
         _members.insert(_lastDeletedIndex!, _lastDeletedMember!);
      } else {
         _members.add(_lastDeletedMember!);
      }
      _lastDeletedMember = null;
      _lastDeletedIndex = null;
      notifyListeners();
    }
  }
}
