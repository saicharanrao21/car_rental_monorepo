import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import '../../data/repositories/admin_integrations_repository.dart';

class NotificationRulesCentreWidget extends ConsumerStatefulWidget {
  const NotificationRulesCentreWidget({super.key});

  @override
  ConsumerState<NotificationRulesCentreWidget> createState() =>
      _NotificationRulesCentreWidgetState();
}

class _NotificationRulesCentreWidgetState
    extends ConsumerState<NotificationRulesCentreWidget> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _rules = [];
  String _searchQuery = '';
  String _roleFilter = 'ALL';
  String _channelFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminIntegrationsRepositoryProvider);
      final rules = await repo.getNotificationRules();
      if (mounted) {
        setState(() {
          _rules = rules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleRule(Map<String, dynamic> rule, bool isEnabled) async {
    final ruleId = rule['id'] as String;
    final repo = ref.read(adminIntegrationsRepositoryProvider);

    try {
      await repo.toggleNotificationRule(ruleId, isEnabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rule for ${rule['label'] ?? rule['eventType']} ${isEnabled ? 'enabled' : 'disabled'}.',
            ),
            backgroundColor: isEnabled ? const Color(0xFF10B981) : Colors.orange,
          ),
        );
      }
      await _loadRules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle rule: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditRuleDialog(Map<String, dynamic> rule) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditNotificationRuleDialog(
        rule: rule,
        onSave: (updated) async {
          final repo = ref.read(adminIntegrationsRepositoryProvider);
          try {
            await repo.upsertNotificationRule(updated);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification rule saved successfully!'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            }
            await _loadRules();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update rule: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  void _showSimulationDialog([String? defaultEventType]) {
    showDialog(
      context: context,
      builder: (ctx) => _SimulateNotificationDialog(
        defaultEventType: defaultEventType,
        rules: _rules,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0F172A),
                theme.colorScheme.primaryContainer.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.rule_rounded, color: Color(0xFF818CF8), size: 24),
                        ),
                        const Gap(14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Event & Notification Rules Centre',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Gap(2),
                              Text(
                                'Canonical lifecycle event routing matrix • Zero-code channel control • Quiet hours governance',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                    Text(
                      'Configure dynamic dispatch rules for all 13 canonical system lifecycle events. Control target roles, multi-channel broadcast permissions (WhatsApp, Push, Email, SMS), and quiet hours bypass compliance without app redeployment.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24),
              Column(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Simulate Dispatch'),
                    onPressed: () => _showSimulationDialog(),
                  ),
                  const Gap(10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF475569)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh Rules'),
                    onPressed: _loadRules,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(20),

        // KPI Summary Strip
        _buildKpis(theme),
        const Gap(20),

        // Search & Filters
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Search 13 lifecycle events (e.g. BOOKING_CONFIRMED, PAYMENT_FAILED, OTP)...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const Gap(16),
            // Target Role Filter
            DropdownButton<String>(
              value: _roleFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Roles')),
                DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer')),
                DropdownMenuItem(value: 'VENDOR', child: Text('Vendor Partner')),
                DropdownMenuItem(value: 'ADMIN', child: Text('Admin Ops')),
                DropdownMenuItem(value: 'SUPPORT', child: Text('Support Team')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _roleFilter = val);
              },
            ),
            const Gap(16),
            // Channel Filter
            DropdownButton<String>(
              value: _channelFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Channels')),
                DropdownMenuItem(value: 'WHATSAPP', child: Text('WhatsApp')),
                DropdownMenuItem(value: 'PUSH', child: Text('Push Notifications')),
                DropdownMenuItem(value: 'EMAIL', child: Text('Email')),
                DropdownMenuItem(value: 'SMS', child: Text('SMS')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _channelFilter = val);
              },
            ),
          ],
        ),
        const Gap(16),

        // Rules Table or Loader
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: AppLoader()))
        else if (_errorMessage != null)
          ErrorStateWidget(
            message: 'Failed to load notification rules: $_errorMessage',
            onRetry: _loadRules,
          )
        else
          _buildRulesTable(theme),
      ],
    );
  }

  Widget _buildKpis(ThemeData theme) {
    final totalRules = _rules.length;
    final activeRules = _rules.where((r) => r['isEnabled'] == true).length;
    final whatsappCount = _rules.where((r) => r['channels']?['whatsapp'] == true).length;
    final pushCount = _rules.where((r) => r['channels']?['push'] == true).length;
    final emailCount = _rules.where((r) => r['channels']?['email'] == true).length;
    final smsCount = _rules.where((r) => r['channels']?['sms'] == true).length;
    final bypassCount = _rules.where((r) => r['allowQuietHoursBypass'] == true).length;

    return Row(
      children: [
        _buildKpiCard(
          theme,
          label: 'Canonical Lifecycle Events',
          value: '$activeRules Active / $totalRules',
          icon: Icons.event_note_rounded,
          color: const Color(0xFF6366F1),
        ),
        const Gap(12),
        _buildKpiCard(
          theme,
          label: 'WhatsApp Gateway',
          value: '$whatsappCount Events',
          icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF25D366),
        ),
        const Gap(12),
        _buildKpiCard(
          theme,
          label: 'Push Gateway',
          value: '$pushCount Events',
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFF3B82F6),
        ),
        const Gap(12),
        _buildKpiCard(
          theme,
          label: 'Email & SMS Fallbacks',
          value: '$emailCount Email / $smsCount SMS',
          icon: Icons.send_to_mobile_rounded,
          color: const Color(0xFFF59E0B),
        ),
        const Gap(12),
        _buildKpiCard(
          theme,
          label: 'Quiet Hours Bypass',
          value: '$bypassCount Critical Events',
          icon: Icons.shield_rounded,
          color: const Color(0xFFEF4444),
        ),
      ],
    );
  }

  Widget _buildKpiCard(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesTable(ThemeData theme) {
    final filtered = _rules.where((r) {
      if (_roleFilter != 'ALL' && r['recipientRole'] != _roleFilter) return false;
      if (_channelFilter != 'ALL') {
        final key = _channelFilter.toLowerCase();
        if (r['channels']?[key] != true) return false;
      }
      final q = _searchQuery.trim().toLowerCase();
      if (q.isNotEmpty) {
        final eventType = (r['eventType'] as String? ?? '').toLowerCase();
        final label = (r['label'] as String? ?? '').toLowerCase();
        final desc = (r['description'] as String? ?? '').toLowerCase();
        if (!eventType.contains(q) && !label.contains(q) && !desc.contains(q)) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const AppCard(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rule_folder_outlined, size: 48, color: Colors.grey),
              Gap(12),
              Text('No matching notification rules found', style: TextStyle(fontWeight: FontWeight.bold)),
              Gap(6),
              Text('Try adjusting search filters or reset to All Channels.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 20,
            horizontalMargin: 16,
            headingRowHeight: 48,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('Lifecycle Event', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Recipient Role', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Permitted Channels', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Quiet Hours Policy', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: filtered.map((rule) {
              final isEnabled = rule['isEnabled'] == true;
              final channels = rule['channels'] as Map<String, dynamic>? ?? {};
              final allowBypass = rule['allowQuietHoursBypass'] == true;

              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF6366F1).withOpacity(0.12),
                          child: const Icon(Icons.bolt_rounded, color: Color(0xFF6366F1), size: 16),
                        ),
                        const Gap(10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              rule['label'] as String? ?? rule['eventType'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              rule['eventType'] as String? ?? '',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    _buildRoleBadge(rule['recipientRole'] as String? ?? 'CUSTOMER'),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildChannelPill('WA', channels['whatsapp'] == true, const Color(0xFF25D366)),
                        const Gap(6),
                        _buildChannelPill('PUSH', channels['push'] == true, const Color(0xFF3B82F6)),
                        const Gap(6),
                        _buildChannelPill('EMAIL', channels['email'] == true, const Color(0xFF8B5CF6)),
                        const Gap(6),
                        _buildChannelPill('SMS', channels['sms'] == true, const Color(0xFFF59E0B)),
                      ],
                    ),
                  ),
                  DataCell(
                    allowBypass
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flash_on_rounded, size: 13, color: Color(0xFFEF4444)),
                                Gap(4),
                                Text(
                                  'Bypass Allowed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.nightlight_round, size: 12, color: Color(0xFF10B981)),
                                Gap(4),
                                Text(
                                  'Respects 9PM-8AM',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                  ),
                  DataCell(
                    Switch(
                      value: isEnabled,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) => _toggleRule(rule, val),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Color(0xFF6366F1)),
                          label: const Text('Simulate'),
                          onPressed: () => _showSimulationDialog(rule['eventType'] as String?),
                        ),
                        const Gap(6),
                        IconButton(
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Rule Channels & Policy',
                          onPressed: () => _showEditRuleDialog(rule),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role) {
      case 'VENDOR':
        color = const Color(0xFF8B5CF6);
        break;
      case 'ADMIN':
        color = const Color(0xFFEF4444);
        break;
      case 'SUPPORT':
        color = const Color(0xFFF59E0B);
        break;
      default:
        color = const Color(0xFF3B82F6);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildChannelPill(String code, bool enabled, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: enabled ? color.withOpacity(0.14) : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: enabled ? color.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
          width: 0.8,
        ),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: enabled ? color : Colors.grey,
        ),
      ),
    );
  }
}

// ============================================================================
// EDIT NOTIFICATION RULE DIALOG
// ============================================================================

class _EditNotificationRuleDialog extends StatefulWidget {
  final Map<String, dynamic> rule;
  final Function(Map<String, dynamic> updated) onSave;

  const _EditNotificationRuleDialog({required this.rule, required this.onSave});

  @override
  State<_EditNotificationRuleDialog> createState() =>
      _EditNotificationRuleDialogState();
}

class _EditNotificationRuleDialogState
    extends State<_EditNotificationRuleDialog> {
  late bool _whatsapp;
  late bool _push;
  late bool _email;
  late bool _sms;
  late bool _allowBypass;
  late bool _isEnabled;
  late final TextEditingController _descController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final channels = widget.rule['channels'] as Map<String, dynamic>? ?? {};
    _whatsapp = channels['whatsapp'] == true;
    _push = channels['push'] == true;
    _email = channels['email'] == true;
    _sms = channels['sms'] == true;
    _allowBypass = widget.rule['allowQuietHoursBypass'] == true;
    _isEnabled = widget.rule['isEnabled'] == true;
    _descController = TextEditingController(text: widget.rule['description'] as String? ?? '');
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    final updated = Map<String, dynamic>.from(widget.rule);
    updated['channels'] = {
      'whatsapp': _whatsapp,
      'push': _push,
      'email': _email,
      'sms': _sms,
    };
    updated['allowQuietHoursBypass'] = _allowBypass;
    updated['isEnabled'] = _isEnabled;
    updated['description'] = _descController.text.trim();

    try {
      await widget.onSave(updated);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.rule['label'] as String? ?? widget.rule['eventType'] as String;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.tune_rounded, color: Color(0xFF6366F1), size: 22),
          const Gap(10),
          Expanded(child: Text('Edit Rule: $label', style: const TextStyle(fontSize: 17))),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Identifier: ${widget.rule['eventType']}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey),
            ),
            const Gap(16),
            const Text('Permitted Delivery Gateways:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Gap(8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('WhatsApp Cloud API (Primary Conversational)'),
              value: _whatsapp,
              onChanged: (val) => setState(() => _whatsapp = val ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Push Notifications (Mobile Apps & Background Alerts)'),
              value: _push,
              onChanged: (val) => setState(() => _push = val ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transactional Email (Invoices, Agreements & Statements)'),
              value: _email,
              onChanged: (val) => setState(() => _email = val ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('High-Priority SMS Gateway (Fallback & OTP)'),
              value: _sms,
              onChanged: (val) => setState(() => _sms = val ?? false),
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow Quiet Hours Bypass (21:00 - 08:00)', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Enable for mission-critical OTPs, cancellations, or emergency safety alerts.', style: TextStyle(fontSize: 12)),
              value: _allowBypass,
              onChanged: (val) => setState(() => _allowBypass = val),
            ),
            const Gap(8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Master Rule Active Status', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('When disabled, this event will be completely silenced in dispatch runtime.', style: TextStyle(fontSize: 12)),
              value: _isEnabled,
              onChanged: (val) => setState(() => _isEnabled = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        _isSaving
            ? const Center(child: AppLoader())
            : ElevatedButton(
                onPressed: _submit,
                child: const Text('Save Rule'),
              ),
      ],
    );
  }
}

// ============================================================================
// SIMULATE NOTIFICATION RULE DIALOG
// ============================================================================

class _SimulateNotificationDialog extends ConsumerStatefulWidget {
  final String? defaultEventType;
  final List<Map<String, dynamic>> rules;

  const _SimulateNotificationDialog({this.defaultEventType, required this.rules});

  @override
  ConsumerState<_SimulateNotificationDialog> createState() =>
      _SimulateNotificationDialogState();
}

class _SimulateNotificationDialogState
    extends ConsumerState<_SimulateNotificationDialog> {
  late String _selectedEvent;
  String _selectedRole = 'CUSTOMER';
  bool _isSimulating = false;
  Map<String, dynamic>? _simulationResult;
  String? _simError;

  @override
  void initState() {
    super.initState();
    _selectedEvent = widget.defaultEventType ??
        (widget.rules.isNotEmpty
            ? widget.rules.first['eventType'] as String
            : 'BOOKING_CONFIRMED');
    _executeSimulation();
  }

  Future<void> _executeSimulation() async {
    setState(() {
      _isSimulating = true;
      _simError = null;
    });

    final repo = ref.read(adminIntegrationsRepositoryProvider);
    try {
      final res = await repo.simulateNotificationRule(
        _selectedEvent,
        recipientRole: _selectedRole,
      );
      if (mounted) {
        setState(() {
          _simulationResult = res;
          _isSimulating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _simError = e.toString();
          _isSimulating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.bolt_rounded, color: Color(0xFF6366F1), size: 24),
          Gap(10),
          Text('Event Dispatch Simulator & Pre-Flight Check', style: TextStyle(fontSize: 17)),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Simulator Input Controls
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedEvent,
                      decoration: const InputDecoration(
                        labelText: 'Trigger Event',
                        isDense: true,
                      ),
                      items: widget.rules.map((r) {
                        final code = r['eventType'] as String;
                        final label = r['label'] as String? ?? code;
                        return DropdownMenuItem(value: code, child: Text(label, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedEvent = val);
                          _executeSimulation();
                        }
                      },
                    ),
                  ),
                  const Gap(14),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Recipient Role',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CUSTOMER', child: Text('Customer')),
                        DropdownMenuItem(value: 'VENDOR', child: Text('Vendor Partner')),
                        DropdownMenuItem(value: 'ADMIN', child: Text('Admin Ops')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedRole = val);
                          _executeSimulation();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const Gap(16),

              // Simulation Preview Output
              if (_isSimulating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: AppLoader(),
                  ),
                )
              else if (_simError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Simulation error: $_simError', style: const TextStyle(color: Colors.red)),
                )
              else if (_simulationResult != null)
                _buildSimulationDetails(theme, _simulationResult!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Re-Simulate'),
          onPressed: _executeSimulation,
        ),
      ],
    );
  }

  Widget _buildSimulationDetails(ThemeData theme, Map<String, dynamic> res) {
    final activeRule = res['activeRule'] as Map<String, dynamic>? ?? {};
    final resolvedChannels = (res['resolvedChannels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final quietHours = res['quietHoursStatus'] as Map<String, dynamic>? ?? {};
    final delivery = res['deliverySimulation'] as List<dynamic>? ?? [];

    final isQuietHoursActive = quietHours['isInQuietHours'] == true;
    final allowBypass = activeRule['allowQuietHoursBypass'] == true;
    final allowedToDispatch = quietHours['allowedToDispatch'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compliance Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: allowedToDispatch
                ? const Color(0xFF10B981).withOpacity(0.12)
                : const Color(0xFFEF4444).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: allowedToDispatch ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                allowedToDispatch ? Icons.check_circle_rounded : Icons.block_rounded,
                color: allowedToDispatch ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 20,
              ),
              const Gap(10),
              Expanded(
                child: Text(
                  allowedToDispatch
                      ? (isQuietHoursActive && allowBypass
                          ? 'DISPATCH ALLOWED (Bypasses active quiet hours due to critical priority).'
                          : 'DISPATCH ALLOWED: Standard hours transmission permitted.')
                      : 'BLOCKED: Outside operational hours (21:00-08:00) and bypass not permitted.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: allowedToDispatch ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Gap(16),

        // Resolved Channels
        const Text('Resolved Channels for Event:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const Gap(8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: resolvedChannels.map((c) {
            Color color;
            switch (c) {
              case 'WHATSAPP':
                color = const Color(0xFF25D366);
                break;
              case 'PUSH':
                color = const Color(0xFF3B82F6);
                break;
              case 'EMAIL':
                color = const Color(0xFF8B5CF6);
                break;
              default:
                color = const Color(0xFFF59E0B);
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                c,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            );
          }).toList(),
        ),
        const Gap(16),

        // Simulated Payloads
        const Text('Simulated Channel Payloads:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const Gap(8),
        ...delivery.map((d) {
          final item = Map<String, dynamic>.from(d as Map);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gateway: ${item['channel']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      'Target: ${item['target']}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const Gap(4),
                Text(
                  item['preview'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
