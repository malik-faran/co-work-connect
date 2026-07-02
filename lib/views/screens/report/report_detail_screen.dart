import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/report_followup_model.dart';
import 'package:cwc/models/report_model.dart';
import 'package:cwc/services/report_service.dart';
import 'package:cwc/utils/themes/theme.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _reportService = ReportService();
  final _objectionController = TextEditingController();
  UserReportModel? _report;
  List<ReportFollowupModel> _followups = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _objectionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      final report = await _reportService.getReportById(widget.reportId, userId);
      final followups = report != null
          ? await _reportService.getFollowups(widget.reportId)
          : <ReportFollowupModel>[];
      if (!mounted) return;
      setState(() {
        _report = report;
        _followups = followups;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canObject =>
      _report != null &&
      (_report!.status == 'resolved' || _report!.status == 'dismissed');

  Future<void> _submitObjection() async {
    final text = _objectionController.text.trim();
    if (text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write at least 10 characters')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await _reportService.submitObjection(reportId: widget.reportId, message: text);
      if (!mounted) return;
      _objectionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your objection was sent. The report is under review again.'),
          backgroundColor: CAppTheme.successColor,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        title: Text('Report Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor))
          : _report == null
              ? Center(
                  child: Text('Report not found',
                      style: GoogleFonts.poppins(color: CAppTheme.textSecondary)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _headerCard(_report!),
                      const SizedBox(height: 14),
                      _sectionCard(
                        title: 'Your report',
                        icon: Icons.description_outlined,
                        child: Text(
                          _report!.description,
                          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
                        ),
                      ),
                      if (_report!.resolutionNote != null &&
                          _report!.resolutionNote!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'Team decision',
                          icon: Icons.gavel_rounded,
                          child: Text(
                            _report!.resolutionNote!,
                            style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
                          ),
                        ),
                      ],
                      if (_followups.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'Conversation',
                          icon: Icons.forum_outlined,
                          child: Column(
                            children: _followups.map(_followupBubble).toList(),
                          ),
                        ),
                      ],
                      if (_canObject) ...[
                        const SizedBox(height: 14),
                        _objectionCard(),
                      ] else if (_report!.status == 'under_review') ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: CAppTheme.infoColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded, color: CAppTheme.infoColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Our team is reviewing this report. You will be notified when there is an update.',
                                  style: GoogleFonts.poppins(fontSize: 13, height: 1.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _headerCard(UserReportModel report) {
    return Container(
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
                child: Text(report.subject,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor(report.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusRound),
                ),
                child: Text(report.statusLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(report.status),
                    )),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(report.typeLabel,
              style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text(
            'Submitted ${DateFormat('MMM d, yyyy · HH:mm').format(report.createdAt)}',
            style: GoogleFonts.poppins(fontSize: 12, color: CAppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
              Icon(icon, size: 20, color: CAppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _followupBubble(ReportFollowupModel f) {
    final isReporter = f.isReporter;
    return Align(
      alignment: isReporter ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isReporter
              ? CAppTheme.primaryColor.withValues(alpha: 0.1)
              : CAppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isReporter
                ? CAppTheme.primaryColor.withValues(alpha: 0.25)
                : CAppTheme.borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isReporter ? 'You' : 'Support team',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isReporter ? CAppTheme.primaryColor : CAppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(f.message, style: GoogleFonts.poppins(fontSize: 13.5, height: 1.45)),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, h:mm a').format(f.createdAt),
              style: GoogleFonts.poppins(fontSize: 10.5, color: CAppTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _objectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
        boxShadow: CAppTheme.softShadow,
        border: Border.all(color: CAppTheme.warningColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_outlined, color: CAppTheme.warningColor),
              const SizedBox(width: 8),
              Text('Disagree with the outcome?',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'If you believe this decision was incorrect, explain your concern professionally. We will reopen the review.',
            style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _objectionController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Your objection',
              hintText: 'Explain why you disagree and share any new details...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submitObjection,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Submit objection'),
            ),
          ),
        ],
      ),
    );
  }
}
