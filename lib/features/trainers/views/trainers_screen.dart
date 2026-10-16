import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/core/constants/dummy_data.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/features/trainers/models/trainer_model.dart';
import 'package:gym_system/features/trainers/views/widgets/trainer_detail_panel.dart';

// ---------------------------------------------------------------------------
// Enriched local Trainer model wrapper (for convenience in this screen)
// ---------------------------------------------------------------------------
class _TrainerWrapper {
  final TrainerModel model;

  const _TrainerWrapper(this.model);

  List<MemberModel> get members => DummyData.membersForTrainer(model.id);
  int get clientCount => members.length;
}

final List<_TrainerWrapper> _dummyTrainers = DummyData.trainers.map((t) => _TrainerWrapper(t)).toList();

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
  bool   _showTimetable = false;

  static const List<String> _statusOptions = ['All', 'Clocked In', 'Clocked Out'];

  List<_TrainerWrapper> get _filtered => _dummyTrainers.where((t) {
    final q = _searchQuery.toLowerCase();
    final matchesSearch = q.isEmpty || t.model.name.toLowerCase().contains(q);
    final matchesStatus = _statusFilter == 'All' || (_statusFilter == 'Clocked In' && t.model.isClockedIn) || (_statusFilter == 'Clocked Out' && !t.model.isClockedIn);
    return matchesSearch && matchesStatus;
  }).toList();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectTrainer(_TrainerWrapper trainer) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: TrainerDetailPanel(
          trainer: trainer.model,
          members: trainer.members,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clockedIn = _dummyTrainers.where((t) => t.model.isClockedIn).length;
    final totalClients = _dummyTrainers.fold<int>(0, (s, t) => s + t.clientCount);

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrainersHeader(onAddTrainer: () {}),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _KpiCard(label: 'Total Trainers', value: '${_dummyTrainers.length}', icon: Icons.person_pin_rounded, iconColor: AppColors.primary, onTap: null)),
              const SizedBox(width: 16),
              Expanded(child: _KpiCard(label: 'Clocked In', value: '$clockedIn', icon: Icons.login_rounded, iconColor: AppColors.success, onTap: () => setState(() => _statusFilter = 'Clocked In'))),
              const SizedBox(width: 16),
              Expanded(child: _KpiCard(label: 'Assigned Clients', value: '$totalClients', icon: Icons.group_rounded, iconColor: const Color(0xFF64B5F6), onTap: null)),
              const SizedBox(width: 16),
              Expanded(child: _KpiCard(label: 'Classes Today', value: '6', icon: Icons.fitness_center_rounded, iconColor: AppColors.warning, onTap: () => setState(() => _showTimetable = true))),
            ],
          ),
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
            child: _showTimetable 
                ? _TimetableView(onClose: () => setState(() => _showTimetable = false))
                : (_isGridView
                    ? _TrainerGrid(trainers: _filtered, onTrainerTap: _selectTrainer)
                    : _TrainerTable(trainers: _filtered, onTrainerTap: _selectTrainer)),
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
class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  
  const _KpiCard({required this.label, required this.value, required this.icon, required this.iconColor, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
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
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
          ]),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Timetable View
// ---------------------------------------------------------------------------
class _TimetableView extends StatelessWidget {
  final VoidCallback onClose;
  const _TimetableView({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text("Today's Timetable", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _ClassRow('08:00 AM', 'HIIT Blast', 'Gal Gadot', 'Studio A'),
                  _ClassRow('10:00 AM', 'Yoga Flow', 'Scarlett Johansson', 'Studio B'),
                  _ClassRow('01:00 PM', 'Powerlifting 101', 'Dwayne Johnson', 'Weights Area'),
                  _ClassRow('04:00 PM', 'Cardio Core', 'Priyanka Chopra', 'Studio A'),
                  _ClassRow('06:00 PM', 'Bodybuilding Prep', 'Chris Evans', 'Weights Area'),
                  _ClassRow('08:00 PM', 'Evening Zen Yoga', 'Zendaya Coleman', 'Studio B'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  final String time;
  final String className;
  final String trainer;
  final String location;

  const _ClassRow(this.time, this.className, this.trainer, this.location);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(time, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
      ),
      title: Text(className, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Trainer: $trainer • Location: $location'),
    );
  }
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
          color: selected ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
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
  final List<_TrainerWrapper> trainers;
  final ValueChanged<_TrainerWrapper> onTrainerTap;
  const _TrainerGrid({required this.trainers, required this.onTrainerTap});

  @override
  Widget build(BuildContext context) {
    if (trainers.isEmpty) return const Center(child: Text('No trainers match your filters.', style: TextStyle(color: AppColors.textSecondary)));
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 360, mainAxisExtent: 200, crossAxisSpacing: 16, mainAxisSpacing: 16),
      itemCount: trainers.length,
      itemBuilder: (_, i) => _TrainerGridCard(trainerWrapper: trainers[i], onTap: () => onTrainerTap(trainers[i])),
    );
  }
}

class _TrainerGridCard extends StatefulWidget {
  final _TrainerWrapper trainerWrapper;
  final VoidCallback onTap;
  const _TrainerGridCard({required this.trainerWrapper, required this.onTap});
  @override
  State<_TrainerGridCard> createState() => _TrainerGridCardState();
}

class _TrainerGridCardState extends State<_TrainerGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.trainerWrapper.model;
    
    // Calculate client capacity progress
    double capacityRatio = t.currentClients / (t.clientCapacity > 0 ? t.clientCapacity : 1);
    if (capacityRatio > 1.0) capacityRatio = 1.0;

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
            border: Border.all(color: _hovered ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border, width: _hovered ? 1.5 : 1.0),
            boxShadow: _hovered ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 20, spreadRadius: 2)] : [],
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
                      Text('${t.specialty} • ${t.phone}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  )),
                  _StatusBadge(liveStatus: t.liveStatus),
                ]),
                const SizedBox(height: 14),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 12),
                
                // Client Capacity Ratio
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Client Capacity', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text('${t.currentClients} / ${t.clientCapacity} Clients', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: capacityRatio,
                  backgroundColor: AppColors.border,
                  color: capacityRatio >= 1.0 ? AppColors.error : AppColors.success,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                
                const Spacer(),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
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
    CircleAvatar(radius: 26, backgroundColor: AppColors.border, backgroundImage: NetworkImage(avatarUrl), onBackgroundImageError: (_, _) {}),
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
  final String liveStatus;
  const _StatusBadge({required this.liveStatus});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (liveStatus.toLowerCase().contains('free')) {
      color = AppColors.success;
    } else if (liveStatus.toLowerCase().contains('session')) {
      color = AppColors.warning;
    } else {
      color = AppColors.secondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(liveStatus,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  final String trainerName;
  const _OverflowMenu({required this.trainerName});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
    color: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    onSelected: (v) {},
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'clock_in_out', child: Text('Clock In/Out Override')),
      const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
    ],
  );
}

// ---------------------------------------------------------------------------
// Table View
// ---------------------------------------------------------------------------
class _TrainerTable extends StatelessWidget {
  final List<_TrainerWrapper> trainers;
  final ValueChanged<_TrainerWrapper> onTrainerTap;
  const _TrainerTable({required this.trainers, required this.onTrainerTap});

  @override
  Widget build(BuildContext context) {
    if (trainers.isEmpty) return const Center(child: Text('No trainers match your filters.', style: TextStyle(color: AppColors.textSecondary)));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            headingTextStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            dataRowMaxHeight: 64,
            dataRowMinHeight: 64,
            columns: const [
              DataColumn(label: Text('Trainer')),
              DataColumn(label: Text('Clients')),
              DataColumn(label: Text('Shift')),
              DataColumn(label: Text('Live Status')),
              DataColumn(label: Text('')),
            ],
            rows: trainers.map((tw) {
              final t = tw.model;
              return DataRow(
                onSelectChanged: (_) => onTrainerTap(tw),
                cells: [
                  DataCell(Row(children: [
                    _AvatarWithStatus(avatarUrl: t.avatarUrl, isClockedIn: t.isClockedIn),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${t.specialty} • ${t.phone}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ])),
                  DataCell(Text('${tw.clientCount} / ${t.clientCapacity}')),
                  DataCell(Text('${t.shiftStart} - ${t.shiftEnd}', style: const TextStyle(color: AppColors.textSecondary))),
                  DataCell(_StatusBadge(liveStatus: t.liveStatus)),
                  DataCell(_OverflowMenu(trainerName: t.name)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
