import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/report_model.dart';
import 'package:cwc/services/report_service.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/utils/constants/app_constants.dart';
import 'package:cwc/utils/helpers/snackbar_helper.dart';
import 'package:cwc/utils/themes/theme.dart';

class ReportScreen extends StatefulWidget {
  final String? reportedUserId;
  final String? reportedUserName;
  final String? workspaceId;
  final String? workspaceName;
  final String? bookingId;

  const ReportScreen({
    super.key,
    this.reportedUserId,
    this.reportedUserName,
    this.workspaceId,
    this.workspaceName,
    this.bookingId,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _reportService = ReportService();
  final _storageService = StorageService();
  final _picker = ImagePicker();

  String _reportType = 'other';
  final List<String> _evidenceUrls = [];
  bool _submitting = false;
  bool _uploading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    if (_evidenceUrls.length >= 3) {
      showErrorSnackBar(context, 'Maximum 3 images allowed');
      return;
    }

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null) return;

    setState(() => _uploading = true);
    try {
      final url = await _storageService.uploadReportEvidence(
        userId: userId,
        file: picked,
      );
      if (mounted) {
        setState(() => _evidenceUrls.add(url));
        showSuccessSnackBar(context, 'Evidence uploaded');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    final role = user.role == AppConstants.roleOwner ? 'owner' : 'user';
    final subject = _subjectController.text.trim().isNotEmpty
        ? _subjectController.text.trim()
        : UserReportModel.typeLabels[_reportType] ?? 'Report';

    setState(() => _submitting = true);
    try {
      await _reportService.submitReport(
        reporterId: user.id,
        reporterRole: role,
        reportType: _reportType,
        subject: subject,
        description: _descriptionController.text.trim(),
        reportedUserId: widget.reportedUserId,
        workspaceId: widget.workspaceId,
        bookingId: widget.bookingId,
        evidenceUrls: _evidenceUrls,
      );

      if (!mounted) return;
      showSuccessSnackBar(context, 'Report submitted. Our team will review it.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Report Issue', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.reportedUserName != null ||
                  widget.workspaceName != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CAppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reporting about',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: CAppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.reportedUserName ?? widget.workspaceName ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'What is the issue?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _reportType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: UserReportModel.typeLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _reportType = v ?? 'other'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject (optional)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Describe the issue *',
                  hintText: 'Tell us what happened...',
                  filled: true,
                  fillColor: Colors.white,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 10) {
                    return 'Please provide at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Evidence (optional, max 3 images)',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._evidenceUrls.map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, width: 72, height: 72, fit: BoxFit.cover),
                    ),
                  ),
                  if (_evidenceUrls.length < 3)
                    InkWell(
                      onTap: _uploading ? null : _pickEvidence,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CAppTheme.borderColor),
                        ),
                        child: _uploading
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Submit Report',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
