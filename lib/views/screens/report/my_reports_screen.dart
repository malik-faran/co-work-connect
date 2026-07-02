import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/report_model.dart';
import 'package:cwc/services/report_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/report/report_detail_screen.dart';
import 'package:cwc/views/screens/report/report_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final _reportService = ReportService();
  List<UserReportModel> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      final reports = await _reportService.getMyReports(userId);
      if (mounted) {
        setState(() {
          _reports = reports;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return CAppTheme.successColor;
      case 'dismissed':
        return CAppTheme.textTertiary;
      case 'under_review':
        return CAppTheme.infoColor;
      default:
        return CAppTheme.warningColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('My Reports', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final submitted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ReportScreen()),
          );
          if (submitted == true) _load();
        },
        icon: const Icon(Icons.flag_outlined),
        label: const Text('New Report'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_outlined, size: 56, color: CAppTheme.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'No reports yet',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Report issues, scams, or inappropriate behaviour.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      return InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReportDetailScreen(reportId: report.id),
                            ),
                          );
                          _load();
                        },
                        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                        child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                          boxShadow: CAppTheme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report.subject,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(report.status).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    report.statusLabel,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor(report.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              report.typeLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: CAppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              report.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 13.5),
                            ),
                            if (report.resolutionNote != null &&
                                report.resolutionNote!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: CAppTheme.successColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Team note: ${report.resolutionNote}',
                                  style: GoogleFonts.poppins(fontSize: 12.5),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('MMM d, yyyy · HH:mm').format(report.createdAt),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: CAppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      );
                    },
                  ),
                ),
    );
  }
}
