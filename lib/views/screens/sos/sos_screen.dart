import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cwc/utils/themes/theme.dart';

/// SOS Emergency Screen
/// Contains important emergency numbers for Pakistan
class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  Future<void> _makeCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      throw 'Could not launch $phoneNumber';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: CAppTheme.errorColor,
        foregroundColor: Colors.white,
        title: Text(
          'Emergency SOS',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: BoxDecoration(
                color: CAppTheme.errorColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emergency_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Emergency Services',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap on any number to call immediately',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildEmergencyCard(
                    context: context,
                    icon: Icons.local_police_rounded,
                    title: 'Police',
                    number: '15',
                    color: const Color(0xFF3B82F6),
                    onTap: () => _makeCall('15'),
                  ),
                  const SizedBox(height: 12),
                  _buildEmergencyCard(
                    context: context,
                    icon: Icons.medical_services_rounded,
                    title: 'Ambulance',
                    number: '115',
                    color: CAppTheme.errorColor,
                    onTap: () => _makeCall('115'),
                  ),
                  const SizedBox(height: 12),
                  _buildEmergencyCard(
                    context: context,
                    icon: Icons.fire_extinguisher_rounded,
                    title: 'Fire Brigade',
                    number: '16',
                    color: const Color(0xFFF97316),
                    onTap: () => _makeCall('16'),
                  ),
                  const SizedBox(height: 12),
                  _buildEmergencyCard(
                    context: context,
                    icon: Icons.emergency_outlined,
                    title: 'Rescue 1122',
                    number: '1122',
                    color: CAppTheme.successColor,
                    onTap: () => _makeCall('1122'),
                  ),
                  const SizedBox(height: 12),
                  _buildEmergencyCard(
                    context: context,
                    icon: Icons.woman_rounded,
                    title: 'Women Helpline',
                    number: '1099',
                    color: const Color(0xFFEC4899),
                    onTap: () => _makeCall('1099'),
                  ),
                  const SizedBox(height: 12),
                  _buildEmergencyCard(
                    context: context,
                    icon: Icons.child_care_rounded,
                    title: 'Child Helpline',
                    number: '1098',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => _makeCall('1098'),
                  ),
                  const SizedBox(height: 12),
                  _buildEmergencyCard(
                    context: context,
                    icon: Icons.traffic_rounded,
                    title: 'Traffic Police',
                    number: '1915',
                    color: CAppTheme.warningColor,
                    onTap: () => _makeCall('1915'),
                  ),
                  const SizedBox(height: 12),
                  _buildEmergencyCard(
                    context: context,
                    icon: Icons.bolt_rounded,
                    title: 'Electricity Emergency',
                    number: '118',
                    color: const Color(0xFFEAB308),
                    onTap: () => _makeCall('118'),
                  ),
                  const SizedBox(height: 12),
                  _buildEmergencyCard(
                    context: context,
                    icon: Icons.local_gas_station_rounded,
                    title: 'Gas Emergency',
                    number: '1199',
                    color: const Color(0xFF64748B),
                    onTap: () => _makeCall('1199'),
                  ),
                  const SizedBox(height: 20),

                  // Info section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: CAppTheme.primaryColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                      border: Border.all(
                        color: CAppTheme.primaryColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: CAppTheme.primaryColor, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'Important Information',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: CAppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoItem('All emergency services are available 24/7'),
                        _buildInfoItem('Call charges may apply as per your network'),
                        _buildInfoItem('Stay calm and provide clear information'),
                        _buildInfoItem('Keep your location ready when calling'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String number,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CAppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      number,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                ),
                child: const Icon(
                  Icons.phone_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7, right: 10),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: CAppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: CAppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
