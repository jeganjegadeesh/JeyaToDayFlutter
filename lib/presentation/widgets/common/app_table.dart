import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AppTable extends StatelessWidget {
  final List<String> headers;
  final List<List<dynamic>> rows;
  final List<double>? columnWidths;
  final bool isLoading;
  final String emptyMessage;

  const AppTable({
    super.key,
    required this.headers,
    required this.rows,
    this.columnWidths,
    this.isLoading = false,
    this.emptyMessage = 'No data found.',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(
                Icons.inbox_outlined,
                size: 48,
                color: AppColors.textHint,
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header Row
        Container(
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
          child: Row(
            children: headers.asMap().entries.map((entry) {
              final index = entry.key;
              final header = entry.value;
              return Expanded(
                flex: columnWidths != null
                    ? (columnWidths![index] * 10).toInt()
                    : 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Text(
                    header,
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Data Rows
        ...rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return Container(
            decoration: BoxDecoration(
              color: index % 2 == 0
                  ? AppColors.surface
                  : AppColors.background,
              border: const Border(
                bottom: BorderSide(color: AppColors.divider),
                left: BorderSide(color: AppColors.divider),
                right: BorderSide(color: AppColors.divider),
              ),
              borderRadius: index == rows.length - 1
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    )
                  : null,
            ),
            child: Row(
              children: row.asMap().entries.map((cellEntry) {
                final cellIndex = cellEntry.key;
                final cell = cellEntry.value;
                return Expanded(
                  flex: columnWidths != null
                      ? (columnWidths![cellIndex] * 10).toInt()
                      : 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: cell is Widget
                        ? cell
                        : Text(
                            cell.toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }
}

// Status Badge
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Action Buttons for table rows
class TableActions extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onView;

  const TableActions({
    super.key,
    this.onEdit,
    this.onDelete,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onView != null)
          IconButton(
            onPressed: onView,
            icon: const Icon(Icons.visibility_outlined),
            color: AppColors.info,
            iconSize: 18,
            tooltip: 'View',
          ),
        if (onEdit != null)
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.warning,
            iconSize: 18,
            tooltip: 'Edit',
          ),
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: AppColors.error,
            iconSize: 18,
            tooltip: 'Delete',
          ),
      ],
    );
  }
}