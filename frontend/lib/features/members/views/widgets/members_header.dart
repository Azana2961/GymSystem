import 'package:flutter/material.dart';
import 'package:gym_system/core/services/export_service.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';
import 'package:gym_system/features/members/views/widgets/member_form_dialog.dart';

class MembersHeader extends StatefulWidget {
  final MembersProvider provider;

  const MembersHeader({super.key, required this.provider});

  @override
  State<MembersHeader> createState() => _MembersHeaderState();
}

class _MembersHeaderState extends State<MembersHeader> {
  bool _isExporting = false;

  Future<void> _handleExport(BuildContext context, String format) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final members = widget.provider.allMembers;
      final ExportResult result;
      if (format == 'csv') {
        result = await ExportService.instance.exportMembersCsv(members);
      } else {
        result = await ExportService.instance.exportMembersPdf(members);
      }

      if (!context.mounted) return;
      setState(() => _isExporting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B1B20),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: result.success ? AppColors.success : AppColors.error,
              width: 1.2,
            ),
          ),
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: result.success ? AppColors.success : AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.success
                          ? '⚡ ${format.toUpperCase()} saved: ${result.fileName}'
                          : result.message,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (result.success) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Saved to Downloads & opened in default app',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              if (result.success) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => ExportService.instance.revealInFolder(result.filePath),
                  child: const Text(
                    'Show in Folder',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Export failed: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Members', style: Theme.of(context).textTheme.headlineLarge),
        Row(
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                onChanged: widget.provider.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search by name, ID, or plan...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              tooltip: 'Sync with SQLite Database',
              onPressed: () => widget.provider.refresh(),
            ),
            const SizedBox(width: 10),

            // Export Menu Popup
            PopupMenuButton<String>(
              tooltip: 'Export Members',
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.border),
              ),
              onSelected: (val) => _handleExport(context, val),
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart_outlined, color: AppColors.primary, size: 18),
                      SizedBox(width: 10),
                      Text('Export as CSV (Excel)', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary, size: 18),
                      SizedBox(width: 10),
                      Text('Export as PDF Document', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  children: [
                    if (_isExporting) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Exporting...',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ] else ...[
                      const Icon(Icons.file_download_outlined, color: AppColors.primary, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Export',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 16),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => MemberFormDialog(provider: widget.provider),
                );
              },
              icon: const Icon(Icons.add, color: AppColors.background),
              label: const Text('Add Member', style: TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
