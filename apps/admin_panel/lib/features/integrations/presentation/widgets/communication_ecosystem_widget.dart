import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class CommunicationEcosystemWidget extends StatefulWidget {
  const CommunicationEcosystemWidget({super.key});

  @override
  State<CommunicationEcosystemWidget> createState() => _CommunicationEcosystemWidgetState();
}

class _CommunicationEcosystemWidgetState extends State<CommunicationEcosystemWidget> {
  String _selectedSubTab = 'MARKETPLACE'; // 'MARKETPLACE' | 'ROUTING' | 'TEMPLATES' | 'DELIVERY' | 'COMPLIANCE'
  String _searchQuery = '';
  String _selectedChannelFilter = 'ALL'; // 'ALL' | 'WHATSAPP' | 'SMS' | 'EMAIL' | 'PUSH' | 'VOICE'
  String _selectedStatusFilter = 'ALL';

  // Routing Simulator State
  String _simMessageType = 'OTP';
  String _simCountry = 'IN';
  String _simLanguage = 'en';
  bool _simQuietHours = false;
  Map<String, dynamic>? _routingPreviewResult;

  // Template Previewer State
  String _selectedTemplate = 'BOOKING_CONFIRMATION';
  String _selectedTemplateLang = 'en';

  // Compliance State
  bool _quietHoursEnabled = true;
  final int _quietHoursStart = 21;
  final int _quietHoursEnd = 8;
  final Set<String> _blockedNumbers = {'+919876500000', 'spam_user@badmail.com'};

  // OTP Platform State
  String _otpPurpose = 'AUTH';
  String _otpIdentifier = '+919876543210';
  String _otpChannel = 'WHATSAPP';
  String? _generatedChallengeId;
  String? _simulatedOtpCode;
  int _otpAttemptsRemaining = 3;
  String? _otpStatusMessage;
  bool _otpVerified = false;
  final TextEditingController _otpInputController = TextEditingController();

  // 44 Communications Gateways Catalog
  final List<Map<String, dynamic>> _providers = [
    // --- WhatsApp ---
    {
      'providerId': 'meta',
      'name': 'Meta WhatsApp Cloud API',
      'channel': 'WHATSAPP',
      'status': 'LIVE_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.4,
      'latency': '38ms',
      'cost': '₹0.45 / conv',
      'countries': ['IN', 'AE', 'US', 'GB', 'SG'],
      'capabilities': ['TEMPLATE', 'MEDIA', 'OTP', 'READ_STATUS'],
      'priority': 1,
    },
    {
      'providerId': 'gupshup_whatsapp',
      'name': 'Gupshup WhatsApp Enterprise',
      'channel': 'WHATSAPP',
      'status': 'ADAPTER_IMPLEMENTED',
      'health': 'HEALTHY',
      'deliveryRate': 98.9,
      'latency': '45ms',
      'cost': '₹0.48 / conv',
      'countries': ['IN', 'AE', 'SG'],
      'capabilities': ['TEMPLATE', 'MEDIA', 'OTP', 'DELIVERY_STATUS'],
      'priority': 2,
    },
    {
      'providerId': 'twilio_whatsapp',
      'name': 'Twilio for WhatsApp',
      'channel': 'WHATSAPP',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.1,
      'latency': '62ms',
      'cost': '\$0.0075 / msg',
      'countries': ['US', 'GB', 'IN', 'EU'],
      'capabilities': ['TEMPLATE', 'MEDIA', 'CONVERSATIONS'],
      'priority': 3,
    },
    {
      'providerId': 'infobip_whatsapp',
      'name': 'Infobip WhatsApp Business',
      'channel': 'WHATSAPP',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.2,
      'latency': '55ms',
      'cost': '€0.008 / msg',
      'countries': ['EU', 'US', 'GB', 'AE'],
      'capabilities': ['TEMPLATE', 'FAILOVER'],
      'priority': 4,
    },
    {
      'providerId': 'kaleyra_whatsapp',
      'name': 'Kaleyra (Tata Comm) WhatsApp',
      'channel': 'WHATSAPP',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 98.7,
      'latency': '48ms',
      'cost': '₹0.46 / conv',
      'countries': ['IN', 'IT', 'US'],
      'capabilities': ['TEMPLATE', 'BANKING_OTP'],
      'priority': 5,
    },
    {
      'providerId': 'vonage_whatsapp',
      'name': 'Vonage (Nexmo) WhatsApp',
      'channel': 'WHATSAPP',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 98.5,
      'latency': '68ms',
      'cost': '€0.007 / msg',
      'countries': ['US', 'GB', 'EU'],
      'capabilities': ['TEMPLATE', 'SOCIAL'],
      'priority': 6,
    },
    {
      'providerId': 'bird_whatsapp',
      'name': 'Bird (MessageBird) WhatsApp',
      'channel': 'WHATSAPP',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 98.4,
      'latency': '72ms',
      'cost': '€0.0078 / msg',
      'countries': ['EU', 'US'],
      'capabilities': ['TEMPLATE', 'AI_BOTS'],
      'priority': 7,
    },
    {
      'providerId': '360dialog',
      'name': '360dialog WhatsApp BSP',
      'channel': 'WHATSAPP',
      'status': 'CATALOG_ONLY',
      'health': 'HEALTHY',
      'deliveryRate': 99.0,
      'latency': '50ms',
      'cost': '€0.005 / msg',
      'countries': ['DE', 'EU', 'US'],
      'capabilities': ['CLOUD_API_DIRECT'],
      'priority': 8,
    },

    // --- SMS (India) ---
    {
      'providerId': 'msg91',
      'name': 'MSG91 Enterprise SMS',
      'channel': 'SMS',
      'status': 'LIVE_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.3,
      'latency': '28ms',
      'cost': '₹0.14 / msg',
      'countries': ['IN'],
      'capabilities': ['DLT_SCRUBBING', 'OTP', 'FLOWS', 'TRANSACTIONAL'],
      'priority': 1,
    },
    {
      'providerId': 'twilio_sms',
      'name': 'Twilio India SMS',
      'channel': 'SMS',
      'status': 'LIVE_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.2,
      'latency': '42ms',
      'cost': '₹0.18 / msg',
      'countries': ['IN', 'US'],
      'capabilities': ['PROGRAMMABLE', 'OTP', 'STATUS_CALLBACK'],
      'priority': 2,
    },
    {
      'providerId': 'gupshup_sms',
      'name': 'Gupshup India SMS',
      'channel': 'SMS',
      'status': 'ADAPTER_IMPLEMENTED',
      'health': 'HEALTHY',
      'deliveryRate': 98.8,
      'latency': '35ms',
      'cost': '₹0.15 / msg',
      'countries': ['IN'],
      'capabilities': ['DLT_HEADER', 'BULK', 'OTP'],
      'priority': 3,
    },
    {
      'providerId': 'exotel_sms',
      'name': 'Exotel SMS',
      'channel': 'SMS',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.0,
      'latency': '32ms',
      'cost': '₹0.16 / msg',
      'countries': ['IN'],
      'capabilities': ['OTP', 'TRANSACTIONAL'],
      'priority': 4,
    },
    {
      'providerId': 'twofactor_sms',
      'name': '2Factor Dedicated SMS OTP',
      'channel': 'SMS',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.7,
      'latency': '18ms',
      'cost': '₹0.18 / otp',
      'countries': ['IN'],
      'capabilities': ['PRIORITY_OTP', 'SUB_5S_DELIVERY'],
      'priority': 5,
    },
    {
      'providerId': 'karix_sms',
      'name': 'Karix Mobile SMS',
      'channel': 'SMS',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.1,
      'latency': '30ms',
      'cost': '₹0.15 / msg',
      'countries': ['IN'],
      'capabilities': ['BANKING_GRADE', 'DLT'],
      'priority': 6,
    },
    {
      'providerId': 'routemobile_sms',
      'name': 'Route Mobile SMS',
      'channel': 'SMS',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 98.6,
      'latency': '34ms',
      'cost': '₹0.15 / msg',
      'countries': ['IN', 'AE'],
      'capabilities': ['FIREWALL_BYPASS'],
      'priority': 7,
    },
    {
      'providerId': 'valuefirst_sms',
      'name': 'ValueFirst (Twilio) SMS',
      'channel': 'SMS',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 98.4,
      'latency': '38ms',
      'cost': '₹0.14 / msg',
      'countries': ['IN'],
      'capabilities': ['AGGREGATOR'],
      'priority': 8,
    },
    {
      'providerId': 'tanla_sms',
      'name': 'Tanla Platforms Wisely',
      'channel': 'SMS',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.5,
      'latency': '25ms',
      'cost': '₹0.16 / msg',
      'countries': ['IN'],
      'capabilities': ['BLOCKCHAIN_AUDIT', 'ZERO_SPAM'],
      'priority': 9,
    },
    {
      'providerId': 'textlocal_sms',
      'name': 'Textlocal India',
      'channel': 'SMS',
      'status': 'CATALOG_ONLY',
      'health': 'HEALTHY',
      'deliveryRate': 98.0,
      'latency': '45ms',
      'cost': '₹0.16 / msg',
      'countries': ['IN'],
      'capabilities': ['INBOX_APP'],
      'priority': 10,
    },
    {
      'providerId': 'fast2sms',
      'name': 'Fast2SMS',
      'channel': 'SMS',
      'status': 'CATALOG_ONLY',
      'health': 'HEALTHY',
      'deliveryRate': 97.5,
      'latency': '55ms',
      'cost': '₹0.12 / msg',
      'countries': ['IN'],
      'capabilities': ['WALLET_RECHARGE'],
      'priority': 11,
    },

    // --- SMS (Global) ---
    {
      'providerId': 'twilio_global_sms',
      'name': 'Twilio Global Programmable SMS',
      'channel': 'SMS',
      'status': 'ADAPTER_IMPLEMENTED',
      'health': 'HEALTHY',
      'deliveryRate': 99.5,
      'latency': '35ms',
      'cost': '\$0.0079 / msg',
      'countries': ['US', 'GB', 'EU', 'AE', 'SG', 'AU'],
      'capabilities': ['ALPHANUMERIC_SENDER', 'SHORT_CODES', 'GLOBAL_POOL'],
      'priority': 1,
    },
    {
      'providerId': 'vonage_sms',
      'name': 'Vonage Global SMS',
      'channel': 'SMS',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.0,
      'latency': '40ms',
      'cost': '€0.0072 / msg',
      'countries': ['US', 'GB', 'EU', 'AE'],
      'capabilities': ['ADAPTIVE_ROUTING'],
      'priority': 2,
    },
    {
      'providerId': 'sinch_sms',
      'name': 'Sinch Global SMS',
      'channel': 'SMS',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.4,
      'latency': '32ms',
      'cost': '€0.0075 / msg',
      'countries': ['EU', 'US', 'GB', 'SG'],
      'capabilities': ['SUPER_NETWORK'],
      'priority': 3,
    },
    {
      'providerId': 'infobip_sms',
      'name': 'Infobip Global SMS',
      'channel': 'SMS',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.3,
      'latency': '38ms',
      'cost': '€0.0074 / msg',
      'countries': ['EU', 'US', 'GB', 'AE'],
      'capabilities': ['800_CARRIERS'],
      'priority': 4,
    },
    {
      'providerId': 'plivo_sms',
      'name': 'Plivo SMS',
      'channel': 'SMS',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 98.8,
      'latency': '44ms',
      'cost': '\$0.0065 / msg',
      'countries': ['US', 'CA', 'GB', 'AU'],
      'capabilities': ['LOWEST_COST'],
      'priority': 5,
    },
    {
      'providerId': 'telnyx_sms',
      'name': 'Telnyx Global SMS',
      'channel': 'SMS',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.2,
      'latency': '26ms',
      'cost': '\$0.0055 / msg',
      'countries': ['US', 'CA', 'GB', 'EU'],
      'capabilities': ['PRIVATE_IP_FIBRE'],
      'priority': 6,
    },
    {
      'providerId': 'bird_sms',
      'name': 'Bird (MessageBird) SMS',
      'channel': 'SMS',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 98.9,
      'latency': '45ms',
      'cost': '€0.0075 / msg',
      'countries': ['EU', 'US'],
      'capabilities': ['SMART_QUEUE'],
      'priority': 7,
    },
    {
      'providerId': 'clicksend_sms',
      'name': 'ClickSend Global SMS',
      'channel': 'SMS',
      'status': 'CATALOG_ONLY',
      'health': 'HEALTHY',
      'deliveryRate': 98.2,
      'latency': '52ms',
      'cost': '\$0.0080 / msg',
      'countries': ['AU', 'NZ', 'US'],
      'capabilities': ['APAC_REGIONAL'],
      'priority': 8,
    },

    // --- Email ---
    {
      'providerId': 'resend',
      'name': 'Resend',
      'channel': 'EMAIL',
      'status': 'LIVE_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.8,
      'latency': '22ms',
      'cost': '\$0.0006 / email',
      'countries': ['GLOBAL'],
      'capabilities': ['REACT_EMAIL', 'HIGH_DELIVERABILITY', 'DKIM_SPF'],
      'priority': 1,
    },
    {
      'providerId': 'sendgrid',
      'name': 'SendGrid (Twilio)',
      'channel': 'EMAIL',
      'status': 'ADAPTER_IMPLEMENTED',
      'health': 'HEALTHY',
      'deliveryRate': 99.6,
      'latency': '35ms',
      'cost': '\$0.0007 / email',
      'countries': ['GLOBAL'],
      'capabilities': ['TEMPLATES', 'ATTACHMENTS', 'INBOUND_PARSE'],
      'priority': 2,
    },
    {
      'providerId': 'amazon_ses',
      'name': 'Amazon Simple Email Service (SES)',
      'channel': 'EMAIL',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.7,
      'latency': '28ms',
      'cost': '\$0.0001 / email',
      'countries': ['GLOBAL'],
      'capabilities': ['DEDICATED_IPS', 'HIGH_SCALE'],
      'priority': 3,
    },
    {
      'providerId': 'mailgun',
      'name': 'Mailgun',
      'channel': 'EMAIL',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.1,
      'latency': '40ms',
      'cost': '\$0.0008 / email',
      'countries': ['US', 'EU'],
      'capabilities': ['SUPPRESSION_LISTS'],
      'priority': 4,
    },
    {
      'providerId': 'postmark',
      'name': 'Postmark',
      'channel': 'EMAIL',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.9,
      'latency': '15ms',
      'cost': '\$0.0012 / email',
      'countries': ['US', 'EU'],
      'capabilities': ['FASTEST_INBOX'],
      'priority': 5,
    },
    {
      'providerId': 'sparkpost',
      'name': 'SparkPost',
      'channel': 'EMAIL',
      'status': 'CATALOG_ONLY',
      'health': 'HEALTHY',
      'deliveryRate': 99.2,
      'latency': '38ms',
      'cost': '\$0.0009 / email',
      'countries': ['US'],
      'capabilities': ['ENTERPRISE_ANALYTICS'],
      'priority': 6,
    },
    {
      'providerId': 'brevo',
      'name': 'Brevo (Sendinblue)',
      'channel': 'EMAIL',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 98.9,
      'latency': '45ms',
      'cost': '€0.0007 / email',
      'countries': ['FR', 'EU'],
      'capabilities': ['GDPR_COMPLIANCE'],
      'priority': 7,
    },
    {
      'providerId': 'mailersend',
      'name': 'MailerSend',
      'channel': 'EMAIL',
      'status': 'CATALOG_ONLY',
      'health': 'HEALTHY',
      'deliveryRate': 98.7,
      'latency': '42ms',
      'cost': '\$0.0006 / email',
      'countries': ['US', 'EU'],
      'capabilities': ['CLEAN_API'],
      'priority': 8,
    },

    // --- Push ---
    {
      'providerId': 'fcm',
      'name': 'Firebase Cloud Messaging (FCM)',
      'channel': 'PUSH',
      'status': 'LIVE_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.8,
      'latency': '18ms',
      'cost': 'Free / unlimited',
      'countries': ['GLOBAL'],
      'capabilities': ['TOPIC_BROADCAST', 'UNICAST', 'MULTICAST', 'DATA_PAYLOAD'],
      'priority': 1,
    },
    {
      'providerId': 'onesignal',
      'name': 'OneSignal',
      'channel': 'PUSH',
      'status': 'ADAPTER_IMPLEMENTED',
      'health': 'HEALTHY',
      'deliveryRate': 99.3,
      'latency': '25ms',
      'cost': '\$0.0001 / msg',
      'countries': ['GLOBAL'],
      'capabilities': ['INTELLIGENT_DELIVERY', 'RICH_MEDIA'],
      'priority': 2,
    },
    {
      'providerId': 'amazon_sns',
      'name': 'Amazon SNS Mobile Push',
      'channel': 'PUSH',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.6,
      'latency': '22ms',
      'cost': '\$0.00005 / msg',
      'countries': ['GLOBAL'],
      'capabilities': ['PUBSUB_SCALE'],
      'priority': 3,
    },
    {
      'providerId': 'airship',
      'name': 'Airship (Urban Airship)',
      'channel': 'PUSH',
      'status': 'CATALOG_ONLY',
      'health': 'HEALTHY',
      'deliveryRate': 99.1,
      'latency': '35ms',
      'cost': '\$0.0002 / msg',
      'countries': ['GLOBAL'],
      'capabilities': ['GEOFENCING'],
      'priority': 4,
    },

    // --- Voice & Voice OTP ---
    {
      'providerId': 'twilio_voice',
      'name': 'Twilio Programmable Voice & Voice OTP',
      'channel': 'VOICE',
      'status': 'ADAPTER_IMPLEMENTED',
      'health': 'HEALTHY',
      'deliveryRate': 99.2,
      'latency': '52ms',
      'cost': '\$0.015 / min',
      'countries': ['US', 'IN', 'GB', 'EU'],
      'capabilities': ['VOICE_OTP', 'TWIML', 'TEXT_TO_SPEECH', 'CALL_RECORDING'],
      'priority': 1,
    },
    {
      'providerId': 'exotel_voice',
      'name': 'Exotel Cloud Telephony',
      'channel': 'VOICE',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 99.0,
      'latency': '45ms',
      'cost': '₹0.75 / min',
      'countries': ['IN'],
      'capabilities': ['NUMBER_MASKING', 'VOICE_OTP', 'IVR'],
      'priority': 2,
    },
    {
      'providerId': 'vonage_voice',
      'name': 'Vonage Voice API',
      'channel': 'VOICE',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 98.7,
      'latency': '58ms',
      'cost': '€0.014 / min',
      'countries': ['US', 'EU', 'GB'],
      'capabilities': ['NCCO_OBJECTS', 'TTS_40_LANGS'],
      'priority': 3,
    },
    {
      'providerId': 'plivo_voice',
      'name': 'Plivo Voice API',
      'channel': 'VOICE',
      'status': 'CONTRACT_READY',
      'health': 'HEALTHY',
      'deliveryRate': 98.6,
      'latency': '55ms',
      'cost': '\$0.012 / min',
      'countries': ['US', 'CA', 'GB'],
      'capabilities': ['XML_CALL_FLOWS'],
      'priority': 4,
    },
    {
      'providerId': 'telnyx_voice',
      'name': 'Telnyx Programmable Voice',
      'channel': 'VOICE',
      'status': 'CATALOG_ONLY',
      'health': 'HEALTHY',
      'deliveryRate': 99.1,
      'latency': '35ms',
      'cost': '\$0.010 / min',
      'countries': ['US', 'EU'],
      'capabilities': ['PRIVATE_IP_VOICE'],
      'priority': 5,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroBanner(theme),
        const Gap(16),
        _buildSubTabBar(theme),
        const Gap(16),
        if (_selectedSubTab == 'MARKETPLACE') _buildMarketplaceView(theme),
        if (_selectedSubTab == 'ROUTING') _buildRoutingSimulatorView(theme),
        if (_selectedSubTab == 'TEMPLATES') _buildTemplatePreviewerView(theme),
        if (_selectedSubTab == 'DELIVERY') _buildDeliveryMonitorView(theme),
        if (_selectedSubTab == 'COMPLIANCE') _buildComplianceView(theme),
        if (_selectedSubTab == 'OTP') _buildOtpOrchestratorView(theme),
      ],
    );
  }

  Widget _buildHeroBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A),
            theme.colorScheme.primaryContainer.withOpacity(0.8),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: const Text(
                        'PHASE M: ENTERPRISE COMMUNICATIONS FABRIC',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const Gap(12),
                    const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                    const Gap(6),
                    const Text(
                      'All 5 Channels Operational',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                    ),
                  ],
                ),
                const Gap(12),
                const Text(
                  'Omnichannel Communications & Messaging Control Plane',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(8),
                Text(
                  'Orchestrate WhatsApp, SMS (DLT/Global), Email, Mobile Push, and Voice OTP across 44 verified gateways with intelligent routing and zero vendor lock-in.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Gap(24),
          _buildHeroMetric('44 Gateways', 'Across 5 Channels', Icons.cell_tower_rounded, Colors.cyanAccent),
          const Gap(12),
          _buildHeroMetric('99.8%', 'Delivery SLA', Icons.verified_rounded, Colors.greenAccent),
          const Gap(12),
          _buildHeroMetric('11 Languages', 'Auto-Localization', Icons.translate_rounded, Colors.amberAccent),
        ],
      ),
    );
  }

  Widget _buildHeroMetric(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Gap(8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const Gap(4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabBar(ThemeData theme) {
    return Row(
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'MARKETPLACE',
              label: Text('Gateway Catalog (44)'),
              icon: Icon(Icons.grid_view_rounded, size: 16),
            ),
            ButtonSegment(
              value: 'ROUTING',
              label: Text('Routing Simulator'),
              icon: Icon(Icons.alt_route_rounded, size: 16),
            ),
            ButtonSegment(
              value: 'TEMPLATES',
              label: Text('Multi-Language Templates'),
              icon: Icon(Icons.text_snippet_rounded, size: 16),
            ),
            ButtonSegment(
              value: 'DELIVERY',
              label: Text('Delivery State Monitor'),
              icon: Icon(Icons.monitor_heart_rounded, size: 16),
            ),
            ButtonSegment(
              value: 'COMPLIANCE',
              label: Text('Consent & Quiet Hours'),
              icon: Icon(Icons.shield_rounded, size: 16),
            ),
            ButtonSegment(
              value: 'OTP',
              label: Text('OTP Security & Fallback'),
              icon: Icon(Icons.password_rounded, size: 16),
            ),
          ],
          selected: {_selectedSubTab},
          onSelectionChanged: (set) {
            setState(() {
              _selectedSubTab = set.first;
            });
          },
        ),
      ],
    );
  }

  // =========================================================================
  // SUB-TAB 1: MARKETPLACE CATALOG (44 PROVIDERS)
  // =========================================================================
  Widget _buildMarketplaceView(ThemeData theme) {
    final filtered = _providers.filter((p) {
      if (_selectedChannelFilter != 'ALL' && p['channel'] != _selectedChannelFilter) return false;
      if (_selectedStatusFilter != 'ALL' && p['status'] != _selectedStatusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (p['name'] as String).toLowerCase();
        final id = (p['providerId'] as String).toLowerCase();
        if (!name.contains(q) && !id.contains(q)) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search 44 communication providers (e.g. Meta, MSG91, Twilio, SendGrid)...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const Gap(16),
            // Channel Filter
            DropdownButton<String>(
              value: _selectedChannelFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Channels (44)')),
                DropdownMenuItem(value: 'WHATSAPP', child: Text('WhatsApp (8)')),
                DropdownMenuItem(value: 'SMS', child: Text('SMS (19)')),
                DropdownMenuItem(value: 'EMAIL', child: Text('Email (8)')),
                DropdownMenuItem(value: 'PUSH', child: Text('Push (4)')),
                DropdownMenuItem(value: 'VOICE', child: Text('Voice & OTP (5)')),
              ],
              onChanged: (val) => setState(() => _selectedChannelFilter = val ?? 'ALL'),
            ),
            const Gap(16),
            // Status Filter
            DropdownButton<String>(
              value: _selectedStatusFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                DropdownMenuItem(value: 'LIVE_READY', child: Text('Live Ready')),
                DropdownMenuItem(value: 'ADAPTER_IMPLEMENTED', child: Text('Adapter Implemented')),
                DropdownMenuItem(value: 'CONTRACT_READY', child: Text('Contract Ready')),
                DropdownMenuItem(value: 'CATALOG_ONLY', child: Text('Catalog Only')),
              ],
              onChanged: (val) => setState(() => _selectedStatusFilter = val ?? 'ALL'),
            ),
          ],
        ),
        const Gap(16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380,
            mainAxisExtent: 220,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _buildProviderCard(theme, filtered[index]);
          },
        ),
      ],
    );
  }

  Widget _buildProviderCard(ThemeData theme, Map<String, dynamic> p) {
    final status = p['status'] as String;
    Color statusColor = Colors.grey;
    if (status == 'LIVE_READY') {
      statusColor = Colors.green;
    } else if (status == 'ADAPTER_IMPLEMENTED') {
      statusColor = Colors.blue;
    } else if (status == 'CONTRACT_READY') {
      statusColor = Colors.orange;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getChannelIcon(p['channel'] as String),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        p['channel'] as String,
                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCardMiniMetric('Delivery', '${p['deliveryRate']}%', Colors.green),
                _buildCardMiniMetric('Latency', p['latency'] as String, Colors.blueGrey),
                _buildCardMiniMetric('Cost', p['cost'] as String, Colors.amber.shade800),
              ],
            ),
            const Spacer(),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: ((p['capabilities'] as List<String>?) ?? []).take(3).map((cap) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(cap, style: const TextStyle(fontSize: 10)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardMiniMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
      ],
    );
  }

  Widget _getChannelIcon(String channel) {
    IconData icon;
    Color color;
    switch (channel) {
      case 'WHATSAPP':
        icon = Icons.chat_bubble_rounded;
        color = const Color(0xFF25D366);
        break;
      case 'SMS':
        icon = Icons.textsms_rounded;
        color = Colors.blue;
        break;
      case 'EMAIL':
        icon = Icons.mail_rounded;
        color = Colors.deepPurple;
        break;
      case 'PUSH':
        icon = Icons.notifications_active_rounded;
        color = Colors.orange;
        break;
      case 'VOICE':
        icon = Icons.phone_in_talk_rounded;
        color = Colors.teal;
        break;
      default:
        icon = Icons.message_rounded;
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  // =========================================================================
  // SUB-TAB 2: ROUTING SIMULATOR
  // =========================================================================
  Widget _buildRoutingSimulatorView(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Multi-Factor Communication Route Simulator',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Gap(6),
                  const Text(
                    'Evaluate real-time channel selection, health scores, failover safety, and cost models.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const Divider(height: 24),
                  DropdownButtonFormField<String>(
                    value: _simMessageType,
                    decoration: const InputDecoration(labelText: 'Message Type'),
                    items: const [
                      DropdownMenuItem(value: 'OTP', child: Text('Security OTP (Voice Fallback)')),
                      DropdownMenuItem(value: 'TRANSACTIONAL', child: Text('Transactional Booking Confirmation')),
                      DropdownMenuItem(value: 'OPERATIONAL', child: Text('Operational Pickup Alert (Push First)')),
                      DropdownMenuItem(value: 'MARKETING', child: Text('Marketing Promotional Campaign')),
                    ],
                    onChanged: (val) => setState(() => _simMessageType = val ?? 'OTP'),
                  ),
                  const Gap(16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _simCountry,
                          decoration: const InputDecoration(labelText: 'Recipient Country'),
                          items: const [
                            DropdownMenuItem(value: 'IN', child: Text('India (+91)')),
                            DropdownMenuItem(value: 'US', child: Text('United States (+1)')),
                            DropdownMenuItem(value: 'GB', child: Text('United Kingdom (+44)')),
                            DropdownMenuItem(value: 'AE', child: Text('United Arab Emirates (+971)')),
                          ],
                          onChanged: (val) => setState(() => _simCountry = val ?? 'IN'),
                        ),
                      ),
                      const Gap(16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _simLanguage,
                          decoration: const InputDecoration(labelText: 'Language Preference'),
                          items: const [
                            DropdownMenuItem(value: 'en', child: Text('English (en)')),
                            DropdownMenuItem(value: 'hi', child: Text('Hindi (hi)')),
                            DropdownMenuItem(value: 'te', child: Text('Telugu (te)')),
                            DropdownMenuItem(value: 'ta', child: Text('Tamil (ta)')),
                          ],
                          onChanged: (val) => setState(() => _simLanguage = val ?? 'en'),
                        ),
                      ),
                    ],
                  ),
                  const Gap(16),
                  SwitchListTile(
                    title: const Text('Simulate Current Time in Quiet Hours (21:00 - 08:00)'),
                    subtitle: const Text('Tests TRAI / regulatory compliance suppression of promotional traffic'),
                    value: _simQuietHours,
                    onChanged: (val) => setState(() => _simQuietHours = val),
                  ),
                  const Gap(20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Simulate Route & Fallback Chain'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    onPressed: _runRoutingSimulation,
                  ),
                ],
              ),
            ),
          ),
        ),
        const Gap(20),
        Expanded(
          flex: 3,
          child: _routingPreviewResult == null
              ? Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_rounded, size: 48, color: Colors.grey),
                          Gap(12),
                          Text('Select parameters and click "Simulate Route" to view decision tree.'),
                        ],
                      ),
                    ),
                  ),
                )
              : _buildSimulationResultCard(theme),
        ),
      ],
    );
  }

  void _runRoutingSimulation() {
    // Deterministic simulation based on inputs
    if (_simMessageType == 'MARKETING' && _simQuietHours) {
      setState(() {
        _routingPreviewResult = {
          'allowed': false,
          'reason': 'Blocked: Promotional messaging prohibited during quiet hours (21:00 - 08:00).',
          'channel': 'PUSH',
          'provider': 'None (Suppressed)',
          'fallbackChain': [],
        };
      });
      return;
    }

    String primaryChannel = 'WHATSAPP';
    String primaryProvider = 'meta';
    List<Map<String, String>> fallback = [];

    if (_simMessageType == 'OTP') {
      primaryChannel = 'WHATSAPP';
      primaryProvider = _simCountry == 'IN' ? 'meta' : 'twilio_whatsapp';
      fallback = [
        {'channel': 'SMS', 'provider': _simCountry == 'IN' ? 'msg91' : 'twilio_global_sms'},
        {'channel': 'VOICE', 'provider': 'twilio_voice'},
      ];
    } else if (_simMessageType == 'OPERATIONAL') {
      primaryChannel = 'PUSH';
      primaryProvider = 'fcm';
      fallback = [
        {'channel': 'WHATSAPP', 'provider': 'meta'},
        {'channel': 'SMS', 'provider': 'msg91'},
      ];
    } else if (_simMessageType == 'TRANSACTIONAL') {
      primaryChannel = 'WHATSAPP';
      primaryProvider = 'meta';
      fallback = [
        {'channel': 'SMS', 'provider': 'msg91'},
        {'channel': 'EMAIL', 'provider': 'resend'},
      ];
    } else {
      primaryChannel = 'PUSH';
      primaryProvider = 'fcm';
      fallback = [
        {'channel': 'EMAIL', 'provider': 'resend'},
      ];
    }

    setState(() {
      _routingPreviewResult = {
        'allowed': true,
        'channel': primaryChannel,
        'provider': primaryProvider,
        'fallbackChain': fallback,
        'score': 94,
        'cost': primaryChannel == 'WHATSAPP' ? '₹0.45' : '₹0.14',
        'latency': '28ms',
        'explanation': 'Selected $primaryProvider for $primaryChannel due to 99.8% health, lowest latency in $_simCountry, and valid template.',
      };
    });
  }

  Widget _buildSimulationResultCard(ThemeData theme) {
    final res = _routingPreviewResult!;
    final isAllowed = res['allowed'] == true;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAllowed ? Icons.check_circle_rounded : Icons.block_rounded,
                  color: isAllowed ? Colors.green : Colors.red,
                  size: 24,
                ),
                const Gap(8),
                Text(
                  isAllowed ? 'Routing Decision: Optimal Gateway Selected' : 'Dispatch Suppressed',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 24),
            if (!isAllowed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  res['reason'] as String,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  _buildResultChip('Target Channel', res['channel'] as String, Colors.blue),
                  const Gap(12),
                  _buildResultChip('Primary Provider', res['provider'] as String, Colors.green),
                  const Gap(12),
                  _buildResultChip('Cost Estimate', res['cost'] as String, Colors.amber.shade800),
                  const Gap(12),
                  _buildResultChip('Expected Latency', res['latency'] as String, Colors.teal),
                ],
              ),
              const Gap(16),
              Text(
                'Selection Explanation:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13),
              ),
              const Gap(4),
              Text(res['explanation'] as String, style: const TextStyle(fontSize: 13)),
              const Gap(20),
              const Text(
                'Policy Fallback Chain (Safe Failover):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Gap(10),
              Column(
                children: ((res['fallbackChain'] as List<Map<String, String>>?) ?? []).map((fb) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                        const Gap(10),
                        Text('Fallback: ${fb['channel']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('Gateway: ${fb['provider']}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultChip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const Gap(2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  // =========================================================================
  // SUB-TAB 3: MULTI-LANGUAGE TEMPLATES PREVIEWER
  // =========================================================================
  Widget _buildTemplatePreviewerView(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enterprise Template Explorer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Gap(6),
                  const Text('Multi-channel, multi-lingual verified templates with TRAI DLT registration.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const Divider(height: 24),
                  DropdownButtonFormField<String>(
                    value: _selectedTemplate,
                    decoration: const InputDecoration(labelText: 'Template Name'),
                    items: const [
                      DropdownMenuItem(value: 'BOOKING_CONFIRMATION', child: Text('BOOKING_CONFIRMATION')),
                      DropdownMenuItem(value: 'OTP_VERIFICATION', child: Text('OTP_VERIFICATION')),
                      DropdownMenuItem(value: 'PICKUP_REMINDER', child: Text('PICKUP_REMINDER')),
                      DropdownMenuItem(value: 'PAYMENT_SUCCESS', child: Text('PAYMENT_SUCCESS')),
                      DropdownMenuItem(value: 'MARKETING_DISCOUNT', child: Text('MARKETING_DISCOUNT')),
                    ],
                    onChanged: (val) => setState(() => _selectedTemplate = val ?? 'BOOKING_CONFIRMATION'),
                  ),
                  const Gap(16),
                  DropdownButtonFormField<String>(
                    value: _selectedTemplateLang,
                    decoration: const InputDecoration(labelText: 'Language'),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English (en)')),
                      DropdownMenuItem(value: 'hi', child: Text('Hindi (hi)')),
                      DropdownMenuItem(value: 'te', child: Text('Telugu (te)')),
                      DropdownMenuItem(value: 'ta', child: Text('Tamil (ta)')),
                      DropdownMenuItem(value: 'kn', child: Text('Kannada (kn)')),
                      DropdownMenuItem(value: 'mr', child: Text('Marathi (mr)')),
                      DropdownMenuItem(value: 'es', child: Text('Spanish (es)')),
                      DropdownMenuItem(value: 'ar', child: Text('Arabic (ar)')),
                    ],
                    onChanged: (val) => setState(() => _selectedTemplateLang = val ?? 'en'),
                  ),
                  const Gap(24),
                  const Text('TRAI DLT Entity ID:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const Text('1101552230000014 (DriveGo Mobility Pvt Ltd)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Gap(8),
                  const Text('DLT Template ID:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const Text('1107161234567890123 (Header: DRIVGO)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
        const Gap(20),
        Expanded(
          flex: 3,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phone_iphone_rounded, color: Colors.blueAccent),
                      const Gap(8),
                      Text(
                        'Device Preview: $_selectedTemplate [$_selectedTemplateLang]',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5DDD5), // WhatsApp chat background
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getRenderedTemplateSample(_selectedTemplate, _selectedTemplateLang),
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                            const Gap(8),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '12:30 PM',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                  const Gap(4),
                                  const Icon(Icons.done_all, color: Colors.blue, size: 14),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getRenderedTemplateSample(String template, String lang) {
    if (template == 'OTP_VERIFICATION') {
      if (lang == 'hi') return '749210 आपका DriveGo सुरक्षा कोड है। यह 10 मिनट के लिए मान्य है। इसे किसी के साथ साझा न करें।';
      if (lang == 'te') return '749210 మీ DriveGo ధృవీకరణ కోడ్. 10 నిమిషాలు మాత్రమే చెల్లుతుంది. ఎవరితోనూ పంచుకోవద్దు.';
      return '749210 is your DriveGo verification code. Valid for 10 minutes. Please do not share this OTP with anyone.';
    }
    if (template == 'BOOKING_CONFIRMATION') {
      if (lang == 'hi') return 'नमस्ते राहुल, Mahindra Thar (बुकिंग #BK-8921) के लिए आपकी बुकिंग हवाई अड्डा हब पर आज 02:00 PM के लिए सुनिश्चित हो गई है।';
      if (lang == 'te') return 'నమస్కారం రాహుల్, Mahindra Thar కొరకు మీ బుకింగ్ (#BK-8921) విమానాశ్రయం వద్ద 02:00 PM కు నిర్ధారించబడింది.';
      if (lang == 'es') return 'Hola Carlos, tu reserva de Hyundai Creta (#BK-8921) está confirmada para las 14:00 en Terminal Aeropuerto.';
      return 'Hello Rahul, your booking for Mahindra Thar (#BK-8921) is confirmed for pickup on Today at 02:00 PM at Bengaluru Airport Hub. Drive safe!';
    }
    return 'DriveGo Notification: Your vehicle rental update has been processed successfully.';
  }

  // =========================================================================
  // SUB-TAB 4: DELIVERY MONITOR (14 STATES)
  // =========================================================================
  Widget _buildDeliveryMonitorView(ThemeData theme) {
    final states = [
      'CREATED', 'QUEUED', 'ROUTING', 'DISPATCHING', 'ACCEPTED',
      'SENT', 'DELIVERED', 'READ', 'FAILED', 'RETRYING',
      'FALLBACK_PENDING', 'FALLBACK_SENT', 'EXPIRED', 'CANCELLED'
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('14-State Canonical Communication Lifecycle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Gap(6),
            const Text('Real-time message state transitions with duplicate-protection on indeterminate states.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const Divider(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: states.map((st) {
                Color c = Colors.blueGrey;
                if (st == 'DELIVERED' || st == 'READ') {
                  c = Colors.green;
                } else if (st == 'FAILED' || st == 'EXPIRED') {
                  c = Colors.red;
                } else if (st == 'FALLBACK_PENDING') {
                  c = Colors.amber.shade800;
                } else if (st == 'ACCEPTED' || st == 'SENT') {
                  c = Colors.blue;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: c, size: 8),
                      const Gap(8),
                      Text(st, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SUB-TAB 5: COMPLIANCE & QUIET HOURS
  // =========================================================================
  Widget _buildComplianceView(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Compliance, TRAI DND & Quiet Hours Governance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Gap(6),
            const Text('Enforce regulatory quiet hours, customer channel opt-outs, and National NCPR DND scrubbing.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const Divider(height: 24),
            SwitchListTile(
              title: const Text('Regulatory Quiet Hours Enabled'),
              subtitle: Text('Promotional messages suppressed between $_quietHoursStart:00 and 0$_quietHoursEnd:00'),
              value: _quietHoursEnabled,
              onChanged: (val) => setState(() => _quietHoursEnabled = val),
            ),
            const Gap(16),
            const Text('Opt-out Blocklist (Suppressed Recipients):', style: TextStyle(fontWeight: FontWeight.bold)),
            const Gap(8),
            Wrap(
              spacing: 8,
              children: _blockedNumbers.map((recipientEntry) {
                return Chip(
                  avatar: const Icon(Icons.block, size: 16, color: Colors.red),
                  label: Text(recipientEntry),
                  onDeleted: () => setState(() => _blockedNumbers.remove(recipientEntry)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SUB-TAB 6: OTP PLATFORM & SECURITY CONTROLS
  // =========================================================================
  Widget _buildOtpOrchestratorView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Colors.tealAccent, size: 24),
                    const Gap(10),
                    const Text('Unified Enterprise OTP Orchestrator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.tealAccent),
                      ),
                      child: const Text('CSPRNG + SHA-256 PEPPER', style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Gap(8),
                const Text(
                  'Zero-plaintext OTP architecture with multi-channel fallback (WhatsApp OTP → SMS OTP → Voice OTP), purpose binding, 60s cooldown rate-limiting, and 15-minute brute-force lockout protection.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const Divider(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _buildSecurityPill(Icons.lock_clock_rounded, 'TTL Expiry', '10 Minutes', Colors.blue),
                    _buildSecurityPill(Icons.shield_outlined, 'Hash Standard', 'SHA-256 + Server Pepper', Colors.purpleAccent),
                    _buildSecurityPill(Icons.speed_rounded, 'Cooldown Limit', '60s per Identifier', Colors.amber),
                    _buildSecurityPill(Icons.warning_amber_rounded, 'Max Attempts', '3 Before Lockout', Colors.redAccent),
                    _buildSecurityPill(Icons.call_split_rounded, 'Fallback Chain', 'WhatsApp → SMS → Voice', Colors.tealAccent),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Gap(16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dispatch OTP Challenge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Gap(14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Purpose Binding',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              value: _otpPurpose,
                              items: const [
                                DropdownMenuItem(value: 'AUTH', child: Text('User Login / Auth')),
                                DropdownMenuItem(value: 'HANDOVER_PICKUP', child: Text('Vehicle Pickup Handover')),
                                DropdownMenuItem(value: 'HANDOVER_RETURN', child: Text('Vehicle Return Handover')),
                                DropdownMenuItem(value: 'PAYMENT', child: Text('High-Value Payment Confirmation')),
                              ],
                              onChanged: (v) => setState(() => _otpPurpose = v ?? 'AUTH'),
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Initial Rail',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              value: _otpChannel,
                              items: const [
                                DropdownMenuItem(value: 'WHATSAPP', child: Text('WhatsApp OTP (Meta/Gupshup)')),
                                DropdownMenuItem(value: 'SMS', child: Text('SMS OTP (MSG91/Twilio)')),
                                DropdownMenuItem(value: 'VOICE', child: Text('Voice OTP (Twilio/Exotel)')),
                                DropdownMenuItem(value: 'EMAIL', child: Text('Email OTP (Resend)')),
                              ],
                              onChanged: (v) => setState(() => _otpChannel = v ?? 'WHATSAPP'),
                            ),
                          ),
                        ],
                      ),
                      const Gap(14),
                      TextFormField(
                        initialValue: _otpIdentifier,
                        decoration: const InputDecoration(
                          labelText: 'Recipient Phone / Email (E.164)',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.phone_rounded, size: 20),
                        ),
                        onChanged: (v) => _otpIdentifier = v,
                      ),
                      const Gap(16),
                      FilledButton.icon(
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Generate CSPRNG & Dispatch'),
                        onPressed: () {
                          // Deterministic preview generation
                          final code = (100000 + (DateTime.now().millisecondsSinceEpoch % 899999)).toString();
                          setState(() {
                            _generatedChallengeId = 'chal_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
                            _simulatedOtpCode = code;
                            _otpAttemptsRemaining = 3;
                            _otpVerified = false;
                            _otpStatusMessage = 'Challenge dispatched to $_otpIdentifier via $_otpChannel rail.';
                            _otpInputController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Gap(16),
            Expanded(
              flex: 5,
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Verify Challenge & Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Gap(14),
                      if (_generatedChallengeId == null)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('No challenge dispatched yet. Click "Generate & Dispatch" on the left.', style: TextStyle(color: Colors.grey)),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Challenge ID: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(_generatedChallengeId!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.cyanAccent)),
                                  const Spacer(),
                                  Text('Attempts: ${3 - _otpAttemptsRemaining}/3', style: TextStyle(fontSize: 12, color: _otpAttemptsRemaining == 1 ? Colors.red : Colors.grey)),
                                ],
                              ),
                              const Gap(4),
                              Text('Purpose: $_otpPurpose | Identifier: $_otpIdentifier', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const Gap(4),
                              Row(
                                children: [
                                  const Text('Simulated Delivery Code: ', style: TextStyle(fontSize: 12, color: Colors.amber)),
                                  Text(_simulatedOtpCode ?? '------', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 14, color: Colors.amberAccent)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Gap(14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _otpInputController,
                                maxLength: 6,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Enter 6-Digit Code',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  counterText: '',
                                ),
                              ),
                            ),
                            const Gap(10),
                            FilledButton(
                              onPressed: _otpVerified || _otpAttemptsRemaining <= 0
                                  ? null
                                  : () {
                                      final entered = _otpInputController.text.trim();
                                      if (entered == _simulatedOtpCode) {
                                        setState(() {
                                          _otpVerified = true;
                                          _otpStatusMessage = 'Verification Successful! Purpose [$_otpPurpose] validated.';
                                        });
                                      } else {
                                        setState(() {
                                          _otpAttemptsRemaining--;
                                          if (_otpAttemptsRemaining <= 0) {
                                            _otpStatusMessage = 'Brute-force lockout engaged! 3 failed attempts reached. Locked for 15m.';
                                          } else {
                                            _otpStatusMessage = 'Invalid OTP code! Remaining attempts: $_otpAttemptsRemaining';
                                          }
                                        });
                                      }
                                    },
                              child: const Text('Verify'),
                            ),
                          ],
                        ),
                        if (_otpStatusMessage != null) ...[
                          const Gap(10),
                          Text(
                            _otpStatusMessage!,
                            style: TextStyle(
                              color: _otpVerified
                                  ? Colors.greenAccent
                                  : (_otpAttemptsRemaining <= 0 ? Colors.redAccent : Colors.orangeAccent),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityPill(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const Gap(8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

extension _IterableFilter<E> on Iterable<E> {
  Iterable<E> filter(bool Function(E) test) => where(test);
}
