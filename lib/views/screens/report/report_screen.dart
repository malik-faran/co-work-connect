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
  final _descriptionController = TextEditingController();
  final _reportService = ReportService();
  final _storageService = StorageService();
  final _picker = ImagePicker();

  late String _reportType;
  late final List<MapEntry<String, String>> _reasonOptions;
  final List<String> _evidenceUrls = [];
  bool _submitting = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _reasonOptions = UserReportModel.reasonsFor(
      reportedUserId: widget.reportedUserId,
      workspaceId: widget.workspaceId,
      bookingId: widget.bookingId,
    );
    _reportType = _reasonOptions.first.key;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String get _defaultSubject {
    final label = _reasonOptions
        .firstWhere((e) => e.key == _reportType, orElse: () => _reasonOptions.last)
        .value;
    final about = widget.reportedUserName ??
        widget.workspaceName ??
        UserReportModel.contextLabel(
          reportedUserId: widget.reportedUserId,
          workspaceId: widget.workspaceId,
          bookingId: widget.bookingId,
        );
    return '$label — $about';
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

    setState(() => _submitting = true);
    try {
      await _reportService.submitReport(
        reporterId: user.id,
        reporterRole: role,
        reportType: _reportType,
        subject: _defaultSubject,
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
    final contextLabel = UserReportModel.contextLabel(
      reportedUserId: widget.reportedUserId,
      workspaceId: widget.workspaceId,
      bookingId: widget.bookingId,
    );

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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CAppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report category',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: CAppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contextLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.reportedUserName != null ||
                        widget.workspaceName != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'About',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: CAppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.reportedUserName ?? widget.workspaceName ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'What is the issue?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Select the reason that best describes your concern',
                style: GoogleFonts.poppins(fontSize: 12.5, color: CAppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              ..._reasonOptions.map((option) {
                final selected = _reportType == option.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected
                        ? CAppTheme.primaryColor.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    child: InkWell(
                      onTap: () => setState(() => _reportType = option.key),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                          border: Border.all(
                            color: selected
                                ? CAppTheme.primaryColor
                                : CAppTheme.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 20,
                              color: selected
                                  ? CAppTheme.primaryColor
                                  : CAppTheme.textTertiary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                option.value,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight:
                                      selected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Describe what happened *',
                  hintText: 'Include dates, messages, or other details...',
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
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
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
