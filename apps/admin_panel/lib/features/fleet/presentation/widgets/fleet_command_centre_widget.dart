import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FleetCommandCentreWidget extends StatefulWidget {
  const FleetCommandCentreWidget({super.key});

  @override
  State<FleetCommandCentreWidget> createState() => _FleetCommandCentreWidgetState();
}

class _FleetCommandCentreWidgetState extends State<FleetCommandCentreWidget> {
  String _selectedFilter = 'ALL';

  final List<Map<String, dynamic>> _mockVehicles = [
    {
      'carId': 'car_101',
      'make': 'Hyundai',
      'model': 'Creta SX(O)',
      'regNumber': 'KA01-MJ-4412',
      'branch': 'Bengaluru Central Hub',
      'state': 'AVAILABLE',
      'reason': 'Cleaned and ready for pickup',
      'nextAvailable': 'Immediate',
      'speed': '0 km/h',
      'odometer': '18,450 km',
      'fuel': '90%',
      'ignition': 'OFF',
      'compliance': 'VALID',
      'daysToInsuranceExpiry': 142,
    },
    {
      'carId': 'car_102',
      'make': 'Tata',
      'model': 'Nexon EV Empowered',
      'regNumber': 'KA05-EV-9901',
      'branch': 'Airport T2 Terminal',
      'state': 'ON_RENT',
      'reason': 'Trip #BK_8821 active. Expected return 18:30',
      'nextAvailable': 'Today, 19:30 (+60m buffer)',
      'speed': '58 km/h',
      'odometer': '12,230 km',
      'fuel': '74% Battery',
      'ignition': 'ON',
      'compliance': 'VALID',
      'daysToInsuranceExpiry': 89,
    },
    {
      'carId': 'car_103',
      'make': 'Mahindra',
      'model': 'XUV700 AX7L',
      'regNumber': 'KA03-NB-1120',
      'branch': 'Koramangala Station',
      'state': 'MAINTENANCE',
      'reason': 'Front brake pad replacement in progress',
      'nextAvailable': 'Tomorrow, 11:00',
      'speed': '0 km/h',
      'odometer': '34,800 km',
      'fuel': '45%',
      'ignition': 'OFF',
      'compliance': 'VALID',
      'daysToInsuranceExpiry': 210,
    },
    {
      'carId': 'car_104',
      'make': 'Maruti Suzuki',
      'model': 'Swift ZXi+',
      'regNumber': 'KA04-EQ-3319',
      'branch': 'Indiranagar Hub',
      'state': 'COMPLIANCE_BLOCKED',
      'reason': 'Fitness certificate expired 3 days ago',
      'nextAvailable': 'Blocked until RTO renewal',
      'speed': '0 km/h',
      'odometer': '48,120 km',
      'fuel': '60%',
      'ignition': 'OFF',
      'compliance': 'EXPIRED',
      'daysToInsuranceExpiry': -3,
    },
    {
      'carId': 'car_105',
      'make': 'Toyota',
      'model': 'Innova Crysta VX',
      'regNumber': 'KA01-TP-7788',
      'branch': 'Whitefield Depot',
      'state': 'GPS_OFFLINE',
      'reason': 'Telematics heartbeat dropped for 45 minutes',
      'nextAvailable': 'Held until IoT signal restored',
      'speed': 'Unknown',
      'odometer': '52,100 km',
      'fuel': '80%',
      'ignition': 'OFF',
      'compliance': 'VALID',
      'daysToInsuranceExpiry': 115,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _mockVehicles.where((v) {
      if (_selectedFilter == 'ALL') return true;
      return v['state'] == _selectedFilter;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Rebalancing Alert Banner ───
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.swap_horiz, color: Color(0xFF2563EB), size: 28),
              const Gap(14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Fleet Rebalance Recommendation: 2 Compact SUVs Needed at Airport T2',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E40AF)),
                    ),
                    Gap(2),
                    Text(
                      'Airport T2 Hub is at 92% utilization with surge demand. Transfer 2 idle SUVs from Bengaluru Central Hub to avoid booking turnaways.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rebalance transfer order dispatched to fleet logistics team.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Dispatch Transfer', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const Gap(18),

        // ─── Filter Chips ───
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('ALL', 'All Fleet (5)'),
              const Gap(8),
              _buildFilterChip('AVAILABLE', 'Available (1)', color: Colors.green),
              const Gap(8),
              _buildFilterChip('ON_RENT', 'On Rent (1)', color: Colors.blue),
              const Gap(8),
              _buildFilterChip('MAINTENANCE', 'In Maintenance (1)', color: Colors.orange),
              const Gap(8),
              _buildFilterChip('COMPLIANCE_BLOCKED', 'Compliance Blocked (1)', color: Colors.red),
              const Gap(8),
              _buildFilterChip('GPS_OFFLINE', 'GPS Offline (1)', color: Colors.purple),
            ],
          ),
        ),
        const Gap(16),

        // ─── Vehicle Cards List ───
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Gap(12),
          itemBuilder: (context, index) {
            final v = filtered[index];
            return _buildVehicleCard(context, v);
          },
        ),
      ],
    );
  }

  Widget _buildFilterChip(String filterKey, String label, {Color? color}) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
      ),
      selected: isSelected,
      selectedColor: color ?? const Color(0xFF2563EB),
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (val) {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
    );
  }

  Widget _buildVehicleCard(BuildContext context, Map<String, dynamic> v) {
    Color statusColor;
    switch (v['state']) {
      case 'AVAILABLE':
        statusColor = Colors.green;
        break;
      case 'ON_RENT':
        statusColor = Colors.blue;
        break;
      case 'MAINTENANCE':
        statusColor = Colors.orange;
        break;
      case 'COMPLIANCE_BLOCKED':
        statusColor = Colors.red;
        break;
      case 'GPS_OFFLINE':
        statusColor = Colors.purple;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      v['state'],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Gap(10),
                  Text(
                    '${v['make']} ${v['model']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  const Gap(8),
                  Text(
                    '(${v['regNumber']})',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Text(
                v['branch'],
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
              ),
            ],
          ),
          const Gap(10),

          // Explainable State & Reason
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                const Gap(8),
                Expanded(
                  child: Text(
                    'Status Rationale: ${v['reason']}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                  ),
                ),
                Text(
                  'Next Available: ${v['nextAvailable']}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          const Gap(12),

          // Telematics Snapshot Strip
          Row(
            children: [
              _buildTelemetryChip(Icons.speed, 'Speed', v['speed']),
              const Gap(16),
              _buildTelemetryChip(Icons.linear_scale, 'Odometer', v['odometer']),
              const Gap(16),
              _buildTelemetryChip(Icons.local_gas_station, 'Energy', v['fuel']),
              const Gap(16),
              _buildTelemetryChip(Icons.power_settings_new, 'Ignition', v['ignition']),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _showInspectionDialog(context, v),
                icon: const Icon(Icons.checklist, size: 16),
                label: const Text('16-Pt Inspection', style: TextStyle(fontSize: 12)),
              ),
              const Gap(8),
              ElevatedButton.icon(
                onPressed: () => _showTransitionDialog(context, v),
                icon: const Icon(Icons.swap_calls, size: 16),
                label: const Text('Change State', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryChip(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const Gap(4),
        Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      ],
    );
  }

  void _showInspectionDialog(BuildContext context, Map<String, dynamic> v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('16-Point Vehicle Inspection: ${v['make']} ${v['model']}'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Full pre-rental and return digital condition report:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const Gap(12),
              _buildChecklistRow('EXT_01 Front Bumper & Grille', 'PASS'),
              _buildChecklistRow('EXT_06 Windshield & Glass', 'PASS'),
              _buildChecklistRow('EXT_07 Tyres & Tread Depth', 'PASS'),
              _buildChecklistRow('INT_10 Cabin Cleanliness', 'PASS'),
              _buildChecklistRow('MEC_12 Odometer Verification', 'PASS (18,450 km)'),
              _buildChecklistRow('MEC_13 Fuel / Battery Level', 'PASS (90%)'),
              _buildChecklistRow('DOC_16 Mandatory Documents in Glovebox', 'PASS'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildChecklistRow(String item, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          Text(status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }

  void _showTransitionDialog(BuildContext context, Map<String, dynamic> v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Transition State for ${v['regNumber']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current State: ${v['state']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Gap(12),
            const Text('Select Target Operational State:', style: TextStyle(fontSize: 12)),
            const Gap(8),
            DropdownButtonFormField<String>(
              value: 'AVAILABLE',
              items: const [
                DropdownMenuItem(value: 'AVAILABLE', child: Text('AVAILABLE (Ready for Rental)')),
                DropdownMenuItem(value: 'CLEANING', child: Text('CLEANING (Turnaround Sanitization)')),
                DropdownMenuItem(value: 'MAINTENANCE', child: Text('MAINTENANCE (Workshop)')),
                DropdownMenuItem(value: 'COMPLIANCE_BLOCKED', child: Text('COMPLIANCE_BLOCKED')),
                DropdownMenuItem(value: 'RETIRED', child: Text('RETIRED (Decommissioned)')),
              ],
              onChanged: (_) {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('State transition successfully executed and audited.')),
              );
            },
            child: const Text('Apply Transition'),
          ),
        ],
      ),
    );
  }
}
