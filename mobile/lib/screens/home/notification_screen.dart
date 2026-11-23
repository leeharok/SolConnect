import 'package:material_ui/material_ui.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import 'chat_room_screen.dart';
import 'point_history_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({
    super.key,
    required this.user,
    this.onUnreadCountChanged,
  });

  final AppUser user;
  final VoidCallback? onUnreadCountChanged;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ChatService _chatService = ChatService();

  List<Map<String, dynamic>> _notifications = [];

  bool _loading = true;
  bool _working = false;
  String? _error;
  String? _token;
  int _unreadCount = 0;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final token = await AuthScope.read(context).getAccessToken();

      if (token == null || token.isEmpty) {
        throw const NotificationException('로그인이 필요해요.');
      }

      _token = token;

      final result = await NotificationService.getMyNotifications(
        token: token,
      );

      final raw = result['notifications'];
      final items = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _notifications = items;
        _unreadCount =
            result['unreadCount'] is int ? result['unreadCount'] as int : 0;
        _loading = false;
        _error = null;
      });

      widget.onUnreadCountChanged?.call();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    if (_token == null || _unreadCount == 0 || _working) return;

    setState(() => _working = true);

    try {
      await NotificationService.markAllAsRead(token: _token!);

      if (!mounted) return;

      final readAt = DateTime.now().toIso8601String();

      setState(() {
        _notifications = _notifications.map((item) {
          return {
            ...item,
            'readAt': item['readAt'] ?? readAt,
          };
        }).toList();
        _unreadCount = 0;
      });

      widget.onUnreadCountChanged?.call();
    } on NotificationException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _markOneAsRead(
    Map<String, dynamic> notification,
  ) async {
    if (notification['readAt'] != null) return;

    final id = notification['id'] as String?;
    if (id == null || _token == null) return;

    await NotificationService.markAsRead(
      token: _token!,
      notificationId: id,
    );

    if (!mounted) return;

    final readAt = DateTime.now().toIso8601String();

    setState(() {
      _notifications = _notifications.map((item) {
        if (item['id'] == id) {
          return {
            ...item,
            'readAt': readAt,
          };
        }
        return item;
      }).toList();

      if (_unreadCount > 0) _unreadCount--;
    });

    widget.onUnreadCountChanged?.call();
  }

  Future<void> _openNotification(
    Map<String, dynamic> notification,
  ) async {
    if (_working || _token == null) return;

    setState(() => _working = true);

    try {
      await _markOneAsRead(notification);

      if (!mounted) return;

      final notificationType = notification['type'] as String?;

      // 후기 등록 알림은 포인트 내역으로 이동
      if (notificationType == 'REVIEW_SUBMITTED') {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const PointHistoryScreen(),
          ),
        );

        if (!mounted) return;

        await _loadNotifications(showLoading: false);
        return;
      }

      // 채팅방과 연결되는 알림
      const chatNotificationTypes = {
        'QUESTION_MATCHED',
        'CHAT_MESSAGE',
        'COMPLETION_REQUESTED',
      };

      if (!chatNotificationTypes.contains(notificationType)) {
        _showMessage('연결된 화면을 아직 준비하고 있어요.');
        return;
      }

      final chatRoomId = notification['chatRoomId'] as String?;

      if (chatRoomId == null || chatRoomId.isEmpty) {
        _showMessage('연결된 채팅방 정보가 없어요.');
        return;
      }

      final rooms = await _chatService.getMyChatRooms(
        token: _token!,
      );

      Map<String, dynamic>? matchedRoom;

      for (final room in rooms) {
        if (room['id'] == chatRoomId) {
          matchedRoom = room;
          break;
        }
      }

      if (!mounted) return;

      if (matchedRoom == null) {
        _showMessage('연결된 채팅방은 현재 채팅 목록에서 확인할 수 없어요.');
        return;
      }

      final partner = matchedRoom['partner'] is Map
          ? Map<String, dynamic>.from(matchedRoom['partner'])
          : <String, dynamic>{};

      final question = matchedRoom['question'] is Map
          ? Map<String, dynamic>.from(matchedRoom['question'])
          : <String, dynamic>{};

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChatRoomScreen(
            chatRoomId: chatRoomId,
            partnerName: partner['name'] as String? ?? '상대방',
            subject: question['subject'] as String? ?? '멘토링',
            user: widget.user,
            initialQuestion: question,
            initialChatStatus: matchedRoom!['status'] as String? ?? 'ACTIVE',
          ),
        ),
      );

      if (!mounted) return;

      await _loadNotifications(showLoading: false);
    } on NotificationException catch (error) {
      if (mounted) _showMessage(error.message);
    } on ChatException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('알림을 열지 못했어요.');
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
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

  IconData _iconFor(String? type) {
    switch (type) {
      case 'QUESTION_MATCHED':
        return Icons.people_alt_outlined;
      case 'CHAT_MESSAGE':
        return Icons.chat_bubble_outline_rounded;
      case 'COMPLETION_REQUESTED':
        return Icons.check_circle_outline_rounded;
      case 'REVIEW_SUBMITTED':
        return Icons.stars_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final isUnread = item['readAt'] == null;
    final title = item['title'] as String? ?? '알림';
    final body = item['body'] as String? ?? '';
    final date = _formatDate(item['createdAt']);

    return InkWell(
      onTap: _working ? null : () => _openNotification(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread
                ? AppColors.primary.withValues(alpha: 0.25)
                : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconFor(item['type'] as String?),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isUnread ? FontWeight.w800 : FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(top: 5, left: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: AppTextStyles.caption,
                  ),
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSub,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.hint,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _unreadCount > 0 ? '읽지 않은 알림 $_unreadCount개' : '모든 알림을 확인했어요',
                  style: AppTextStyles.caption,
                ),
              ),
              TextButton(
                onPressed:
                    _working || _unreadCount == 0 ? null : _markAllAsRead,
                child: const Text('모두 읽음'),
              ),
              IconButton(
                onPressed: _loading ? null : () => _loadNotifications(),
                tooltip: '새로고침',
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading && _notifications.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _notifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.caption,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadNotifications,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadNotifications(),
                      child: _notifications.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 110),
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 52,
                                  color: AppColors.hint,
                                ),
                                SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    '아직 도착한 알림이 없어요.',
                                    style: AppTextStyles.sectionTitle,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    '매칭이나 새 메시지가 도착하면 알려드릴게요.',
                                    style: AppTextStyles.caption,
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                return _buildNotificationCard(
                                  _notifications[index],
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }
}
