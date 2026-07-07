import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/models/collaboration_hub_models.dart';
import 'package:cwc/models/user_model.dart';
import 'package:cwc/services/auth_service.dart';
import 'package:cwc/services/collaboration_hub_service.dart';
import 'package:cwc/services/storage_service.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/widgets/collaboration_widgets.dart';

/// CRUD editor for the current user's portfolio items.
class PortfolioEditorScreen extends StatefulWidget {
  const PortfolioEditorScreen({super.key});

  @override
  State<PortfolioEditorScreen> createState() => _PortfolioEditorScreenState();
}

class _PortfolioEditorScreenState extends State<PortfolioEditorScreen> {
  final _hub = CollaborationHubService();
  final _auth = AuthService();
  final _storage = StorageService();
  List<PortfolioItem> _items = [];
  bool _loading = true;
  bool _resumeUploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    final items = await _hub.getPortfolio(user.id);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(title: const Text('My Portfolio')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editItem(null),
        icon: const Icon(Icons.add),
        label: const Text('Add work'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CAppTheme.primaryColor))
          : _items.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: [
                    _resumeSection(context.watch<AuthController>().currentUser),
                    const SizedBox(height: 16),
                    EmptyState(
                      icon: Icons.work_outline_rounded,
                      title: 'Build your portfolio',
                      subtitle: 'Showcase your best work so teams pick you faster.',
                      action: ElevatedButton.icon(
                        onPressed: () => _editItem(null),
                        icon: const Icon(Icons.add),
                        label: const Text('Add your first item'),
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: [
                    _resumeSection(context.watch<AuthController>().currentUser),
                    const SizedBox(height: 8),
                    Text('Portfolio work',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ..._items.map(_card),
                  ],
                ),
    );
  }

  Widget _resumeSection(UserModel? user) {
    final hasResume = user?.resumeUrl != null && user!.resumeUrl!.isNotEmpty;
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                ),
                child: const Icon(Icons.description_rounded, color: CAppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Resume / CV',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(
                      hasResume
                          ? (user.resumeFileName ?? 'Resume uploaded')
                          : 'Upload PDF, DOC, or DOCX (max 10 MB)',
                      style: GoogleFonts.poppins(fontSize: 12.5, color: CAppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_resumeUploading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: CAppTheme.primaryColor),
              ),
            )
          else if (hasResume) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(user.resumeUrl!);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickAndUploadResume,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Replace'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove resume',
                  onPressed: _removeResume,
                  icon: const Icon(Icons.delete_outline_rounded, color: CAppTheme.errorColor),
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickAndUploadResume,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Upload resume'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadResume() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final fileName = file.name;
      if (!StorageService.isAllowedResume(fileName)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only PDF, DOC, and DOCX files are allowed')),
        );
        return;
      }
      final bytes = file.bytes;
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected file')),
        );
        return;
      }
      setState(() => _resumeUploading = true);
      final url = await _storage.uploadResume(
        userId: user.id,
        bytes: bytes,
        fileName: fileName,
      );
      final updated = await _auth.updateResume(
        userId: user.id,
        resumeUrl: url,
        resumeFileName: fileName,
      );
      if (!mounted) return;
      context.read<AuthController>().setCurrentUser(updated);
      setState(() => _resumeUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume uploaded'), backgroundColor: CAppTheme.successColor),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _resumeUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _removeResume() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove resume?'),
        content: const Text('Your uploaded resume will be removed from your portfolio.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: CAppTheme.errorColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      setState(() => _resumeUploading = true);
      final updated = await _auth.clearResume(user.id);
      if (!mounted) return;
      context.read<AuthController>().setCurrentUser(updated);
      setState(() => _resumeUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume removed'), backgroundColor: CAppTheme.successColor),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _resumeUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Widget _card(PortfolioItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                child: Image.network(item.imageUrl!, width: 56, height: 56, fit: BoxFit.cover),
              )
            else
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: CAppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                ),
                child: const Icon(Icons.work_rounded, color: CAppTheme.primaryColor),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  if (item.description != null && item.description!.isNotEmpty)
                    Text(item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12.5, color: CAppTheme.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20, color: CAppTheme.primaryColor),
              onPressed: () => _editItem(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: CAppTheme.textTertiary),
              onPressed: () async {
                await _hub.deletePortfolioItem(item.id);
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editItem(PortfolioItem? existing) async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    final result = await showModalBottomSheet<PortfolioItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PortfolioForm(existing: existing, userId: user.id),
    );
    if (result == null) return;
    await _hub.savePortfolioItem(result);
    _load();
  }
}

class _PortfolioForm extends StatefulWidget {
  final PortfolioItem? existing;
  final String userId;
  const _PortfolioForm({required this.existing, required this.userId});

  @override
  State<_PortfolioForm> createState() => _PortfolioFormState();
}

class _PortfolioFormState extends State<_PortfolioForm> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _url;
  late final TextEditingController _skillInput;
  late List<String> _skills;
  late String? _imageUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _desc = TextEditingController(text: existing?.description ?? '');
    _url = TextEditingController(text: existing?.projectUrl ?? '');
    _skillInput = TextEditingController();
    _skills = existing == null ? [] : List<String>.from(existing!.skills);
    _imageUrl = existing?.imageUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _url.dispose();
    _skillInput.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;
      setState(() => _uploading = true);
      final bytes = await picked.readAsBytes();
      final url = await StorageService().uploadCollaborationFile(
        collaborationId: 'portfolio_${widget.userId}',
        bytes: bytes,
        fileName: picked.name,
      );
      setState(() {
        _imageUrl = url;
        _uploading = false;
      });
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CAppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.existing == null ? 'Add portfolio item' : 'Edit portfolio item',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _uploading ? null : _pickImage,
                child: Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: CAppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(CAppTheme.radiusMedium),
                    image: _imageUrl != null && _imageUrl!.isNotEmpty
                        ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _uploading
                      ? const Center(child: CircularProgressIndicator())
                      : (_imageUrl == null || _imageUrl!.isEmpty)
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate_rounded,
                                    size: 32, color: CAppTheme.textTertiary),
                                const SizedBox(height: 6),
                                Text('Add cover image',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, color: CAppTheme.textSecondary)),
                              ],
                            )
                          : null,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'Project link (optional)',
                  hintText: 'https://github.com/...',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _skillInput,
                decoration: InputDecoration(
                  labelText: 'Add skill',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final s = _skillInput.text.trim();
                      if (s.isNotEmpty && !_skills.contains(s)) {
                        setState(() {
                          _skills.add(s);
                          _skillInput.clear();
                        });
                      }
                    },
                  ),
                ),
                onSubmitted: (s) {
                  if (s.trim().isNotEmpty && !_skills.contains(s.trim())) {
                    setState(() {
                      _skills.add(s.trim());
                      _skillInput.clear();
                    });
                  }
                },
              ),
              if (_skills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skills
                      .map((s) => Chip(
                            label: Text(s),
                            onDeleted: () => setState(() => _skills.remove(s)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_title.text.trim().isEmpty) return;
                    final link = _url.text.trim();
                    if (link.isNotEmpty) {
                      final uri = Uri.tryParse(link);
                      final valid = uri != null &&
                          uri.hasScheme &&
                          (uri.scheme == 'http' || uri.scheme == 'https') &&
                          uri.host.isNotEmpty;
                      if (!valid) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Project link must be a valid URL (https://...)'),
                          ),
                        );
                        return;
                      }
                    }
                    Navigator.pop(
                      context,
                      PortfolioItem(
                        id: widget.existing?.id ?? const Uuid().v4(),
                        userId: widget.userId,
                        title: _title.text.trim(),
                        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                        imageUrl: _imageUrl,
                        projectUrl: _url.text.trim().isEmpty ? null : _url.text.trim(),
                        skills: _skills,
                        sortOrder: widget.existing?.sortOrder ?? 0,
                        createdAt: widget.existing?.createdAt ?? DateTime.now(),
                      ),
                    );
                  },
                  child: Text(widget.existing == null ? 'Add to portfolio' : 'Save changes'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
