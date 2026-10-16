import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';

class MemberFormDialog extends StatefulWidget {
  final MembersProvider provider;
  final MemberModel? memberToEdit;

  const MemberFormDialog({super.key, required this.provider, this.memberToEdit});

  @override
  State<MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<MemberFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _notesController;
  
  String _selectedPlan = 'Basic Plan';
  String? _selectedGender;
  DateTime? _startDate;
  DateTime? _expiryDate;
  bool _isActive = true;
  bool _isPaymentPending = false;
  
  final List<String> _plans = ['Basic Plan', 'Silver Plan', 'Gold Plan', 'Platinum Plan'];
  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    final m = widget.memberToEdit;
    _nameController = TextEditingController(text: m?.name ?? '');
    _phoneController = TextEditingController(text: m?.phone ?? '');
    _emailController = TextEditingController(text: m?.email ?? '');
    _notesController = TextEditingController(text: m?.notes ?? '');
    
    if (m != null) {
      _selectedPlan = _plans.contains(m.plan) ? m.plan : _plans.first;
      _selectedGender = m.gender;
      _startDate = m.startDate ?? DateTime.now();
      _expiryDate = m.expiryDate;
      _isActive = m.isActive;
      _isPaymentPending = m.isPaymentPending;
    } else {
      _startDate = DateTime.now();
      _expiryDate = DateTime.now().add(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (_expiryDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expiry date is required')));
        return;
      }

      final member = MemberModel(
        id: widget.memberToEdit?.id ?? 'M${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        name: _nameController.text.trim(),
        plan: _selectedPlan,
        expiryDate: _expiryDate!,
        isPaymentPending: _isPaymentPending,
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        startDate: _startDate,
        gender: _selectedGender,
        notes: _notesController.text.trim(),
        isActive: _isActive,
      );

      if (widget.memberToEdit != null) {
        widget.provider.updateMember(member);
      } else {
        widget.provider.addMember(member);
      }
      
      Navigator.of(context).pop();
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _startDate : _expiryDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
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
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.memberToEdit == null ? 'Add New Member' : 'Edit Member',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 32, color: AppColors.border),
                
                Row(
                  children: [
                    Expanded(child: _buildTextField('Full Name', _nameController, required: true)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdownField('Gender', _selectedGender, _genders, (v) => setState(() => _selectedGender = v)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(child: _buildTextField('Phone', _phoneController)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Email', _emailController)),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField('Plan', _selectedPlan, _plans, (v) => setState(() => _selectedPlan = v!)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Active Status', style: TextStyle(color: AppColors.textSecondary)),
                        value: _isActive,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _isActive = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
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
                const SizedBox(height: 16),
                
                SwitchListTile(
                  title: const Text('Payment Pending', style: TextStyle(color: AppColors.textSecondary)),
                  value: _isPaymentPending,
                  activeThumbColor: AppColors.error,
                  onChanged: (v) => setState(() => _isPaymentPending = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                
                _buildTextField('Notes', _notesController, maxLines: 3),
                const SizedBox(height: 32),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: const Text('Save Member', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          validator: required ? (v) => v == null || v.isEmpty ? 'Required field' : null : null,
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: AppColors.surface,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' : 'Select Date',
                  style: TextStyle(color: date != null ? AppColors.textPrimary : AppColors.textSecondary),
                ),
                const Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
