import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/system_config_detail.dart';
import '../../domain/repositories/business_rules_repository.dart';
import '../providers/business_rules_providers.dart';
import 'config_audit_history_view.dart';
import 'config_conflict_dialog.dart';
import 'config_save_confirmation_dialog.dart';
import 'editors/cancellation_matrix_editor.dart';
import 'editors/commission_config_editor.dart';
import 'editors/deposits_defaults_editor.dart';
import 'editors/duration_discounts_editor.dart';
import 'editors/generic_config_editor.dart';
import 'editors/quote_config_editor.dart';
import 'editors/tax_config_editor.dart';

/// Full-featured context-preserving side drawer for inspecting, editing,
/// and reviewing the audit trail of any platform business rule.
class ConfigDetailDrawer extends ConsumerStatefulWidget {
  final SystemConfigDetail config;
  final VoidCallback? onClose;

  const ConfigDetailDrawer({
    super.key,
    required this.config,
    this.onClose,
  });

  static Future<void> show({
    required BuildContext context,
    required SystemConfigDetail config,
  }) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);

    if (isDesktop || isTablet) {
      return showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss Config Drawer',
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, anim1, anim2) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 620,
                height: double.infinity,
                child: ConfigDetailDrawer(
                  config: config,
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, anim1, anim2, widget) {
          final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: widget,
          );
        },
      );
    } else {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ConfigDetailDrawer(
            config: config,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<ConfigDetailDrawer> createState() => _ConfigDetailDrawerState();
}

class _ConfigDetailDrawerState extends ConsumerState<ConfigDetailDrawer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late dynamic _currentDraftValue;
  bool _isDirty = false;
  bool _isEditorValid = true;
  String? _clientValidationError;

  void _resetToInitial() {
    _currentDraftValue = widget.config.effectiveValue;
    _isDirty = false;
    _isEditorValid = true;
    _clientValidationError = null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _resetToInitial();
  }

  @override
  void didUpdateWidget(covariant ConfigDetailDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.key != widget.config.key ||
        oldWidget.config.version != widget.config.version) {
      _resetToInitial();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onValueChanged(dynamic newValue, bool isValid) {
    setState(() {
      _currentDraftValue = newValue;
      _isDirty = true;
      _isEditorValid = isValid;
      _clientValidationError = isValid
          ? null
          : 'Please correct invalid values before submitting.';
    });
  }

  void _resetDraft() {
    setState(() {
      _resetToInitial();
    });
  }

  Future<void> _initiateSave() async {
    final canEdit = ref.read(canEditConfigurationsProvider);
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unauthorized: SYSTEM_CONFIG_WRITE permission is required to edit.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!_isEditorValid) {
      setState(() {
        _clientValidationError = 'Cannot save: form contains validation errors.';
      });
      return;
    }

    // Confirmation dialog showing before/after diff and reason input
    final reason = await ConfigSaveConfirmationDialog.show(
      context: context,
      config: widget.config,
      newValue: _currentDraftValue,
    );

    if (reason == null) {
      return;
    }

    try {
      await ref.read(ruleMutationControllerProvider.notifier).updateRule(
            key: widget.config.key,
            value: _currentDraftValue,
            expectedVersion: widget.config.version,
            reason: reason,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const Gap(10),
                Expanded(
                  child: Text(
                    '${widget.config.humanReadableName} updated successfully.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );

        setState(() {
          _isDirty = false;
        });

        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop();
        }
      }
    } on ConcurrencyConflictException catch (conflict) {
      if (!mounted) return;
      await ConfigConflictDialog.show(
        context: context,
        conflict: conflict,
        onReload: () {
          ref.invalidate(businessRulesListProvider);
          ref.invalidate(selectedRuleDetailProvider);
          Navigator.of(context).pop();
        },
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update rule: $err'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(canEditConfigurationsProvider);
    final mutationState = ref.watch(ruleMutationControllerProvider);
    final isSubmitting = mutationState.isLoading;

    final config = widget.config;
    final isDb = config.isExplicitlyConfigured;
    final formattedDate = config.updatedAt != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(config.updatedAt!)
        : 'Initial system seed';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 32,
            offset: const Offset(-6, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.humanReadableName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Gap(2),
                          SelectableText(
                            config.key,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                      onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                      tooltip: 'Close Drawer',
                    ),
                  ],
                ),
                const Gap(14),
                // Metadata Pills
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Source Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDb ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDb ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDb ? Icons.storage_rounded : Icons.info_outline_rounded,
                            size: 13,
                            color: isDb ? const Color(0xFF15803D) : const Color(0xFFB45309),
                          ),
                          const Gap(5),
                          Text(
                            isDb ? 'DATABASE (OVERRIDDEN)' : 'DEFAULT FALLBACK',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDb ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Version Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        'Revision: v${config.version}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    // Public/Internal Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: config.isPublic ? const Color(0xFFE0F2FE) : const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: config.isPublic ? const Color(0xFFBAE6FD) : const Color(0xFFE9D5FF),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            config.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                            size: 12,
                            color: config.isPublic ? const Color(0xFF0369A1) : const Color(0xFF7E22CE),
                          ),
                          const Gap(4),
                          Text(
                            config.isPublic ? 'PUBLIC SAFE' : 'INTERNAL ONLY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: config.isPublic ? const Color(0xFF0369A1) : const Color(0xFF7E22CE),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Last Updated Info
                    Text(
                      'Last modified $formattedDate by ${config.updatedBy ?? "system"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── Tabs ───
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.edit_note_rounded, size: 18),
                  text: 'Configuration Editor',
                ),
                Tab(
                  icon: Icon(Icons.history_rounded, size: 18),
                  text: 'Audit Trail & History',
                ),
              ],
            ),
          ),

          // ─── Tab Content ───
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Editor
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Permission banner if read-only
                      if (!canEdit)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 20),
                              Gap(12),
                              Expanded(
                                child: Text(
                                  'READ-ONLY MODE: You have viewing access (SYSTEM_CONFIG_READ) but not write authorization (SYSTEM_CONFIG_WRITE). Editing controls are disabled.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF991B1B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Description Box
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded,
                                color: Color(0xFF475569), size: 18),
                            const Gap(10),
                            Expanded(
                              child: Text(
                                config.description ?? 'Platform business rule configuration parameter.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Client-side validation message if any
                      if (_clientValidationError != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF87171)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFDC2626), size: 18),
                              const Gap(8),
                              Expanded(
                                child: Text(
                                  _clientValidationError!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFFB91C1C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Dedicated Editor switcher
                      _buildDedicatedEditor(config, canEdit),
                    ],
                  ),
                ),

                // Tab 2: Audit History
                ConfigAuditHistoryView(configKey: config.key),
              ],
            ),
          ),

          // ─── Footer Action Bar ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
              children: [
                if (_isDirty)
                  TextButton.icon(
                    onPressed: _resetDraft,
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: const Text('Discard Changes'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                const Spacer(),
                OutlinedButton(
                  onPressed: isSubmitting
                      ? null
                      : (widget.onClose ?? () => Navigator.of(context).pop()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    foregroundColor: const Color(0xFF334155),
                  ),
                  child: const Text('Close'),
                ),
                const Gap(12),
                ElevatedButton.icon(
                  onPressed: (!canEdit || !_isDirty || isSubmitting) ? null : _initiateSave,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(isSubmitting ? 'Validating & Saving...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF94A3B8),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDedicatedEditor(SystemConfigDetail config, bool canEdit) {
    switch (config.key) {
      case 'pricing.tax':
        return TaxConfigEditor(
          initialValue: _currentDraftValue is Map
              ? Map<String, dynamic>.from(_currentDraftValue as Map)
              : <String, dynamic>{},
          isReadOnly: !canEdit,
          onChanged: _onValueChanged,
        );

      case 'pricing.quote':
        return QuoteConfigEditor(
          initialValue: _currentDraftValue is Map
              ? Map<String, dynamic>.from(_currentDraftValue as Map)
              : <String, dynamic>{},
          isReadOnly: !canEdit,
          onChanged: _onValueChanged,
        );

      case 'pricing.duration_discounts':
        return DurationDiscountsEditor(
          initialValue: _currentDraftValue,
          isReadOnly: !canEdit,
          onChanged: _onValueChanged,
        );

      case 'booking.cancellation_matrix':
        return CancellationMatrixEditor(
          initialValue: _currentDraftValue is Map
              ? Map<String, dynamic>.from(_currentDraftValue as Map)
              : <String, dynamic>{},
          isReadOnly: !canEdit,
          onChanged: _onValueChanged,
        );

      case 'pricing.commission':
        return CommissionConfigEditor(
          initialValue: _currentDraftValue is Map
              ? Map<String, dynamic>.from(_currentDraftValue as Map)
              : <String, dynamic>{},
          isReadOnly: !canEdit,
          onChanged: _onValueChanged,
        );

      case 'deposits.defaults':
        return DepositsDefaultsEditor(
          initialValue: _currentDraftValue is Map
              ? Map<String, dynamic>.from(_currentDraftValue as Map)
              : <String, dynamic>{},
          isReadOnly: !canEdit,
          onChanged: _onValueChanged,
        );

      default:
        return GenericConfigEditor(
          initialValue: _currentDraftValue,
          isReadOnly: !canEdit,
          onChanged: _onValueChanged,
        );
    }
  }
}
