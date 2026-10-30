import 'package:flutter/material.dart';
import 'package:gym_system/core/constants/app_settings.dart';
import 'package:gym_system/core/constants/dummy_data.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';
import 'package:gym_system/core/widgets/receipt_qr_dialog.dart';

class MemberFormDialog extends StatefulWidget {
  final MembersProvider provider;
  final MemberModel? memberToEdit;

  const MemberFormDialog({super.key, required this.provider, this.memberToEdit});

  @override
  State<MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<MemberFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _settings = AppSettings.instance;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _discountController;
  late TextEditingController _udhaarController;

  String _selectedPlan = 'Basic Plan';
  String? _selectedGender;
  DateTime? _startDate;
  DateTime? _expiryDate;
  bool _includeJoiningFee = true;
  bool _isVisitor = false;
  String _selectedPaymentMethod = 'Cash';

  final List<String> _genders = ['Male', 'Female', 'Other'];

  List<String> get _plans => _settings.plans.map((p) => p.name).toList();

  @override
  void initState() {
    super.initState();
    final m = widget.memberToEdit;
    _nameController = TextEditingController(text: m?.name ?? '');
    _phoneController = TextEditingController(text: m?.phone ?? '');
    _emailController = TextEditingController(text: m?.email ?? '');
    _discountController = TextEditingController(text: '0');
    _udhaarController = TextEditingController(
      text: (m != null && m.dueAmount > 0) ? m.dueAmount.toInt().toString() : '0',
    );

    _includeJoiningFee = _settings.enableJoiningFee;
    _selectedPaymentMethod = _settings.paymentMethods.first;

    if (m != null) {
      _isVisitor = m.isVisitor;
      _selectedPlan = _plans.contains(m.plan) ? m.plan : _plans.first;
      _selectedGender = m.gender;
      _startDate = m.startDate ?? DateTime.now();
      _expiryDate = m.expiryDate;
      _includeJoiningFee = false; // Existing member doesn't pay joining fee again
    } else {
      _startDate = DateTime.now();
      _selectedPlan = _plans.first;
      final days = _settings.getPlanDurationDays(_selectedPlan);
      _expiryDate = _startDate!.add(Duration(days: days));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _discountController.dispose();
    _udhaarController.dispose();
    super.dispose();
  }

  double get _planFee => _isVisitor ? 0.0 : _settings.getPlanPrice(_selectedPlan);

  double get _joiningFee =>
      (!_isVisitor && _includeJoiningFee && _settings.enableJoiningFee) ? _settings.joiningFeeAmount : 0.0;

  double get _discount => _isVisitor ? 0.0 : (double.tryParse(_discountController.text.trim()) ?? 0.0);

  double get _finalPrice => _isVisitor ? 0.0 : (_planFee + _joiningFee - _discount).clamp(0.0, double.infinity);

  double get _udhaarAmount => _isVisitor
      ? 0.0
      : (double.tryParse(_udhaarController.text.trim().replaceAll(',', '')) ?? 0.0)
          .clamp(0.0, _finalPrice);

  double get _paidNowAmount => (_finalPrice - _udhaarAmount).clamp(0.0, _finalPrice);

  String _generatePassToken(bool visitor) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final ms = DateTime.now().microsecondsSinceEpoch;
    final buf = StringBuffer(visitor ? 'VIS-' : 'GYM-');
    int seed = ms;
    for (int i = 0; i < 6; i++) {
      buf.write(chars[(seed + i * 17) % chars.length]);
      seed = (seed ~/ 7) + (i * 31);
    }
    return buf.toString();
  }

  void _onVisitorToggled(bool val) {
    setState(() {
      _isVisitor = val;
      if (_isVisitor) {
        _includeJoiningFee = false;
        _startDate ??= DateTime.now();
        _expiryDate = _startDate!.add(const Duration(days: 1));
      } else {
        _includeJoiningFee = _settings.enableJoiningFee;
        if (_startDate != null) {
          final days = _settings.getPlanDurationDays(_selectedPlan);
          _expiryDate = _startDate!.add(Duration(days: days));
        }
      }
    });
  }

  void _onPlanChanged(String? newPlan) {
    if (newPlan == null) return;
    setState(() {
      _selectedPlan = newPlan;
      if (_startDate != null) {
        final days = _settings.getPlanDurationDays(_selectedPlan);
        _expiryDate = _startDate!.add(Duration(days: days));
      }
    });
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (_expiryDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expiry date is required'), backgroundColor: AppColors.error),
        );
        return;
      }

      final formattedPaid = AppSettings.formatAmount(_paidNowAmount);
      final formattedUdhaar = AppSettings.formatAmount(_udhaarAmount);
      final generatedToken = widget.memberToEdit?.qrToken ?? _generatePassToken(_isVisitor);
      final methodUsed = _isVisitor ? 'Free Pass' : _selectedPaymentMethod;
      final hasDue = !_isVisitor && _udhaarAmount > 0;
      final member = MemberModel(
        id: widget.memberToEdit?.id ?? '${_isVisitor ? 'V' : 'M'}${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        name: _nameController.text.trim(),
        plan: _isVisitor ? 'Visitor Pass' : _selectedPlan,
        expiryDate: _expiryDate!,
        isPaymentPending: hasDue,
        dueAmount: _udhaarAmount,
        paidAmount: _paidNowAmount,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        startDate: _startDate,
        gender: _selectedGender,
        notes: _isVisitor
            ? 'Free Visitor Pass (Rs. 0)'
            : (hasDue
                ? 'Paid Rs. $formattedPaid via $methodUsed • Udhaar Due: Rs. $formattedUdhaar'
                : 'Paid Rs. $formattedPaid via $methodUsed'),
        isActive: !hasDue,
        qrToken: generatedToken,
      );

      if (widget.memberToEdit != null) {
        widget.provider.updateMember(member, paidAmount: _paidNowAmount, paymentMethod: methodUsed);
        final dummyIdx = DummyData.members.indexWhere((m) => m.id == member.id);
        if (dummyIdx != -1) {
          DummyData.members[dummyIdx] = member;
        }
      } else {
        widget.provider.addMember(member, sendWelcome: false);
        if (!DummyData.members.any((m) => m.id == member.id)) {
          DummyData.members.insert(0, member);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasDue
                ? 'Member saved with Rs. $formattedUdhaar Udhaar (Due) & synced to Kiosks!'
                : 'Member saved & synced to all Tablet Kiosks for offline scanning!',
          ),
          backgroundColor: hasDue ? AppColors.warning : AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );

      final nav = Navigator.of(context);
      nav.pop();

      // Show the Receipt & Check-in QR Pass
      showDialog(
        context: nav.context,
        builder: (ctx) => ReceiptQrDialog(
          member: member,
          planFee: _planFee,
          admissionFee: _joiningFee,
          discount: _discount,
          totalPaid: _paidNowAmount,
          paymentMethod: methodUsed,
          isNewRegistration: widget.memberToEdit == null,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _startDate : _expiryDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: AppColors.background,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          final days = _settings.getPlanDurationDays(_selectedPlan);
          _expiryDate = picked.add(Duration(days: days));
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
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
                            child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.memberToEdit == null ? 'Add New Member' : 'Edit Member',
                            style: const TextStyle(
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
                  const Divider(height: 28, color: AppColors.border),

                  // Visitor Pass Toggle Banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isVisitor
                          ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isVisitor
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.5)
                            : AppColors.border,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isVisitor
                                ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.camera_enhance_rounded,
                            color: _isVisitor ? const Color(0xFF00E5FF) : AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Visitor / Guest Pass (Free)',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'FREE',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (_isVisitor) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'AUTO PHOTO ON SCAN',
                                        style: TextStyle(
                                          color: Color(0xFF00E5FF),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Enable for visitors/walk-ins. Scanning a Visitor QR at the kiosk automatically takes their photo.',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isVisitor,
                          activeTrackColor: const Color(0xFF00E5FF),
                          activeThumbColor: Colors.black,
                          onChanged: _onVisitorToggled,
                        ),
                      ],
                    ),
                  ),

                  // Full Name & Gender
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Full Name', _nameController, hint: 'e.g. Hamza Tariq', required: true)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdownField('Gender', _selectedGender, _genders, (v) => setState(() => _selectedGender = v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Phone & Email
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Phone Number', _phoneController, hint: 'e.g. +92 300 1234567')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Email Address', _emailController, hint: 'e.g. hamza@gmail.com')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Plan Selection (Hidden when Visitor Pass is toggled on)
                  if (!_isVisitor) ...[
                    _buildDropdownField('Membership Plan', _selectedPlan, _plans, _onPlanChanged),
                    const SizedBox(height: 16),
                  ],

                  // Start Date & Expiry Date
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePicker('Start Date', _startDate, () => _selectDate(context, true)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDatePicker('Expiry Date', _expiryDate, () => _selectDate(context, false)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // PRICING & FEES SECTION
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
                              'Fees & Pricing Breakdown',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Plan Fee Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isVisitor ? 'Visitor / Guest Pass' : '$_selectedPlan Fee',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            ),
                            Text(
                              _isVisitor ? 'FREE (Rs. 0)' : 'Rs. ${AppSettings.formatAmount(_planFee)}',
                              style: TextStyle(
                                color: _isVisitor ? AppColors.success : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Joining Fee Toggle / Inclusion (Hidden for Free Visitor Pass)
                        if (!_isVisitor && _settings.enableJoiningFee) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _includeJoiningFee,
                                      activeColor: AppColors.primary,
                                      checkColor: Colors.black,
                                      onChanged: (v) => setState(() => _includeJoiningFee = v ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Include Joining / Admission Fee',
                                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              Text(
                                _includeJoiningFee
                                    ? '+ Rs. ${AppSettings.formatAmount(_settings.joiningFeeAmount)}'
                                    : 'Rs. 0 (Waived)',
                                style: TextStyle(
                                  color: _includeJoiningFee ? AppColors.textPrimary : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Discount Row (Hidden for Free Visitor Pass)
                        if (!_isVisitor) ...[
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

                          // Udhaar / Pending Due Balance Row
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Udhaar / Pending Due (Rs.)',
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
                                              color: _udhaarAmount == 0
                                                  ? AppColors.success.withValues(alpha: 0.2)
                                                  : AppColors.surface,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: _udhaarAmount == 0 ? AppColors.success : AppColors.border,
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
                                        InkWell(
                                          onTap: () => setState(() => _udhaarController.text = _finalPrice.toInt().toString()),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                                            ),
                                            child: const Text(
                                              'Full Udhaar',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error),
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
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _udhaarAmount > 0 ? AppColors.warning : AppColors.border)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.warning)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: 24, color: AppColors.border),

                        // FINAL PRICE & UDHAAR DISPLAY
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: (_isVisitor
                                    ? AppColors.success
                                    : (_udhaarAmount > 0 ? AppColors.warning : AppColors.primary))
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (_isVisitor
                                      ? AppColors.success
                                      : (_udhaarAmount > 0 ? AppColors.warning : AppColors.primary))
                                  .withValues(alpha: 0.5),
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
                                        _isVisitor
                                            ? 'VISITOR PASS FEE'
                                            : (_udhaarAmount > 0 ? 'AMOUNT PAID NOW' : 'FINAL PRICE / TOTAL PAYABLE'),
                                        style: TextStyle(
                                          color: _isVisitor
                                              ? AppColors.success
                                              : (_udhaarAmount > 0 ? AppColors.warning : AppColors.primary),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _isVisitor
                                            ? 'Complimentary Guest Entry Pass'
                                            : (_udhaarAmount > 0
                                                ? 'Total Bill: Rs. ${AppSettings.formatAmount(_finalPrice)} • Remaining Udhaar: Rs. ${AppSettings.formatAmount(_udhaarAmount)}'
                                                : 'Plan Fee + Joining Fee - Discount'),
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _isVisitor ? 'FREE' : 'Rs. ${AppSettings.formatAmount(_paidNowAmount)}',
                                    style: TextStyle(
                                      color: _isVisitor
                                          ? AppColors.success
                                          : (_udhaarAmount > 0 ? AppColors.warning : AppColors.primary),
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (!_isVisitor && _udhaarAmount > 0) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 15),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Udhaar Due: Rs. ${AppSettings.formatAmount(_udhaarAmount)} — Member will appear in DUE on attendance & in Analytics Udhaar list',
                                          style: const TextStyle(
                                            color: AppColors.warning,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // PAYMENT METHOD SECTION (from Settings - hidden when Visitor Pass is Free)
                  if (!_isVisitor) ...[
                    const Text(
                      'Payment Method',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _settings.paymentMethods.map((method) {
                        final isSelected = _selectedPaymentMethod == method;
                        return ChoiceChip(
                          avatar: isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                              : null,
                          label: Text(method),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedPaymentMethod = method),
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
                    const SizedBox(height: 28),
                  ],

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.black, size: 18),
                        label: Text(
                          widget.memberToEdit == null ? 'Save Member' : 'Update Member',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
          ),
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required field' : null : null,
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
              dropdownColor: AppColors.surface,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null
                      ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                      : 'Select Date',
                  style: TextStyle(
                    color: date != null ? AppColors.textPrimary : AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
