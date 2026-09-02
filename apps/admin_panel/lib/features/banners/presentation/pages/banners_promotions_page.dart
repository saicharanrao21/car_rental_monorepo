import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:models/models.dart';
import 'package:core/core.dart';
import 'package:gap/gap.dart';
import '../../../../core/widgets/admin_detail_drawer.dart';
import '../providers/admin_banners_providers.dart';

class BannersPromotionsPage extends ConsumerWidget {
  const BannersPromotionsPage({super.key});

  void _showBannerForm(BuildContext context, WidgetRef ref, [BannerModel? banner]) {
    AdminDetailDrawer.show(
      context: context,
      title: banner == null ? 'Add Promotional Banner' : 'Edit Promotional Banner',
      subtitle: banner != null ? 'Banner ID: #${banner.id.toUpperCase()}' : 'Configure promotional campaign banner',
      width: 480,
      child: _BannerFormModal(
        bannerToEdit: banner,
        onSave: ({required String title, required String ctaLink, required String imageUrl}) {
          if (banner == null) {
            final newBanner = BannerModel(
              id: 'banner_${DateTime.now().millisecondsSinceEpoch}',
              title: title,
              ctaLink: ctaLink,
              imageUrl: imageUrl,
              displayOrder: 99, // Will be placed at the end
              isActive: true,
            );
            ref.read(adminBannersProvider.notifier).addBanner(newBanner);
          } else {
            final updated = banner.copyWith(
              title: title,
              ctaLink: ctaLink,
              imageUrl: imageUrl,
            );
            ref.read(adminBannersProvider.notifier).updateBanner(updated);
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _confirmDeleteBanner(BuildContext context, WidgetRef ref, BannerModel banner) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Promotional Banner'),
          content: Text('Are you sure you want to delete the banner "${banner.title}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                ref.read(adminBannersProvider.notifier).deleteBanner(banner.id);
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(adminBannersProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Banners & Promotions',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Gap(4),
                    Text(
                      'Manage, reorder, and configure customer app promo banners.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                AppButton(
                  text: 'Add Promo Banner',
                  isFullWidth: false,
                  onPressed: () => _showBannerForm(context, ref),
                ),
              ],
            ),
            const Gap(24),

            // Banner Reorder instructions alert
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  Gap(12),
                  Expanded(
                    child: Text(
                      'Drag and drop the handles (☰) on the left side of any banner to reorder how they appear in the customer mobile app.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(20),

            Expanded(
              child: bannersAsync.when(
                loading: () => const Center(child: AppLoader()),
                error: (err, _) => ErrorStateWidget(
                  message: 'Error loading promotional banners',
                  onRetry: () => ref.invalidate(adminBannersProvider),
                ),
                data: (banners) {
                  if (banners.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.photo_library_outlined,
                      title: 'No Banners Configured',
                      subtitle: 'Add a banner to display promotion campaigns to customers.',
                      actionText: 'Add Banner',
                      onActionPressed: () => _showBannerForm(context, ref),
                    );
                  }

                  return ReorderableListView.builder(
                    itemCount: banners.length,
                    buildDefaultDragHandles: false,
                    // ignore: deprecated_member_use
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final list = List<BannerModel>.from(banners);
                      final item = list.removeAt(oldIndex);
                      list.insert(newIndex, item);
                      final orderedIds = list.map((b) => b.id).toList();
                      ref.read(adminBannersProvider.notifier).reorderBanners(orderedIds);
                    },
                    itemBuilder: (context, idx) {
                      final item = banners[idx];
                      return Card(
                        key: ValueKey(item.id),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              // Drag Handle
                              ReorderableDragStartListener(
                                index: idx,
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.menu, color: Colors.grey),
                                ),
                              ),
                              const Gap(12),

                              // Banner Image Preview
                              Container(
                                width: 90,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    item.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.image, color: Colors.grey, size: 24),
                                    ),
                                  ),
                                ),
                              ),
                              const Gap(16),

                              // Banner details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const Gap(4),
                                    Text(
                                      'Target CTA: ${item.ctaLink}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),

                              // Actions (Switch + Edit + Delete)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: item.isActive ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                  const Gap(4),
                                  Switch(
                                    value: item.isActive,
                                    activeThumbColor: AppColors.primary,
                                    onChanged: (val) {
                                      ref.read(adminBannersProvider.notifier).toggleActive(item.id, val);
                                    },
                                  ),
                                  const Gap(12),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                    tooltip: 'Edit Banner',
                                    onPressed: () => _showBannerForm(context, ref, item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    tooltip: 'Delete Banner',
                                    onPressed: () => _confirmDeleteBanner(context, ref, item),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerFormModal extends StatefulWidget {
  final BannerModel? bannerToEdit;
  final Function({required String title, required String ctaLink, required String imageUrl}) onSave;

  const _BannerFormModal({this.bannerToEdit, required this.onSave});

  @override
  State<_BannerFormModal> createState() => _BannerFormModalState();
}

class _BannerFormModalState extends State<_BannerFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _ctaController;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.bannerToEdit?.title ?? '');
    _ctaController = TextEditingController(text: widget.bannerToEdit?.ctaLink ?? '');
    _imageUrl = widget.bannerToEdit?.imageUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ctaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Banner Image (Click to Upload)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const Gap(8),
          InkWell(
            onTap: () {
              setState(() {
                _imageUrl = 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=600&q=80';
              });
            },
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _imageUrl != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _imageUrl!,
                            width: double.infinity,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 16),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Tap to replace image',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 36, color: Colors.grey),
                        Gap(8),
                        Text('Click to select promo image', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
            ),
          ),
          const Gap(16),

          AppTextField(
            label: 'Banner Title',
            controller: _titleController,
            hint: 'e.g. Super Summer Offer',
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Title is required';
              }
              return null;
            },
          ),
          const Gap(16),

          AppTextField(
            label: 'CTA Link (Route URI)',
            controller: _ctaController,
            hint: 'e.g. /search?category=Luxury',
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'CTA Link is required';
              }
              return null;
            },
          ),
          const Gap(24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const Gap(16),
              Expanded(
                child: AppButton(
                  text: widget.bannerToEdit == null ? 'Create Banner' : 'Save Changes',
                  onPressed: () {
                    if (_imageUrl == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please upload a banner image')),
                      );
                      return;
                    }
                    if (_formKey.currentState!.validate()) {
                      widget.onSave(
                        title: _titleController.text,
                        ctaLink: _ctaController.text,
                        imageUrl: _imageUrl!,
                      );
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
