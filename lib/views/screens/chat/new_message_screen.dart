import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cwc/controllers/auth_controller.dart';
import 'package:cwc/services/chat_service.dart';
import 'package:cwc/utils/helpers/model_helpers.dart';
import 'package:cwc/utils/themes/theme.dart';
import 'package:cwc/views/screens/chat/chat_screen.dart';

/// Search users by name/email and start a direct chat.
class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final _chatService = ChatService();
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    final currentUserId = context.read<AuthController>().currentUser?.id;
    if (currentUserId == null) return;

    final q = value.trim();
    if (q.length < 2) {
      if (mounted) setState(() => _results = []);
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final rows = await _chatService.searchUsersForChat(q, excludeUserId: currentUserId);
      if (!mounted) return;
      setState(() {
        _results = rows;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _startChat(String otherUserId) async {
    final currentUserId = context.read<AuthController>().currentUser?.id;
    if (currentUserId == null) return;

    try {
      final room = await _chatService.getOrCreateChatRoom(
        user1Id: currentUserId,
        user2Id: otherUserId,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(chatRoomId: room.id)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: CAppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CAppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('New Message', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: CAppTheme.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _results = []);
                            },
                          )
                        : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(fontSize: 13, color: CAppTheme.errorColor),
              ),
            ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final q = _searchController.text.trim();
    if (q.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Type at least 2 characters to find people to message.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: CAppTheme.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    if (_results.isEmpty && !_isSearching) {
      return Center(
        child: Text(
          'No users found',
          style: GoogleFonts.poppins(color: CAppTheme.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _results[index];
        final name = user['name']?.toString() ?? 'User';
        final email = user['email']?.toString() ?? '';
        final role = user['role']?.toString() ?? 'user';
        final profession = user['profession']?.toString();
        final imageUrl = user['profile_image_url']?.toString();

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
          child: InkWell(
            onTap: () => _startChat(user['id'] as String),
            borderRadius: BorderRadius.circular(CAppTheme.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: CAppTheme.primaryColor.withValues(alpha: 0.1),
                    backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : null,
                    child: imageUrl == null || imageUrl.isEmpty
                        ? Text(
                            safeInitial(name),
                            style: GoogleFonts.poppins(
                              color: CAppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (profession != null && profession.isNotEmpty)
                          Text(
                            profession,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: CAppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else if (email.isNotEmpty)
                          Text(
                            email,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: CAppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: role == 'owner'
                          ? const Color(0xFFEF8B2C).withValues(alpha: 0.1)
                          : CAppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(CAppTheme.radiusSmall),
                    ),
                    child: Text(
                      role == 'owner' ? 'Owner' : 'User',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: role == 'owner'
                            ? const Color(0xFFEF8B2C)
                            : CAppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
