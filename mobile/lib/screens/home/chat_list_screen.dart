import 'package:material_ui/material_ui.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import 'chat_room_screen.dart';
import '../../theme/app_theme.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.user,
    this.onChatRead,
  });

  final AppUser user;
  final VoidCallback? onChatRead;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();

  List<Map<String, dynamic>> _rooms = [];

  bool _loading = true;
  bool _initialized = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;
      _loadRooms();
    }
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await AuthScope.read(context).getAccessToken();

      if (token == null || token.isEmpty) {
        throw const ChatException('로그인이 필요해요.');
      }

      final rooms = await _chatService.getMyChatRooms(
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(dynamic value) {
    if (value is! String) return '';

    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';

    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }

    return '${date.month}/${date.day}';
  }

  String _schoolLabel(String? level) {
    switch (level) {
      case 'ELEMENTARY':
        return '초등학교';
      case 'MIDDLE':
        return '중학교';
      case 'HIGH':
        return '고등학교';
      default:
        return '학교';
    }
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final partner = room['partner'] is Map
        ? Map<String, dynamic>.from(room['partner'])
        : <String, dynamic>{};

    final question = room['question'] is Map
        ? Map<String, dynamic>.from(room['question'])
        : <String, dynamic>{};

    final lastMessage = room['lastMessage'] is Map
        ? Map<String, dynamic>.from(room['lastMessage'])
        : null;

    final partnerName = partner['name'] as String? ?? '상대방';
    final subject = question['subject'] as String? ?? '멘토링';
    final level = question['schoolLevel'] as String?;
    final grade = question['grade'];

    final preview = lastMessage == null
        ? '대화를 시작해 보세요.'
        : (lastMessage['content'] as String? ?? '');

    final time = lastMessage == null
        ? _formatDate(room['updatedAt'])
        : _formatDate(lastMessage['createdAt']);

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      onTap: () async {
        final chatRoomId = room['id'] as String?;

        if (chatRoomId == null || chatRoomId.isEmpty) return;

        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ChatRoomScreen(
              chatRoomId: chatRoomId,
              partnerName: partnerName,
              subject: subject,
              user: widget.user,
              initialQuestion: question,
              initialChatStatus: room['status'] as String? ?? 'ACTIVE',
            ),
          ),
        );

        if (!mounted) return;

        widget.onChatRead?.call();
        await _loadRooms();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppColors.primary,
              child: Text(
                partnerName.isNotEmpty ? partnerName.characters.first : '?',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          partnerName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: AppTextStyles.caption,
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$subject · ${_schoolLabel(level)} ${grade ?? ''}학년',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '진행 중인 멘토링',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _loadRooms,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.primary,
                ),
                tooltip: '새로고침',
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              size: 44,
                              color: AppColors.textSub,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadRooms,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRooms,
                      child: _rooms.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 110),
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 52,
                                  color: AppColors.hint,
                                ),
                                SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    '아직 진행 중인 채팅이 없어요.',
                                    style: AppTextStyles.sectionTitle,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    '멘토링이 매칭되면 여기에 표시돼요.',
                                    style: AppTextStyles.caption,
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                4,
                                16,
                                24,
                              ),
                              itemCount: _rooms.length,
                              itemBuilder: (context, index) {
                                return _buildRoomCard(
                                  _rooms[index],
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }
}
