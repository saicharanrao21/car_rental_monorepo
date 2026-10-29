import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/admin_detail_drawer.dart';

class CommunicationTemplatesPage extends ConsumerStatefulWidget {
  const CommunicationTemplatesPage({super.key});

  @override
  ConsumerState<CommunicationTemplatesPage> createState() => _CommunicationTemplatesPageState();
}

class _CommunicationTemplatesPageState extends ConsumerState<CommunicationTemplatesPage> {
  String _selectedChannel = 'ALL';
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  String _selectedLanguage = 'en';
  late Map<String, dynamic> _selectedTemplate;

  final Map<String, String> _customVariables = {
    'customerName': 'Rahul Sharma',
    'bookingId': 'BK-8921',
    'vehicleName': 'Mahindra Thar 4x4',
    'otpCode': '749210',
    'amount': '₹4,500',
    'pickupLocation': 'Indiranagar Hub, Bengaluru',
    'date': 'Today at 02:00 PM',
  };

  final List<Map<String, dynamic>> _templates = [
    {
      'id': 'tpl_booking_conf',
      'key': 'BOOKING_CONFIRMATION',
      'name': 'Booking Confirmed Instant Dispatch',
      'category': 'TRANSACTIONAL',
      'channels': ['WHATSAPP', 'SMS', 'EMAIL', 'PUSH'],
      'dltEntityId': '1101552230000014',
      'dltTemplateId': '1107161234567890123',
      'senderId': 'DRIVGO',
      'variables': ['customerName', 'vehicleName', 'bookingId', 'date', 'pickupLocation'],
      'status': 'APPROVED',
      'samples': {
        'en': 'Hello {{customerName}}, your booking for {{vehicleName}} (#{{bookingId}}) is confirmed for pickup on {{date}} at {{pickupLocation}}. Drive safe!',
        'hi': 'नमस्ते {{customerName}}, {{vehicleName}} (बुकिंग #{{bookingId}}) के लिए आपकी बुकिंग {{pickupLocation}} पर {{date}} के लिए सुनिश्चित हो गई है।',
        'te': 'నమస్కారం {{customerName}}, {{vehicleName}} కొరకు మీ బుకింగ్ (#{{bookingId}}) {{pickupLocation}} వద్ద {{date}} కు నిర్ధారించబడింది.',
        'kn': 'ನಮಸ್ಕಾರ {{customerName}}, ನಿಮ್ಮ {{vehicleName}} ಬುಕಿಂಗ್ (#{{bookingId}}) {{date}} ಕ್ಕೆ {{pickupLocation}} ನಲ್ಲಿ ದೃಢೀಕರಿಸಲಾಗಿದೆ.',
        'ta': 'வணக்கம் {{customerName}}, {{vehicleName}} க்கான உங்கள் முன்பதிவு (#{{bookingId}}) {{date}} அன்று {{pickupLocation}} இல் உறுதி செய்யப்பட்டது.',
      },
    },
    {
      'id': 'tpl_handover_otp',
      'key': 'HANDOVER_INSPECTION_OTP',
      'name': 'Vehicle Handover Customer Verification OTP',
      'category': 'SECURITY_OTP',
      'channels': ['WHATSAPP', 'SMS'],
      'dltEntityId': '1101552230000014',
      'dltTemplateId': '1107161234567890124',
      'senderId': 'DRIVGO',
      'variables': ['otpCode', 'vehicleName', 'bookingId'],
      'status': 'APPROVED',
      'samples': {
        'en': '{{otpCode}} is your DriveGo handover verification code for {{vehicleName}} (#{{bookingId}}). Valid for 10 minutes. Share only with your vendor host.',
        'hi': '{{otpCode}} आपका DriveGo वाहन हैंडओवर सत्यापन कोड है {{vehicleName}} (#{{bookingId}}) के लिए। केवल अपने वेंडर को दें।',
        'te': '{{otpCode}} మీ DriveGo వాహనం హ్యాండోవర్ ధృవీకరణ కోడ్ {{vehicleName}} (#{{bookingId}}). మీ వెండర్‌కు మాత్రమే చెప్పండి.',
        'kn': '{{otpCode}} ನಿಮ್ಮ DriveGo ಹಸ್ತಾಂತರ ಕೋಡ್ ಆಗಿದೆ. ನಿಮ್ಮ ವಾಹನ ನೀಡುವ ವ್ಯಕ್ತಿಗೆ ಮಾತ್ರ ಹಂಚಿಕೊಳ್ಳಿ.',
        'ta': '{{otpCode}} உங்கள் DriveGo வாகன ஒப்படைப்பு சரிபார்ப்பு குறியீடு. உங்கள் விற்பனையாளரிடம் மட்டுமே பகிரவும்.',
      },
    },
    {
      'id': 'tpl_deposit_released',
      'key': 'SECURITY_DEPOSIT_RELEASED',
      'name': 'Security Deposit Released to Source',
      'category': 'FINANCIAL',
      'channels': ['WHATSAPP', 'SMS', 'EMAIL', 'PUSH'],
      'dltEntityId': '1101552230000014',
      'dltTemplateId': '1107161234567890125',
      'senderId': 'DRIVGO',
      'variables': ['customerName', 'amount', 'bookingId'],
      'status': 'APPROVED',
      'samples': {
        'en': 'Hello {{customerName}}, your security deposit of {{amount}} for booking #{{bookingId}} has been successfully released back to your payment source.',
        'hi': 'नमस्ते {{customerName}}, बुकिंग #{{bookingId}} के लिए आपकी {{amount}} की सुरक्षा जमा राशि आपके खाते में वापस जारी कर दी गई है।',
        'te': 'నమస్కారం {{customerName}}, బుకింగ్ #{{bookingId}} కొరకు మీ సెక్యూరిటీ డిపాజిట్ {{amount}} మీ బ్యాంక్ ఖాతాకు విజయవంతంగా విడుదల చేయబడింది.',
        'kn': 'ನಮಸ್ಕಾರ {{customerName}}, ನಿಮ್ಮ ಭದ್ರತಾ ಠೇವಣಿ {{amount}} ಅನ್ನು ನಿಮ್ಮ ಖಾತೆಗೆ ಹಿಂತಿರುಗಿಸಲಾಗಿದೆ.',
        'ta': 'வணக்கம் {{customerName}}, உங்கள் பாதுகாப்பு வைப்புத்தொகை {{amount}} உங்கள் கணக்கில் திரும்ப செலுத்தப்பட்டது.',
      },
    },
    {
      'id': 'tpl_sos_emergency',
      'key': 'SOS_EMERGENCY_TRIGGERED',
      'name': 'SOS Emergency Dispatch Alert',
      'category': 'OPERATIONAL',
      'channels': ['SMS', 'WHATSAPP', 'PUSH', 'VOICE'],
      'dltEntityId': '1101552230000014',
      'dltTemplateId': '1107161234567890126',
      'senderId': 'DRIVGO',
      'variables': ['customerName', 'bookingId', 'pickupLocation'],
      'status': 'APPROVED',
      'samples': {
        'en': 'CRITICAL ALERT: SOS triggered for booking #{{bookingId}} (User: {{customerName}}) at {{pickupLocation}}. DriveGo rapid dispatch team is responding.',
        'hi': 'आपातकालीन चेतावनी: बुकिंग #{{bookingId}} (उपयोगकर्ता: {{customerName}}) के लिए SOS संकेत मिला है। बचाव दल तुरंत संपर्क कर रहा है।',
        'te': 'అత్యవసర హెచ్చరిక: బుకింగ్ #{{bookingId}} వద్ద SOS ప్రారంభించబడింది. సహాయక బృందం స్పందిస్తోంది.',
        'kn': 'ತುರ್ತು ಎಚ್ಚರಿಕೆ: ಬುಕಿಂಗ್ #{{bookingId}} ಗಾಗಿ SOS ಟ್ರಿಗರ್ ಆಗಿದೆ. ರಕ್ಷಣಾ ತಂಡವು ಕಾರ್ಯಪ್ರವೃತ್ತವಾಗಿದೆ.',
        'ta': 'அவசர எச்சரிக்கை: முன்பதிவு #{{bookingId}} க்கான SOS தூண்டப்பட்டது. பாதுகாப்பு குழு செயல்படுகிறது.',
      },
    },
    {
      'id': 'tpl_marketing_weekend',
      'key': 'MARKETING_WEEKEND_ESCAPE',
      'name': 'Weekend Road Trip Promotional Discount',
      'category': 'MARKETING',
      'channels': ['WHATSAPP', 'PUSH', 'EMAIL'],
      'dltEntityId': '1101552230000014',
      'dltTemplateId': '1107161234567890127',
      'senderId': 'DRIVGO',
      'variables': ['customerName', 'amount'],
      'status': 'APPROVED',
      'samples': {
        'en': 'Ready for the weekend, {{customerName}}? Get {{amount}} OFF your next self-drive trip across Bangalore and Hyderabad. Code: WEEKEND20.',
        'hi': 'सप्ताहांत की तैयारी, {{customerName}}? अपनी अगली ड्राइव पर {{amount}} की छूट पाएं। कोड: WEEKEND20 उपयोग करें।',
        'te': 'వీకెండ్ ట్రిప్ సిద్ధమా, {{customerName}}? మీ తదుపరి డ్రైవ్‌పై {{amount}} తగ్గింపు పొందండి. కోడ్: WEEKEND20.',
        'kn': 'ವಾರಾಂತ್ಯಕ್ಕೆ ಸಿದ್ಧರೇ, {{customerName}}? ನಿಮ್ಮ ಮುಂದಿನ ಟ್ರಿಪ್ ಮೇಲೆ {{amount}} ರಿಯಾಯಿತಿ ಪಡೆಯಿರಿ.',
        'ta': 'வார இறுதி பயணத்திற்கு தயாரா, {{customerName}}? உங்கள் அடுத்த பயணத்தில் {{amount}} தள்ளுபடி பெறுங்கள்.',
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedTemplate = _templates.first;
  }

  bool _hasUnresolvedVariables(String text) {
    return RegExp(r'\{\{[a-zA-Z0-9_]+\}\}').hasMatch(text);
  }

  String _interpolate(String raw) {
    var result = raw;
    _customVariables.forEach((k, v) {
      result = result.replaceAll('{{$k}}', v.trim().isEmpty ? '[$k: EMPTY]' : v);
    });
    return result;
  }

  void _showCreateTemplateDrawer() {
    final keyCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final dltIdCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String category = 'TRANSACTIONAL';
    final Set<String> channels = {'WHATSAPP', 'SMS'};

    AdminDetailDrawer.show(
      context: context,
      title: 'Register Canonical Message Template',
      subtitle: 'Complies with TRAI DLT, Meta Cloud API, and FCM specifications',
      width: 520,
      child: StatefulBuilder(
        builder: (ctx, setDrawerState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: keyCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Canonical Template Key *',
                hintText: 'e.g. RETURN_INSPECTION_CONFIRMED',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Friendly Display Name *',
                hintText: 'e.g. Return Inspection Customer Summary',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(
                labelText: 'Category *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'TRANSACTIONAL', child: Text('Transactional (Service Updates)')),
                DropdownMenuItem(value: 'SECURITY_OTP', child: Text('Security & Verification OTP')),
                DropdownMenuItem(value: 'FINANCIAL', child: Text('Financial & Invoices')),
                DropdownMenuItem(value: 'OPERATIONAL', child: Text('Operational & Critical SOS')),
                DropdownMenuItem(value: 'MARKETING', child: Text('Promotional & Marketing')),
              ],
              onChanged: (val) => setDrawerState(() => category = val ?? 'TRANSACTIONAL'),
            ),
            const Gap(12),
            const Text('Supported Channels:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Gap(6),
            Wrap(
              spacing: 8,
              children: ['WHATSAPP', 'SMS', 'EMAIL', 'PUSH', 'VOICE'].map((ch) {
                final isSelected = channels.contains(ch);
                return FilterChip(
                  label: Text(ch),
                  selected: isSelected,
                  onSelected: (selected) {
                    setDrawerState(() {
                      if (selected) {
                        channels.add(ch);
                      } else {
                        channels.remove(ch);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const Gap(12),
            TextField(
              controller: dltIdCtrl,
              decoration: const InputDecoration(
                labelText: 'TRAI DLT Template ID (for India SMS/WhatsApp)',
                hintText: '1107161234567890...',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'English Template Content with {{tokens}} *',
                hintText: 'Hello {{customerName}}, your vehicle handover is complete...',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(24),
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Save & Submit for DLT Registration'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                if (keyCtrl.text.isEmpty || bodyCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter template key and body.')),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                setState(() {
                  _templates.insert(0, {
                    'id': 'tpl_${DateTime.now().millisecondsSinceEpoch}',
                    'key': keyCtrl.text.trim().toUpperCase(),
                    'name': nameCtrl.text.trim().isEmpty ? keyCtrl.text.trim() : nameCtrl.text.trim(),
                    'category': category,
                    'channels': channels.toList(),
                    'dltEntityId': '1101552230000014',
                    'dltTemplateId': dltIdCtrl.text.trim().isEmpty ? 'DLT-PENDING' : dltIdCtrl.text.trim(),
                    'senderId': 'DRIVGO',
                    'variables': ['customerName', 'bookingId'],
                    'status': 'PENDING_DLT',
                    'samples': {
                      'en': bodyCtrl.text.trim(),
                      'hi': bodyCtrl.text.trim(),
                    },
                  });
                  _selectedTemplate = _templates.first;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Template submitted and registered successfully!'), backgroundColor: Colors.green),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = _templates.where((t) {
      if (_selectedChannel != 'ALL' && !(t['channels'] as List).contains(_selectedChannel)) return false;
      if (_selectedCategory != 'ALL' && t['category'] != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (t['name'] as String).toLowerCase();
        final key = (t['key'] as String).toLowerCase();
        if (!name.contains(q) && !key.contains(q)) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Unified Message Templates Studio',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: const Text(
                            'DLT & META REGISTRY SYNCED',
                            style: TextStyle(
                              color: Color(0xFF4338CA),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      'Authoritative multi-language templates across SMS (DLT Header: DRIVGO), WhatsApp Cloud API, Email, and Push Notifications.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.hub_outlined, size: 16),
                      label: const Text('Communications Overview'),
                      onPressed: () => context.go('/communications'),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Template'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onPressed: _showCreateTemplateDrawer,
                    ),
                  ],
                ),
              ],
            ),
            const Gap(20),

            // Filter & Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search templates by key or name...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const Gap(16),
                  DropdownButton<String>(
                    value: _selectedChannel,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Channels')),
                      DropdownMenuItem(value: 'WHATSAPP', child: Text('WhatsApp')),
                      DropdownMenuItem(value: 'SMS', child: Text('SMS (DLT)')),
                      DropdownMenuItem(value: 'EMAIL', child: Text('Email')),
                      DropdownMenuItem(value: 'PUSH', child: Text('Mobile Push')),
                    ],
                    onChanged: (val) => setState(() => _selectedChannel = val ?? 'ALL'),
                  ),
                  const Gap(16),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
                      DropdownMenuItem(value: 'TRANSACTIONAL', child: Text('Transactional')),
                      DropdownMenuItem(value: 'SECURITY_OTP', child: Text('Security OTP')),
                      DropdownMenuItem(value: 'FINANCIAL', child: Text('Financial')),
                      DropdownMenuItem(value: 'OPERATIONAL', child: Text('Operational SOS')),
                      DropdownMenuItem(value: 'MARKETING', child: Text('Marketing')),
                    ],
                    onChanged: (val) => setState(() => _selectedCategory = val ?? 'ALL'),
                  ),
                ],
              ),
            ),
            const Gap(20),

            // Two-Pane Explorer: Left = Template List, Right = Live Simulator & Interpolation
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Pane: Templates List
                  Expanded(
                    flex: 3,
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      elevation: 0,
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isSelected = item['id'] == _selectedTemplate['id'];

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Row(
                              children: [
                                Text(
                                  item['key'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item['status'] == 'APPROVED' ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item['status'] as String,
                                    style: TextStyle(
                                      color: item['status'] == 'APPROVED' ? const Color(0xFF065F46) : const Color(0xFF92400E),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Gap(4),
                                Text(
                                  item['name'] as String,
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                ),
                                const Gap(8),
                                Wrap(
                                  spacing: 6,
                                  children: (item['channels'] as List<String>).map((ch) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        ch,
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                _selectedTemplate = item;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const Gap(20),

                  // Right Pane: Live Device Simulator & Dynamic Variable Sandbox
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Compliance Card
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedTemplate['name'] as String,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownButton<String>(
                                        value: _selectedLanguage,
                                        underline: const SizedBox.shrink(),
                                        items: const [
                                          DropdownMenuItem(value: 'en', child: Text('English (en)')),
                                          DropdownMenuItem(value: 'hi', child: Text('Hindi (hi)')),
                                          DropdownMenuItem(value: 'te', child: Text('Telugu (te)')),
                                          DropdownMenuItem(value: 'kn', child: Text('Kannada (kn)')),
                                          DropdownMenuItem(value: 'ta', child: Text('Tamil (ta)')),
                                        ],
                                        onChanged: (val) => setState(() => _selectedLanguage = val ?? 'en'),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    children: [
                                      _buildMetaItem('DLT Template ID', _selectedTemplate['dltTemplateId'] ?? 'NA'),
                                      const Gap(24),
                                      _buildMetaItem('Sender Header', _selectedTemplate['senderId'] ?? 'DRIVGO'),
                                      const Gap(24),
                                      _buildMetaItem('Category', _selectedTemplate['category'] as String),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Gap(16),

                          // Device Bubble Simulator Preview
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5DDD5), // WhatsApp / Chat Canvas
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF1E293B), size: 16),
                                    Gap(8),
                                    Text(
                                      'Device Message Bubble Preview',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13),
                                    ),
                                  ],
                                ),
                                const Gap(14),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                  Builder(builder: (context) {
                                    final interpolated = _interpolate(
                                        (_selectedTemplate['samples'] as Map<String, dynamic>)[_selectedLanguage] ??
                                            (_selectedTemplate['samples'] as Map<String, dynamic>)['en'] as String);
                                    final hasUnresolved = _hasUnresolvedVariables(interpolated);

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (hasUnresolved) ...[
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF2F2),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFFECACA)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                                                Gap(4),
                                                Text(
                                                  'Unresolved template variables detected',
                                                  style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        Text(
                                          interpolated,
                                          style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF0F172A)),
                                        ),
                                      ],
                                    );
                                  }),
                                      const Gap(10),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '10:45 AM',
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                            ),
                                            const Gap(4),
                                            const Icon(Icons.done_all, size: 14, color: Colors.blueAccent),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(16),

                          // Variable Value Sandbox
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Interpolation Sandbox Variables',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const Gap(4),
                                  Text(
                                    'Edit test tokens below to verify dynamic variable interpolation across localized copies.',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                  const Gap(12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: _customVariables.keys.map((k) {
                                      return SizedBox(
                                        width: 190,
                                        child: TextField(
                                          controller: TextEditingController(text: _customVariables[k])
                                            ..selection = TextSelection.collapsed(offset: _customVariables[k]!.length),
                                          decoration: InputDecoration(
                                            labelText: '{{$k}}',
                                            isDense: true,
                                            border: const OutlineInputBorder(),
                                          ),
                                          onChanged: (v) {
                                            setState(() {
                                              _customVariables[k] = v;
                                            });
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const Gap(2),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }
}
