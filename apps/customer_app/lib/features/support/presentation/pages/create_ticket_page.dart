import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import '../providers/support_providers.dart';
import '../../../my_bookings/presentation/providers/my_bookings_providers.dart';

class CreateTicketPage extends ConsumerStatefulWidget {
  final String? initialBookingId;

  const CreateTicketPage({super.key, this.initialBookingId});

  @override
  ConsumerState<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends ConsumerState<CreateTicketPage> {
  final _formKey = GlobalKey<FormState>();
  TicketCategory _selectedCategory = TicketCategory.BOOKING;
  TicketPriority _selectedPriority = TicketPriority.NORMAL;
  String? _selectedBookingId;
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedBookingId = widget.initialBookingId;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.createTicket(
        category: _selectedCategory,
        priority: _selectedPriority,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        bookingId: _selectedBookingId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support ticket created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(myBookingsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Support Ticket'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('What can we help you with?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Gap(8),
              const Text('Choose the category that best describes your issue.', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const Gap(16),

              // Category Selector
              DropdownButtonFormField<TicketCategory>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Issue Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: TicketCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat.label),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
              ),
              const Gap(16),

              // Optional Booking Link
              bookingsAsync.when(
                data: (bookings) {
                  if (bookings.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedBookingId,
                        decoration: const InputDecoration(
                          labelText: 'Related Booking (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.directions_car_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None / General Inquiry'),
                          ),
                          ...bookings.map((b) {
                            return DropdownMenuItem(
                              value: b.id,
                              child: Text('Booking #${b.id.length > 8 ? b.id.substring(0, 8) : b.id} - ${b.status.toUpperCase()}'),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedBookingId = val;
                          });
                        },
                      ),
                      const Gap(16),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Priority Selector
              DropdownButtonFormField<TicketPriority>(
                initialValue: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Urgency / Priority',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: TicketPriority.values.map((pri) {
                  return DropdownMenuItem(
                    value: pri,
                    child: Text(pri.name),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedPriority = val;
                    });
                  }
                },
              ),
              const Gap(16),

              // Subject
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Brief summary of the issue',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a subject';
                  }
                  return null;
                },
              ),
              const Gap(16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Provide detailed information about the issue so we can help you promptly...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'Please provide at least 10 characters in description';
                  }
                  return null;
                },
              ),
              const Gap(24),

              AppButton(
                text: 'Submit Support Ticket',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
