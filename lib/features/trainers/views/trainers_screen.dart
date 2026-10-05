import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/core/constants/dummy_data.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/features/trainers/views/widgets/trainer_detail_panel.dart';

// ---------------------------------------------------------------------------
// Enriched local Trainer model (self-contained)
// ---------------------------------------------------------------------------
class _Trainer {
  final String id;
  final String name;
  final String specialty;
  final bool isClockedIn;
  final String avatarUrl;
  final String shiftTime;

  const _Trainer({
    required this.id,
    required this.name,
    required this.specialty,
    required this.isClockedIn,
    required this.avatarUrl,
    required this.shiftTime,
  });

  List<MemberModel> get members => DummyData.membersForTrainer(id);

  int get clientCount => members.length;
}

// ---------------------------------------------------------------------------
// Dummy Data
// ---------------------------------------------------------------------------
final List<_Trainer> _dummyTrainers = [
  const _Trainer(id: 'T001', name: 'Chris Evans',        specialty: 'Bodybuilding',      isClockedIn: true,  avatarUrl: 'https://i.pravatar.cc/150?u=1', shiftTime: '07:00 AM – 03:00 PM'),
  const _Trainer(id: 'T002', name: 'Scarlett Johansson', specialty: 'Yoga & Flexibility', isClockedIn: false, avatarUrl: 'https://i.pravatar.cc/150?u=2', shiftTime: '10:00 AM – 06:00 PM'),
  const _Trainer(id: 'T003', name: 'Dwayne Johnson',     specialty: 'Powerlifting',       isClockedIn: true,  avatarUrl: 'https://i.pravatar.cc/150?u=3', shiftTime: '06:00 AM – 02:00 PM'),
  const _Trainer(id: 'T004', name: 'Gal Gadot',          specialty: 'Cardio & HIIT',      isClockedIn: true,  avatarUrl: 'https://i.pravatar.cc/150?u=4', shiftTime: '08:00 AM – 04:00 PM'),
  const _Trainer(id: 'T005', name: 'Jason Momoa',        specialty: 'Powerlifting',       isClockedIn: false, avatarUrl: 'https://i.pravatar.cc/150?u=5', shiftTime: '12:00 PM – 08:00 PM'),
  const _Trainer(id: 'T006', name: 'Zendaya Coleman',    specialty: 'Yoga & Flexibility', isClockedIn: true,  avatarUrl: 'https://i.pravatar.cc/150?u=6', shiftTime: '09:00 AM – 05:00 PM'),
  const _Trainer(id: 'T007', name: 'Henry Cavill',       specialty: 'Bodybuilding',       isClockedIn: true,  avatarUrl: 'https://i.pravatar.cc/150?u=7', shiftTime: '07:00 AM – 03:00 PM'),
  const _Trainer(id: 'T008', name: 'Priyanka Chopra',    specialty: 'Cardio & HIIT',      isClockedIn: false, avatarUrl: 'https://i.pravatar.cc/150?u=8', shiftTime: '02:00 PM – 10:00 PM'),
];

// ---------------------------------------------------------------------------
// Main Screen
// ---------------------------------------------------------------------------
class TrainersScreen extends StatefulWidget {
  const TrainersScreen({super.key});

  @override
  State<TrainersScreen> createState() => _TrainersScreenState();
}

class _TrainersScreenState extends State<TrainersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _searchQuery  = '';
  String _statusFilter = 'All';
  bool   _isGridView   = true;
  _Trainer? _selectedTrainer;

  static const List<String> _statusOptions = ['All', 'Clocked In', 'Clocked Out'];

  List<_Trainer> get _filtered => _dummyTrainers.where((t) {
    final q = _searchQuery.toLowerCase();
    final matchesSearch = q.isEmpty || t.name.toLowerCase().contains(q);
    final matchesStatus = _statusFilter == 'All' || (_statusFilter == 'Clocked In' && t.isClockedIn) || (_statusFilter == 'Clocked Out' && !t.isClockedIn);
    return matchesSearch && matchesStatus;
  }).toList();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectTrainer(_Trainer trainer) {
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    if (wide) {
      setState(() => _selectedTrainer = trainer);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: FractionallySizedBox(
            heightFactor: 0.9,
            child: TrainerDetailPanel(
              trainerName: trainer.name,
              specialty: trainer.specialty,
              isClockedIn: trainer.isClockedIn,
              avatarUrl: trainer.avatarUrl,
              shiftTime: trainer.shiftTime,
              members: trainer.members,
              onClose: () => Navigator.pop(context),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clockedIn    = _dummyTrainers.where((t) => t.isClockedIn).length;
    final totalClients = _dummyTrainers.fold<int>(0, (s, t) => s + t.clientCount);
    final isWide = MediaQuery.sizeOf(context).width >= 1200;

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrainersHeader(onAddTrainer: () {}),
          const SizedBox(height: 24),
          _KpiRow(totalTrainers: _dummyTrainers.length, clockedIn: clockedIn, assignedClients: totalClients, classesToday: 6),
          const SizedBox(height: 20),
          _FilterBar(
            searchCtrl: _searchCtrl,
            statusFilter: _statusFilter,
            isGridView: _isGridView,
            statusOptions: _statusOptions,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onStatusChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
            onToggleView: (grid) => setState(() => _isGridView = grid),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _isGridView
                      ? _TrainerGrid(trainers: _filtered, onTrainerTap: _selectTrainer)
                      : _TrainerTable(trainers: _filtered, onTrainerTap: _selectTrainer),
                ),
                if (_selectedTrainer != null && isWide) ...[
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 400,
                    child: TrainerDetailPanel(
                      trainerName: _selectedTrainer!.name,
                      specialty: _selectedTrainer!.specialty,
                      isClockedIn: _selectedTrainer!.isClockedIn,
                      avatarUrl: _selectedTrainer!.avatarUrl,
                      shiftTime: _selectedTrainer!.shiftTime,
                      members: _selectedTrainer!.members,
                      onClose: () => setState(() => _selectedTrainer = null),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------
class _TrainersHeader extends StatelessWidget {
  final VoidCallback onAddTrainer;
  const _TrainersHeader({required this.onAddTrainer});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('Trainers', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const Spacer(),
      ElevatedButton.icon(
        onPressed: onAddTrainer,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Trainer', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// KPI Row + Card
// ---------------------------------------------------------------------------
class _KpiRow extends StatelessWidget {
  final int totalTrainers, clockedIn, assignedClients, classesToday;
  const _KpiRow({required this.totalTrainers, required this.clockedIn, required this.assignedClients, required this.classesToday});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _KpiCard(label: 'Total Trainers',    value: '$totalTrainers',    icon: Icons.person_pin_rounded,   iconColor: AppColors.primary)),
    const SizedBox(width: 16),
    Expanded(child: _KpiCard(label: 'Clocked In',        value: '$clockedIn',        icon: Icons.login_rounded,        iconColor: AppColors.success)),
    const SizedBox(width: 16),
    Expanded(child: _KpiCard(label: 'Assigned Clients',  value: '$assignedClients',  icon: Icons.group_rounded,        iconColor: const Color(0xFF64B5F6))),
    const SizedBox(width: 16),
    Expanded(child: _KpiCard(label: 'Classes Today',     value: '$classesToday',     icon: Icons.fitness_center_rounded, iconColor: AppColors.warning)),
  ]);
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color iconColor;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
        ]),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Filter Bar
// ---------------------------------------------------------------------------
class _FilterBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String statusFilter;
  final bool isGridView;
  final List<String> statusOptions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<bool> onToggleView;

  const _FilterBar({
    required this.searchCtrl, required this.statusFilter,
    required this.isGridView, required this.statusOptions,
    required this.onSearchChanged, required this.onStatusChanged,
    required this.onToggleView,
  });

  OutlineInputBorder _border({Color color = AppColors.border}) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: color));

  InputDecoration _dropDeco() => InputDecoration(
    filled: true, fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
    border: _border(), enabledBorder: _border(), focusedBorder: _border(color: AppColors.primary),
  );

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(
      flex: 3,
      child: TextField(
        controller: searchCtrl, onChanged: onSearchChanged,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by name...',
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          filled: true, fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: _border(), enabledBorder: _border(), focusedBorder: _border(color: AppColors.primary),
        ),
      ),
    ),
    const SizedBox(width: 12),
    SizedBox(
      width: 160, height: 48,
      child: DropdownButtonFormField<String>(
        value: statusFilter, dropdownColor: AppColors.surface,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: _dropDeco(),
        items: statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onStatusChanged,
      ),
    ),
    const SizedBox(width: 12),
    Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        _ViewToggleBtn(icon: Icons.grid_view_rounded,   selected: isGridView,  onTap: () => onToggleView(true),  tooltip: 'Grid View'),
        _ViewToggleBtn(icon: Icons.table_rows_rounded,  selected: !isGridView, onTap: () => onToggleView(false), tooltip: 'Table View'),
      ]),
    ),
  ]);
}

class _ViewToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;
  const _ViewToggleBtn({required this.icon, required this.selected, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 20, color: selected ? AppColors.primary : AppColors.textSecondary),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Grid View
// ---------------------------------------------------------------------------
class _TrainerGrid extends StatelessWidget {
  final List<_Trainer> trainers;
  final ValueChanged<_Trainer> onTrainerTap;
  const _TrainerGrid({required this.trainers, required this.onTrainerTap});

  @override
  Widget build(BuildContext context) {
    if (trainers.isEmpty) return const Center(child: Text('No trainers match your filters.', style: TextStyle(color: AppColors.textSecondary)));
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 360, mainAxisExtent: 220, crossAxisSpacing: 16, mainAxisSpacing: 16),
      itemCount: trainers.length,
      itemBuilder: (_, i) => _TrainerGridCard(trainer: trainers[i], onTap: () => onTrainerTap(trainers[i])),
    );
  }
}

class _TrainerGridCard extends StatefulWidget {
  final _Trainer trainer;
  final VoidCallback onTap;
  const _TrainerGridCard({required this.trainer, required this.onTap});
  @override
  State<_TrainerGridCard> createState() => _TrainerGridCardState();
}

class _TrainerGridCardState extends State<_TrainerGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trainer;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hovered ? AppColors.primary.withOpacity(0.5) : AppColors.border, width: _hovered ? 1.5 : 1.0),
          boxShadow: _hovered ? [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 20, spreadRadius: 2)] : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _AvatarWithStatus(avatarUrl: t.avatarUrl, isClockedIn: t.isClockedIn),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(t.specialty, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                  ],
                )),
                _StatusBadge(isClockedIn: t.isClockedIn),
              ]),
              const SizedBox(height: 14),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),
              Row(children: [
                _StatChip(icon: Icons.group_rounded, label: '${t.clientCount} Clients'),
                const SizedBox(width: 6),
                Expanded(child: _StatChip(icon: Icons.schedule_rounded, label: t.shiftTime)),
              ]),
              const Spacer(),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Schedule', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 4),
                _OverflowMenu(trainerName: t.name),
              ]),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _AvatarWithStatus extends StatelessWidget {
  final String avatarUrl;
  final bool isClockedIn;
  const _AvatarWithStatus({required this.avatarUrl, required this.isClockedIn});

  @override
  Widget build(BuildContext context) => Stack(children: [
    CircleAvatar(radius: 26, backgroundColor: AppColors.border, backgroundImage: NetworkImage(avatarUrl), onBackgroundImageError: (_, __) {}),
    Positioned(bottom: 0, right: 0, child: Container(
      width: 12, height: 12,
      decoration: BoxDecoration(
        color: isClockedIn ? AppColors.success : AppColors.secondary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
    )),
  ]);
}

class _StatusBadge extends StatelessWidget {
  final bool isClockedIn;
  const _StatusBadge({required this.isClockedIn});

  @override
  Widget build(BuildContext context) {
    final color = isClockedIn ? AppColors.success : AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(isClockedIn ? 'Clocked In' : 'Clocked Out',
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))),
    ],
  );
}

class _OverflowMenu extends StatelessWidget {
  final String trainerName;
  const _OverflowMenu({required this.trainerName});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
    color: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border)),
    onSelected: (_) {},
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'edit',    child: Row(children: [Icon(Icons.edit_outlined,    size: 16, color: AppColors.textSecondary), SizedBox(width: 8), Text('Edit',    style: TextStyle(color: AppColors.textPrimary, fontSize: 13))])),
      const PopupMenuItem(value: 'message', child: Row(children: [Icon(Icons.message_outlined,  size: 16, color: AppColors.textSecondary), SizedBox(width: 8), Text('Message', style: TextStyle(color: AppColors.textPrimary, fontSize: 13))])),
      const PopupMenuItem(value: 'delete',  child: Row(children: [Icon(Icons.delete_outline,    size: 16, color: AppColors.error),          SizedBox(width: 8), Text('Remove',  style: TextStyle(color: AppColors.error,       fontSize: 13))])),
    ],
  );
}

// ---------------------------------------------------------------------------
// Table View
// ---------------------------------------------------------------------------
class _TrainerTable extends StatelessWidget {
  final List<_Trainer> trainers;
  final ValueChanged<_Trainer> onTrainerTap;
  const _TrainerTable({required this.trainers, required this.onTrainerTap});

  @override
  Widget build(BuildContext context) {
    if (trainers.isEmpty) return const Center(child: Text('No trainers match your filters.', style: TextStyle(color: AppColors.textSecondary)));
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.background.withOpacity(0.6)),
            dataRowColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.hovered) ? AppColors.primary.withOpacity(0.05) : Colors.transparent),
            dividerThickness: 0.5,
            columnSpacing: 24,
            headingTextStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
            columns: const [
              DataColumn(label: Text('TRAINER')),
              DataColumn(label: Text('SPECIALTY')),
              DataColumn(label: Text('STATUS')),
              DataColumn(label: Text('CLIENTS'), numeric: true),
              DataColumn(label: Text('SHIFT')),
              DataColumn(label: Text('ACTIONS')),
            ],
            rows: trainers.map((t) => DataRow(
              onSelectChanged: (_) => onTrainerTap(t),
              cells: [
              DataCell(Row(children: [
                CircleAvatar(radius: 16, backgroundImage: NetworkImage(t.avatarUrl), backgroundColor: AppColors.border),
                const SizedBox(width: 10),
                Text(t.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ])),
              DataCell(Text(t.specialty, style: const TextStyle(color: AppColors.primary, fontSize: 13))),
              DataCell(_StatusBadge(isClockedIn: t.isClockedIn)),
              DataCell(Text('${t.clientCount}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
              DataCell(Text(t.shiftTime, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
              DataCell(Row(children: [
                IconButton(icon: const Icon(Icons.edit_outlined,  size: 16, color: AppColors.textSecondary), onPressed: () {}, tooltip: 'Edit',   padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                const SizedBox(width: 12),
                IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),          onPressed: () {}, tooltip: 'Remove', padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ])),
            ])).toList(),
          ),
        ),
      ),
    );
  }
}
