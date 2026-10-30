import 'package:flutter/material.dart';
import 'package:gym_system/core/constants/app_settings.dart';
import 'package:gym_system/core/constants/dummy_data.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';
import 'package:gym_system/core/widgets/receipt_qr_dialog.dart';

class CollectPaymentDialog extends StatefulWidget {
  final MemberModel? initialMember;

  const CollectPaymentDialog({super.key, this.initialMember});

  @override
  State<CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends State<CollectPaymentDialog> {
  final _settings = AppSettings.instance;
  final _searchController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _udhaarController = TextEditingController(text: '0');

  MemberModel? _selectedMember;
  String _selectedMethod = 'Cash';
  bool _includePlanRenewal = true;
  bool _includeExtraFee = false;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedMethod = _settings.paymentMethods.first;

    final membersList = MembersProvider.instance.allMembers.isNotEmpty
        ? MembersProvider.instance.allMembers
        : DummyData.members;

    if (widget.initialMember != null) {
      _selectedMember = widget.initialMember;
    } else {
      // Default to first member with pending payment, udhaar, or due status
      final dueMembers = membersList
          .where((m) => m.isPaymentPending || m.dueAmount > 0 || m.expiryDate.isBefore(DateTime.now()))
          .toList();
      if (dueMembers.isNotEmpty) {
        _selectedMember = dueMembers.first;
      } else if (membersList.isNotEmpty) {
        _selectedMember = membersList.first;
      }
    }

    _configureForMember(_selectedMember);
  }

  void _configureForMember(MemberModel? m) {
    if (m == null) return;
    // If member has existing Udhaar and their plan isn't expired yet, default to collecting their Udhaar first
    if (m.dueAmount > 0 && !m.isExpired) {
      _includePlanRenewal = false;
      _includeExtraFee = false;
    } else {
      _includePlanRenewal = true;
      _includeExtraFee = _settings.enableJoiningFee && m.isExpired;
    }
    _udhaarController.text = '0';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    _udhaarController.dispose();
    super.dispose();
  }

  double get _existingUdhaar => _selectedMember?.dueAmount ?? 0.0;

  double get _planPrice {
    if (_selectedMember == null) return 8000.0;
    return _settings.getPlanPrice(_selectedMember!.plan);
  }

  double get _activePlanCharge => _includePlanRenewal ? _planPrice : 0.0;

  double get _extraFee => (_settings.enableJoiningFee && _includeExtraFee) ? _settings.joiningFeeAmount : 0.0;

  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0.0;

  double get _finalPrice => (_existingUdhaar + _activePlanCharge + _extraFee - _discount).clamp(0.0, double.infinity);

  double get _remainingUdhaar =>
      (double.tryParse(_udhaarController.text.trim().replaceAll(',', '')) ?? 0.0).clamp(0.0, _finalPrice);

  double get _paidNowAmount => (_finalPrice - _remainingUdhaar).clamp(0.0, _finalPrice);

  List<MemberModel> get _filteredMembers {
    final membersList = MembersProvider.instance.allMembers.isNotEmpty
        ? MembersProvider.instance.allMembers
        : DummyData.members;

    if (_searchQuery.trim().isEmpty) {
      return membersList.take(6).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    return membersList.where((m) {
      final matchesId = m.id.toLowerCase().contains(q);
      final matchesName = m.name.toLowerCase().contains(q);
      final matchesPhone = m.phone?.toLowerCase().contains(q) ?? false;
      final matchesPlan = m.plan.toLowerCase().contains(q);
      final matchesNotes = m.notes?.toLowerCase().contains(q) ?? false;
      return matchesId || matchesName || matchesPhone || matchesPlan || matchesNotes;
    }).take(8).toList();
  }

  void _onSelectMember(MemberModel member) {
    setState(() {
      _selectedMember = member;
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
      _configureForMember(member);
    });
  }

  void _submitPayment() {
    if (_selectedMember == null) return;

    final member = _selectedMember!;
    final formattedPaid = AppSettings.formatAmount(_paidNowAmount);
    final formattedUdhaar = AppSettings.formatAmount(_remainingUdhaar);
    final hasDue = _remainingUdhaar > 0;

    // Update member status and expiry in session data & SQLite database
    final planDays = _settings.getPlanDurationDays(member.plan);
    final now = DateTime.now();
    final DateTime newExpiry = _includePlanRenewal
        ? (member.expiryDate.isBefore(now)
            ? now.add(Duration(days: planDays))
            : member.expiryDate.add(Duration(days: planDays)))
        : member.expiryDate;

    final updated = member.copyWith(
      isPaymentPending: hasDue,
      dueAmount: _remainingUdhaar,
      paidAmount: member.paidAmount + _paidNowAmount,
      isActive: !hasDue && !newExpiry.isBefore(now),
      expiryDate: newExpiry,
      notes: hasDue
          ? 'Paid Rs. $formattedPaid via $_selectedMethod • Remaining Udhaar: Rs. $formattedUdhaar'
          : 'Fee Rs. $formattedPaid collected via $_selectedMethod on ${now.toString().split(' ')[0]}',
    );

    // Persist to SQLite & update shared state (ReceiptQrDialog will send the full Pass Card image)
    MembersProvider.instance.updateMember(
      updated,
      sendReceipt: false,
      paidAmount: _paidNowAmount,
      paymentMethod: _selectedMethod,
    );

    final idx = DummyData.members.indexWhere((m) => m.id == member.id);
    if (idx != -1) {
      DummyData.members[idx] = updated;
    }

    final nav = Navigator.of(context);
    nav.pop();

    showDialog(
      context: nav.context,
      builder: (ctx) => ReceiptQrDialog(
        member: updated,
        planFee: _activePlanCharge,
        admissionFee: _extraFee,
        discount: _discount,
        totalPaid: _paidNowAmount,
        paymentMethod: _selectedMethod,
        isNewRegistration: false,
        isPaymentCollection: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(26.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.payment_rounded, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Collect Payment',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24, color: AppColors.border),

                // Member Search Bar
                const Text(
                  'Search Member (by ID, Name, Phone, or Plan)',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _isSearching = true;
                    });
                  },
                  onTap: () {
                    setState(() => _isSearching = true);
                  },
                  decoration: InputDecoration(
                    hintText: 'e.g. M002, Ayesha Khan, 0321, or Silver Plan...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _isSearching = false;
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                  ),
                ),

                // Search Results Dropdown List
                if (_isSearching) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 210),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filteredMembers.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final m = _filteredMembers[index];
                        final isDue = m.isPaymentPending || m.expiryDate.isBefore(DateTime.now());
                        return InkWell(
                          onTap: () => _onSelectMember(m),
                          hoverColor: AppColors.surfaceLight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                  child: Text(
                                    m.name.isNotEmpty ? m.name[0] : 'M',
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            m.name,
                                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceLight,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              m.id,
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${m.plan} • ${m.phone ?? 'No phone'}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isDue)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                                    ),
                                    child: const Text('Due', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Selected Member Card
                if (_selectedMember != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                _selectedMember!.name.isNotEmpty ? _selectedMember!.name[0] : 'M',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _selectedMember!.name,
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${_selectedMember!.id})',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_selectedMember!.plan} • ${_selectedMember!.phone ?? 'No phone'}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_selectedMember!.isPaymentPending || _selectedMember!.isExpired)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Fee Due', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Active', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // PRICING SECTION (Plan Price & Final Price)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Pricing & Fee Calculation',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Previous Pending Udhaar (if any)
                      if (_existingUdhaar > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Previous Pending Udhaar (Due)',
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Rs. ${AppSettings.formatAmount(_existingUdhaar)}',
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Plan Renewal Checkbox & Price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _includePlanRenewal,
                                  activeColor: AppColors.primary,
                                  checkColor: Colors.black,
                                  onChanged: (v) => setState(() => _includePlanRenewal = v ?? true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Renew ${_selectedMember?.plan ?? 'Standard'} (+${_settings.getPlanDurationDays(_selectedMember?.plan ?? 'Basic')}d)',
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Text(
                            _includePlanRenewal
                                ? 'Rs. ${AppSettings.formatAmount(_planPrice)}'
                                : 'Rs. 0 (Udhaar Only)',
                            style: TextStyle(
                              color: _includePlanRenewal ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Late / Extra Fee Toggle (shown only when Admission Fee is enabled in Settings)
                      if (_settings.enableJoiningFee) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _includeExtraFee,
                                    activeColor: AppColors.primary,
                                    checkColor: Colors.black,
                                    onChanged: (v) => setState(() => _includeExtraFee = v ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Include Overdue / Admission Fee',
                                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Text(
                              _includeExtraFee
                                  ? '+ Rs. ${AppSettings.formatAmount(_settings.joiningFeeAmount)}'
                                  : 'Rs. 0 (Waived)',
                              style: TextStyle(
                                color: _includeExtraFee ? AppColors.textPrimary : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Discount Input
                      Row(
                        children: [
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'Discount (Rs.)',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 42,
                              child: TextField(
                                controller: _discountController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                    child: Text('Rs.', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Udhaar / Remaining Due Input
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Udhaar / Remaining Due (Rs.)',
                                  style: TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    InkWell(
                                      onTap: () => setState(() => _udhaarController.text = '0'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _remainingUdhaar == 0
                                              ? AppColors.success.withValues(alpha: 0.2)
                                              : AppColors.surface,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: _remainingUdhaar == 0 ? AppColors.success : AppColors.border,
                                          ),
                                        ),
                                        child: const Text(
                                          'Full Paid',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setState(() => _udhaarController.text = (_finalPrice / 2).round().toString()),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                                        ),
                                        child: const Text(
                                          '50% Udhaar',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 42,
                              child: TextField(
                                controller: _udhaarController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(color: AppColors.warning, fontSize: 14, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                    child: Text('Rs.', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _remainingUdhaar > 0 ? AppColors.warning : AppColors.border)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.warning)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AppColors.border),

                      // FINAL PRICE HIGHLIGHT
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: (_remainingUdhaar > 0 ? AppColors.warning : AppColors.primary).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_remainingUdhaar > 0 ? AppColors.warning : AppColors.primary).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _remainingUdhaar > 0 ? 'AMOUNT COLLECTED NOW' : 'FINAL AMOUNT TO COLLECT',
                                      style: TextStyle(
                                        color: _remainingUdhaar > 0 ? AppColors.warning : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _remainingUdhaar > 0
                                          ? 'Total Bill: Rs. ${AppSettings.formatAmount(_finalPrice)} • Remaining Udhaar: Rs. ${AppSettings.formatAmount(_remainingUdhaar)}'
                                          : 'All dues cleared on payment',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Rs. ${AppSettings.formatAmount(_paidNowAmount)}',
                                  style: TextStyle(
                                    color: _remainingUdhaar > 0 ? AppColors.warning : AppColors.primary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Payment Method Chips (from Settings)
                const Text(
                  'Payment Method',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _settings.paymentMethods.map((method) {
                    final isSelected = _selectedMethod == method;
                    return ChoiceChip(
                      avatar: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                          : null,
                      label: Text(method),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedMethod = method),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.background,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: 1,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 26),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _submitPayment,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.black, size: 18),
                      label: const Text('Confirm Payment', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
