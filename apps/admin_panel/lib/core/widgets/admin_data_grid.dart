import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Definition of a column in the shared AdminDataGrid.
class AdminDataColumn<T> {
  final String title;
  final Widget Function(T item) builder;
  final int flex;
  final double? fixedWidth;
  final bool numeric;
  final String? tooltip;
  final Comparable Function(T item)? sortKey;

  const AdminDataColumn({
    required this.title,
    required this.builder,
    this.flex = 1,
    this.fixedWidth,
    this.numeric = false,
    this.tooltip,
    this.sortKey,
  });
}

/// Enterprise-grade responsive data grid for the DriveGo Admin Control Tower.
/// Automatically adapts between:
/// - Desktop (>= 1024px): Full multi-column data table with sort headers, hover feedback, and fixed sizing.
/// - Tablet (600px - 1023px): Horizontally scrollable high-density table.
/// - Mobile (< 600px): Clean record cards list when [mobileCardBuilder] is provided, or compact card view.
class AdminDataGrid<T> extends StatelessWidget {
  final List<AdminDataColumn<T>> columns;
  final List<T> items;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final void Function(T item)? onRowTap;
  final Widget Function(BuildContext context, T item)? mobileCardBuilder;
  final Set<String>? selectedIds;
  final String Function(T item)? idGetter;
  final void Function(bool? selected, T item)? onSelectRow;
  final void Function(bool? selectedAll)? onSelectAll;
  final double minWidth;
  final double rowHeight;
  final double headingHeight;

  const AdminDataGrid({
    super.key,
    required this.columns,
    required this.items,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.emptyTitle = 'No records found',
    this.emptyMessage = 'No matching data found for the selected filters.',
    this.emptyIcon = Icons.inbox_outlined,
    this.onRowTap,
    this.mobileCardBuilder,
    this.selectedIds,
    this.idGetter,
    this.onSelectRow,
    this.onSelectAll,
    this.minWidth = 900,
    this.rowHeight = 56,
    this.headingHeight = 48,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AdminTableSkeleton();
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return AdminErrorState(
        message: errorMessage!,
        onRetry: onRetry,
      );
    }

    if (items.isEmpty) {
      return AdminEmptyState(
        title: emptyTitle,
        message: emptyMessage,
        icon: emptyIcon,
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    // Mobile adaptation using card records if provided
    if (isMobile && mobileCardBuilder != null) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Gap(12),
        itemBuilder: (ctx, index) {
          final item = items[index];
          return InkWell(
            onTap: onRowTap != null ? () => onRowTap!(item) : null,
            borderRadius: BorderRadius.circular(12),
            child: mobileCardBuilder!(ctx, item),
          );
        },
      );
    }

    final hasSelection = selectedIds != null && idGetter != null && onSelectRow != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: minWidth),
          child: DataTable(
            showCheckboxColumn: hasSelection,
            onSelectAll: hasSelection && onSelectAll != null ? onSelectAll : null,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            headingRowHeight: headingHeight,
            dataRowMinHeight: rowHeight,
            dataRowMaxHeight: rowHeight + 12,
            horizontalMargin: 16,
            columnSpacing: 20,
            dividerThickness: 1,
            columns: columns.map((col) {
              return DataColumn(
                numeric: col.numeric,
                tooltip: col.tooltip,
                label: Text(
                  col.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                    letterSpacing: 0.3,
                  ),
                ),
              );
            }).toList(),
            rows: items.map((item) {
              final isSelected = hasSelection && selectedIds!.contains(idGetter!(item));
              return DataRow(
                selected: isSelected,
                onSelectChanged: hasSelection
                    ? (sel) => onSelectRow!(sel, item)
                    : (onRowTap != null ? (_) => onRowTap!(item) : null),
                color: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF2563EB).withValues(alpha: 0.08);
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return const Color(0xFFF1F5F9);
                  }
                  return null;
                }),
                cells: columns.map((col) {
                  return DataCell(
                    col.builder(item),
                    onTap: onRowTap != null ? () => onRowTap!(item) : null,
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Unified Table Toolbar with search input, filters, item counters, and action buttons.
class AdminTableToolbar extends StatelessWidget {
  final String? searchHint;
  final String? searchValue;
  final ValueChanged<String>? onSearchChanged;
  final List<Widget>? filters;
  final int? totalCount;
  final List<Widget>? actions;
  final Widget? bulkActionBar;

  const AdminTableToolbar({
    super.key,
    this.searchHint = 'Search records...',
    this.searchValue,
    this.onSearchChanged,
    this.filters,
    this.totalCount,
    this.actions,
    this.bulkActionBar,
  });

  @override
  Widget build(BuildContext context) {
    if (bulkActionBar != null) {
      return bulkActionBar!;
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isMobile) ...[
          // Mobile stack layout
          if (onSearchChanged != null)
            AdminSearchField(
              hint: searchHint ?? 'Search...',
              value: searchValue,
              onChanged: onSearchChanged!,
            ),
          if (filters != null && filters!.isNotEmpty) ...[
            const Gap(12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters!.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: f,
                )).toList(),
              ),
            ),
          ],
          if (actions != null && actions!.isNotEmpty) ...[
            const Gap(12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (totalCount != null)
                  Text(
                    '$totalCount Records',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                Row(children: actions!),
              ],
            ),
          ],
        ] else ...[
          // Desktop / Tablet row layout
          Row(
            children: [
              if (onSearchChanged != null)
                SizedBox(
                  width: 260,
                  child: AdminSearchField(
                    hint: searchHint ?? 'Search records...',
                    value: searchValue,
                    onChanged: onSearchChanged!,
                  ),
                ),
              if (filters != null && filters!.isNotEmpty) ...[
                const Gap(12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filters!.map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: f,
                      )).toList(),
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              const Gap(12),
              if (totalCount != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$totalCount Records',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const Gap(12),
              ],
              if (actions != null) ...actions!,
            ],
          ),
        ],
      ],
    );
  }
}

/// Standard Search Input Field with clear icon.
class AdminSearchField extends StatefulWidget {
  final String hint;
  final String? value;
  final ValueChanged<String> onChanged;

  const AdminSearchField({
    super.key,
    required this.hint,
    this.value,
    required this.onChanged,
  });

  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant AdminSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && widget.value != null) {
      _controller.text = widget.value!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}

/// Standardized Status Badge for all Admin Control Tower domain entities.
class AdminStatusBadge extends StatelessWidget {
  final String status;
  final Color? color;
  final IconData? icon;
  final bool compact;

  const AdminStatusBadge({
    super.key,
    required this.status,
    this.color,
    this.icon,
    this.compact = false,
  });

  static Color resolveColor(String status) {
    final upper = status.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_');
    switch (upper) {
      case 'ACTIVE':
      case 'CONFIRMED':
      case 'VERIFIED':
      case 'PAID':
      case 'APPROVED':
      case 'RESOLVED':
      case 'HIGH_PRIORITY':
      case 'COMPLETED':
      case 'ON_TRIP':
        return const Color(0xFF059669); // Emerald
      case 'PENDING':
      case 'PENDING_APPROVAL':
      case 'PENDING_REVIEW':
      case 'IN_PROGRESS':
      case 'MEDIUM_PRIORITY':
      case 'SCHEDULED':
      case 'HELD':
        return const Color(0xFFD97706); // Amber
      case 'CANCELLED':
      case 'REJECTED':
      case 'SUSPENDED':
      case 'FAILED':
      case 'CRITICAL':
      case 'BANNED':
      case 'OVERDUE':
      case 'DISPUTED':
        return const Color(0xFFE11D48); // Rose
      case 'PAUSED':
      case 'TEMPORARILY_CLOSED':
      case 'INACTIVE':
      case 'CLOSED':
      case 'ARCHIVED':
      case 'LOW_PRIORITY':
      case 'OFFLINE':
        return const Color(0xFF64748B); // Slate
      case 'DRAFT':
      case 'REFUNDED':
      case 'INFO':
      default:
        return const Color(0xFF2563EB); // Blue
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? resolveColor(status);
    final formattedText = status.replaceAll('_', ' ').toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: effectiveColor),
            const Gap(4),
          ] else ...[
            Container(
              width: compact ? 5 : 6,
              height: compact ? 5 : 6,
              decoration: BoxDecoration(
                color: effectiveColor,
                shape: BoxShape.circle,
              ),
            ),
            const Gap(6),
          ],
          Text(
            formattedText,
            style: TextStyle(
              color: effectiveColor,
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standardized Shimmer Loader for Admin Tables.
class AdminTableSkeleton extends StatelessWidget {
  final int rowCount;

  const AdminTableSkeleton({super.key, this.rowCount = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(rowCount, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Gap(24),
                Expanded(
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Gap(24),
                Container(
                  width: 80,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Standard Empty State for Data Grids.
class AdminEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  const AdminEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF64748B)),
            ),
            const Gap(16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const Gap(6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ),
            if (action != null) ...[
              const Gap(20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard Error State for Data Grids with Retry Button.
class AdminErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AdminErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: Color(0xFFDC2626)),
            const Gap(12),
            const Text(
              'Failed to load operational data',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF991B1B),
              ),
            ),
            const Gap(4),
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const Gap(16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard Pagination Bar for Data Grids.
class AdminPagination extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;

  const AdminPagination({
    super.key,
    required this.currentPage,
    required this.totalItems,
    this.pageSize = 25,
    this.pageSizeOptions = const [10, 25, 50, 100],
    this.onPageChanged,
    this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final startItem = totalItems == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;
    final endItem = (currentPage * pageSize) > totalItems ? totalItems : (currentPage * pageSize);
    final totalPages = (totalItems / pageSize).ceil().clamp(1, 9999);

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem–$endItem of $totalItems items',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          Row(
            children: [
              if (!isMobile && onPageSizeChanged != null) ...[
                const Text('Per page:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const Gap(8),
                DropdownButton<int>(
                  value: pageSize,
                  underline: const SizedBox(),
                  isDense: true,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  items: pageSizeOptions.map((sz) {
                    return DropdownMenuItem<int>(
                      value: sz,
                      child: Text('$sz'),
                    );
                  }).toList(),
                  onChanged: (newSize) {
                    if (newSize != null && onPageSizeChanged != null) {
                      onPageSizeChanged!(newSize);
                    }
                  },
                ),
                const Gap(16),
              ],
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: currentPage > 1 && onPageChanged != null
                    ? () => onPageChanged!(currentPage - 1)
                    : null,
                visualDensity: VisualDensity.compact,
                tooltip: 'Previous Page',
              ),
              Text(
                'Page $currentPage of $totalPages',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: currentPage < totalPages && onPageChanged != null
                    ? () => onPageChanged!(currentPage + 1)
                    : null,
                visualDensity: VisualDensity.compact,
                tooltip: 'Next Page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
