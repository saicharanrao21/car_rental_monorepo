import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../domain/repositories/admin_notifications_repository.dart';
import '../providers/admin_notifications_providers.dart';

class PushNotificationsPage extends ConsumerStatefulWidget {
  const PushNotificationsPage({super.key});

  @override
  ConsumerState<PushNotificationsPage> createState() => _PushNotificationsPageState();
}

class _PushNotificationsPageState extends ConsumerState<PushNotificationsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _phoneController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _phoneController = TextEditingController();

    _titleController.addListener(() {
      ref.read(notificationTitleProvider.notifier).state = _titleController.text;
    });
    _bodyController.addListener(() {
      ref.read(notificationBodyProvider.notifier).state = _bodyController.text;
    });
    _phoneController.addListener(() {
      ref.read(notificationPhoneProvider.notifier).state = _phoneController.text;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _titleController.clear();
    _bodyController.clear();
    _phoneController.clear();
    ref.read(notificationTargetProvider.notifier).state = 'All Users';
    ref.read(notificationCityProvider.notifier).state = 'Mumbai';
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;

    final targetType = ref.read(notificationTargetProvider);
    final city = ref.read(notificationCityProvider);
    final phone = ref.read(notificationPhoneProvider);
    final title = ref.read(notificationTitleProvider);
    final body = ref.read(notificationBodyProvider);

    String target = 'ALL_USERS';
    if (targetType == 'All Vendors') {
      target = 'ALL_VENDORS';
    } else if (targetType == 'Specific City') {
      target = 'CITY:$city';
    } else if (targetType == 'Specific User by phone') {
      target = 'USER:$phone';
    }

    setState(() {
      _isSending = true;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(sentNotificationsProvider.notifier).sendNotification(
            target: target,
            title: title,
            body: body,
          );

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Push notification sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
      }
    } catch (err) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $err'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetType = ref.watch(notificationTargetProvider);
    final historyAsync = ref.watch(sentNotificationsProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push Notifications',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Gap(4),
                Text(
                  'Compose and broadcast messages to users, vendors, or specific segments.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const Gap(24),
            Expanded(
              child: Responsive.isDesktop(context)
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildComposeCard(context, targetType),
                                const Gap(24),
                                _buildPreviewCard(context),
                              ],
                            ),
                          ),
                        ),
                        const Gap(24),
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            child: _buildHistoryCard(context, historyAsync),
                          ),
                        ),
                      ],
                    )
                  : _buildVerticalLayout(context, historyAsync, targetType),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalLayout(
    BuildContext context,
    AsyncValue<List<SentNotification>> historyAsync,
    String targetType,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildComposeCard(context, targetType),
          const Gap(24),
          _buildPreviewCard(context),
          const Gap(24),
          _buildHistoryCard(context, historyAsync),
        ],
      ),
    );
  }

  Widget _buildComposeCard(BuildContext context, String targetType) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Compose Notification',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Gap(20),

            // Target dropdown
            AppDropdown<String>(
              label: 'Target Group',
              value: targetType,
              items: const [
                DropdownMenuItem(value: 'All Users', child: Text('All Users')),
                DropdownMenuItem(value: 'All Vendors', child: Text('All Vendors')),
                DropdownMenuItem(value: 'Specific City', child: Text('Specific City')),
                DropdownMenuItem(value: 'Specific User by phone', child: Text('Specific User (Phone)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(notificationTargetProvider.notifier).state = val;
                }
              },
            ),
            const Gap(16),

            // Specific City reveal
            if (targetType == 'Specific City') ...[
              AppDropdown<String>(
                label: 'Select City',
                value: ref.watch(notificationCityProvider),
                items: AppConstants.indianCities.map((city) {
                  return DropdownMenuItem(value: city, child: Text(city));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(notificationCityProvider.notifier).state = val;
                  }
                },
              ),
              const Gap(16),
            ],

            // Specific User Phone reveal
            if (targetType == 'Specific User by phone') ...[
              AppTextField(
                label: 'Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                hint: 'e.g. 9876543210',
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Phone number is required';
                  }
                  if (val.length < 10) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const Gap(16),
            ],

            // Title
            AppTextField(
              label: 'Notification Title',
              controller: _titleController,
              hint: 'e.g. Special Discount Alert!',
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const Gap(16),

            // Body (multilineFormField)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notification Message Body',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bodyController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Type message body here...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Body is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const Gap(24),

            _isSending
                ? const Center(child: AppLoader())
                : AppButton(
                    text: 'Send Notification',
                    onPressed: _handleSend,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    final title = ref.watch(notificationTitleProvider);
    final body = ref.watch(notificationBodyProvider);
    final target = ref.watch(notificationTargetProvider);
    final city = ref.watch(notificationCityProvider);
    final phone = ref.watch(notificationPhoneProvider);

    String targetLabel = target;
    if (target == 'Specific City') {
      targetLabel = 'Users in $city';
    } else if (target == 'Specific User by phone') {
      targetLabel = 'User ($phone)';
    }

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Preview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Gap(4),
          Text(
            'Target audience: $targetLabel',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const Gap(16),

          // Notification Bubble Mock (iOS / Android hybrid card style)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title.isEmpty ? 'Notification Title' : title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'now',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const Gap(4),
                      Text(
                        body.isEmpty ? 'Type message body in the form above to preview it live.' : body,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, AsyncValue<List<SentNotification>> historyAsync) {
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sent Notification History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Gap(16),
          SizedBox(
            height: 440,
            child: historyAsync.when(
              loading: () => const Center(child: AppLoader()),
              error: (err, _) => ErrorStateWidget(
                message: 'Error loading sent history',
                onRetry: () => ref.invalidate(sentNotificationsProvider),
              ),
              data: (history) {
                if (history.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.notifications_off_outlined,
                    title: 'No Notification History',
                    subtitle: 'Notifications sent by administrators will show up here.',
                  );
                }

                return Scrollbar(
                  child: ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, idx) {
                      final item = history[idx];
                      final formattedDate = DateFormat('dd MMM, hh:mm a').format(item.sentAt);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_outlined, size: 16, color: Colors.grey),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Gap(2),
                            Text(item.body, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                            const Gap(4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Target: ${item.target}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  formattedDate,
                                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
