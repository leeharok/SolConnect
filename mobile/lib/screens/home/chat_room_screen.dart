import 'dart:convert';
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import 'review_screen.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.chatRoomId,
    required this.partnerName,
    required this.subject,
    required this.user,
    this.initialQuestion = const {},
    this.initialChatStatus = 'ACTIVE',
  });

  final String chatRoomId;
  final String partnerName;
  final String subject;
  final AppUser user;
  final Map<String, dynamic> initialQuestion;
  final String initialChatStatus;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _readSubscription;
  StreamSubscription<Map<String, dynamic>>? _completedSubscription;
  StreamSubscription<Map<String, dynamic>>? _completionRequestedSubscription;
  StreamSubscription<Map<String, dynamic>>? _completionResponseSubscription;

  List<Map<String, dynamic>> _messages = [];

  bool _loading = true;
  bool _sending = false;
  bool _completed = false;
  bool _completionResponding = false;
  bool _reviewOpened = false;

  String _chatStatus = 'ACTIVE';

  String? _error;
  String? _token;

  @override
  void initState() {
    super.initState();
    _chatStatus = widget.initialChatStatus;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_token == null && _loading) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    try {
      final token = await AuthScope.read(context).getAccessToken();

      if (token == null || token.isEmpty) {
        throw const ChatException('로그인이 필요해요.');
      }

      // 임시 인증 진단: JWT 원문은 출력하지 않음
      final tokenParts = token.split('.');
      if (tokenParts.length != 3) {
        throw const ChatException('인증 토큰 형식이 올바르지 않아요.');
      }

      final payload = jsonDecode(
        utf8.decode(
          base64Url.decode(base64Url.normalize(tokenParts[1])),
        ),
      ) as Map<String, dynamic>;

      final tokenUserId = payload['sub'];
      final tokenRole = payload['role'];

      debugPrint(
        'CHAT AUTH DIAGNOSTIC: '
        'screenUserId=${widget.user.id}, '
        'tokenUserId=$tokenUserId, '
        'tokenRole=$tokenRole',
      );

      if (tokenUserId != widget.user.id) {
        throw const ChatException(
          '로그인 계정과 채팅 인증 정보가 일치하지 않아요. 다시 로그인해 주세요.',
        );
      }

      _token = token;

      // 이미 상담이 종료되고 후기를 기다리는 상태인지 확인
      final reviewPending = widget.user.role == UserRole.mentee &&
          widget.initialQuestion['status'] == 'WAITING_REVIEW';

      if (reviewPending) {
        // 종료된 채팅방은 Socket.IO에 입장하지 않고
        // REST API로 기존 대화 기록만 불러오기
        final history = await _chatService.getMessages(
          token: token,
          chatRoomId: widget.chatRoomId,
        );

        if (!mounted) return;

        setState(() {
          _messages = _mergeMessages(_messages, history);
          _completed = true;
          _chatStatus = 'COMPLETED';
          _loading = false;
          _error = null;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_openReviewScreen());
          }
        });

        return;
      }

      // 진행 중인 채팅방만 실시간 연결
      await _chatService.connect(token: token);

      _messageSubscription = _chatService.messages.listen(_onMessage);

      _readSubscription = _chatService.readEvents.listen(_onRead);

      _completedSubscription =
          _chatService.completedEvents.listen(_onCompleted);

      _completionRequestedSubscription =
          _chatService.completionRequestedEvents.listen(
        _onCompletionRequested,
      );

      _completionResponseSubscription =
          _chatService.completionResponseEvents.listen(
        _onCompletionResponse,
      );

      // 채팅방 참여자 확인 및 입장
      await _chatService.joinChatRoom(
        chatRoomId: widget.chatRoomId,
      );

      // 이전 메시지 불러오기
      final history = await _chatService.getMessages(
        token: token,
        chatRoomId: widget.chatRoomId,
      );

      if (!mounted) return;

      setState(() {
        _messages = _mergeMessages(_messages, history);
        _loading = false;
        _error = null;
      });

      // 상대방이 보낸 메시지 읽음 처리
      await _markAsRead();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<Map<String, dynamic>> _mergeMessages(
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> incoming,
  ) {
    final result = <String, Map<String, dynamic>>{};

    for (final message in [...current, ...incoming]) {
      final id = message['id'] as String?;
      if (id == null) continue;

      final previous = result[id];

      if (previous == null) {
        result[id] = Map<String, dynamic>.from(message);
      } else {
        final merged = {
          ...previous,
          ...message,
        };

        if (message['readAt'] == null && previous['readAt'] != null) {
          merged['readAt'] = previous['readAt'];
        }

        result[id] = merged;
      }
    }

    final messages = result.values.toList();

    messages.sort((a, b) {
      final dateA =
          DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(1970);
      final dateB =
          DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(1970);

      return dateA.compareTo(dateB);
    });

    return messages;
  }

  void _onMessage(Map<String, dynamic> message) {
    if (message['chatRoomId'] != widget.chatRoomId) return;

    if (!mounted) return;

    setState(() {
      _messages = _mergeMessages(_messages, [message]);
    });

    _scrollToBottom();

    // 상대방 메시지가 오면 읽음 처리
    if (message['senderId'] != widget.user.id) {
      unawaited(_markAsRead());
    }
  }

  void _onRead(Map<String, dynamic> event) {
    if (event['chatRoomId'] != widget.chatRoomId) return;
    if (event['readerId'] == widget.user.id) return;

    final readAt = event['readAt'];

    if (!mounted) return;

    setState(() {
      _messages = _messages.map((message) {
        if (message['senderId'] == widget.user.id) {
          return {
            ...message,
            'readAt': readAt,
          };
        }
        return message;
      }).toList();
    });
  }

  void _onCompleted(Map<String, dynamic> event) {
    if (event['chatRoomId'] != widget.chatRoomId) return;
    if (!mounted) return;

    setState(() {
      _completed = true;
      _chatStatus = 'COMPLETED';
    });

    // 멘티에게만 후기 작성 화면 자동 표시
    if (widget.user.role == UserRole.mentee) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_openReviewScreen());
        }
      });
    }
  }

  // 멘토가 풀이 전달 완료를 요청했을 때
  void _onCompletionRequested(Map<String, dynamic> event) {
    if (event['chatRoomId'] != widget.chatRoomId) return;
    if (!mounted || _completed) return;

    setState(() {
      _chatStatus = 'COMPLETION_REQUESTED';
    });
  }

  // 멘티가 아직 해결되지 않았다고 응답했을 때
  void _onCompletionResponse(Map<String, dynamic> event) {
    if (event['chatRoomId'] != widget.chatRoomId) return;
    if (event['resolved'] != false || !mounted) return;

    setState(() {
      _chatStatus = 'ACTIVE';
    });

    if (widget.user.role == UserRole.mentor) {
      _showMessage('멘티가 추가 설명을 요청했어요. 상담을 계속해 주세요.');
    }
  }

  // 후기 작성 화면 열기
  Future<void> _openReviewScreen() async {
    if (_reviewOpened || !mounted) return;

    _reviewOpened = true;

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          chatRoomId: widget.chatRoomId,
          partnerName: widget.partnerName,
          user: widget.user,
        ),
      ),
    );

    if (!mounted) return;

    if (submitted == true) {
      // 후기 제출 후 채팅방 목록으로 복귀
      Navigator.of(context).pop();
    } else {
      // 나중에 다시 후기를 작성할 수 있도록 허용
      _reviewOpened = false;
    }
  }

  Future<void> _markAsRead() async {
    try {
      await _chatService.markAsRead(
        chatRoomId: widget.chatRoomId,
      );
    } catch (_) {
      // 읽음 처리 실패가 채팅 이용을 막지는 않도록 함
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty || _sending || _completed || _chatStatus != 'ACTIVE') {
      return;
    }

    setState(() => _sending = true);

    try {
      final result = await _chatService.sendMessage(
        chatRoomId: widget.chatRoomId,
        content: content,
      );

      final data = result['data'];

      if (data is Map) {
        final message = Map<String, dynamic>.from(data);

        if (mounted) {
          setState(() {
            _messages = _mergeMessages(_messages, [message]);
          });
        }
      }

      if (mounted && _messageController.text.trim() == content) {
        _messageController.clear();
      }

      _scrollToBottom();
    } on ChatException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('메시지를 보내지 못했어요.');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  // 멘토가 풀이 전달 완료를 요청
  Future<void> _requestChatCompletion() async {
    if (widget.user.role != UserRole.mentor ||
        _chatStatus != 'ACTIVE' ||
        _token == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('풀이 전달 완료'),
        content: const Text(
          '풀이 전달을 마쳤나요?\n'
          '요청 후 멘티가 문제 해결 여부를 확인해요. '
          '아직 해결되지 않았다면 다시 상담을 이어갈 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('완료 요청'),
          ),
        ],
      ),
    );

    if (confirmed != true || _token == null) return;

    try {
      await _chatService.requestChatCompletion(
        token: _token!,
        chatRoomId: widget.chatRoomId,
      );

      if (!mounted) return;

      setState(() {
        _chatStatus = 'COMPLETION_REQUESTED';
      });

      _showMessage('멘티의 문제 해결 확인을 기다리고 있어요.');
    } on ChatException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('완료 요청 중 오류가 발생했어요.');
    }
  }

  // 멘티가 문제 해결 여부를 선택
  Future<void> _confirmChatCompletion(bool resolved) async {
    if (widget.user.role != UserRole.mentee ||
        _chatStatus != 'COMPLETION_REQUESTED' ||
        _completionResponding ||
        _token == null) {
      return;
    }

    setState(() {
      _completionResponding = true;
    });

    try {
      await _chatService.confirmChatCompletion(
        token: _token!,
        chatRoomId: widget.chatRoomId,
        resolved: resolved,
      );

      if (!mounted) return;

      if (resolved) {
        // 서버에서 완료 이벤트를 받지 못하는 경우에도 화면을 갱신
        _onCompleted({
          'chatRoomId': widget.chatRoomId,
          'status': 'COMPLETED',
        });
      } else {
        setState(() {
          _chatStatus = 'ACTIVE';
        });

        _showMessage('추가 설명을 요청했어요. 멘토와 대화를 이어가세요.');
      }
    } on ChatException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('응답을 전달하는 중 오류가 발생했어요.');
    } finally {
      if (mounted) {
        setState(() {
          _completionResponding = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(dynamic value) {
    if (value is! String) return '';

    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // 멘티가 최초 등록한 문제를 채팅의 첫 번째 말풍선으로 표시

  // 사진 클릭 시 확대해서 보여주는 화면
  Future<void> _showExpandedImage(String imageUrl) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(dialogContext).size.height * 0.82,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    child: Center(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Text(
                            '사진을 불러오지 못했어요.',
                            style: TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 최초 질문 사진을 채팅 말풍선으로 표시
  Widget _buildInitialQuestion() {
    final rawImages = widget.initialQuestion['images'];

    final images = rawImages is List
        ? rawImages
            .whereType<Map>()
            .map((image) => Map<String, dynamic>.from(image))
            .toList()
        : <Map<String, dynamic>>[];

    final content = widget.initialQuestion['content'] as String? ?? '';

    final curriculum = widget.initialQuestion['curriculum'] as String?;

    final isMentee = widget.user.role == UserRole.mentee;

    if (images.isEmpty &&
        content.trim().isEmpty &&
        (curriculum == null || curriculum.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: isMentee ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMentee ? AppColors.primary : AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMentee ? 16 : 4),
              bottomRight: Radius.circular(isMentee ? 4 : 16),
            ),
            border: isMentee ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (images.isNotEmpty)
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final storagePath =
                          images[index]['storagePath'] as String?;

                      if (storagePath == null || storagePath.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final imageUrl = Uri.parse(ApiService.baseUrl)
                          .resolve(storagePath)
                          .toString();

                      return GestureDetector(
                        onTap: () => _showExpandedImage(imageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 220,
                            height: 190,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 220,
                                height: 190,
                                color: AppColors.placeholder,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.textSub,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (content.trim().isNotEmpty) ...[
                if (images.isNotEmpty) const SizedBox(height: 10),
                Text(
                  content,
                  style: TextStyle(
                    color: isMentee ? AppColors.white : AppColors.text,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              if (curriculum?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  '교육과정: $curriculum',
                  style: TextStyle(
                    color: isMentee ? Colors.white70 : AppColors.textSub,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isMine = message['senderId'] == widget.user.id;
    final content = message['content'] as String? ?? '';
    final time = _formatTime(message['createdAt']);
    final isRead = message['readAt'] != null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 5),
                child: Text(
                  widget.partnerName,
                  style: AppTextStyles.caption,
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isMine) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isRead ? '읽음' : '',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSub,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.68,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isMine ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMine ? 16 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 16),
                      ),
                      border:
                          isMine ? null : Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      content,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isMine ? AppColors.white : AppColors.text,
                      ),
                    ),
                  ),
                ),
                if (!isMine) ...[
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    if (_completed) {
      if (widget.user.role == UserRole.mentee) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppColors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '멘토링이 종료됐어요.',
                style: TextStyle(
                  color: AppColors.textSub,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openReviewScreen,
                  child: const Text('후기 작성하기'),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        color: AppColors.white,
        child: const Text(
          '종료된 멘토링입니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSub,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_chatStatus == 'COMPLETION_REQUESTED') {
      if (widget.user.role == UserRole.mentee) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppColors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '멘토가 풀이 전달 완료를 요청했어요.\n문제가 해결되었나요?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _completionResponding
                          ? null
                          : () => _confirmChatCompletion(false),
                      child: const Text('아직 해결되지 않았어요'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _completionResponding
                          ? null
                          : () => _confirmChatCompletion(true),
                      child: const Text('해결됐어요'),
                    ),
                  ),
                ],
              ),
              if (_completionResponding)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        );
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        color: AppColors.white,
        child: const Text(
          '멘티의 문제 해결 확인을 기다리고 있어요.\n'
          '확인이 끝나면 상담이 종료돼요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSub,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: '메시지를 입력하세요.',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              height: 46,
              child: IconButton.filled(
                onPressed: _sending || _loading ? null : _sendMessage,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.partnerName,
              style: AppTextStyles.title,
            ),
            Text(
              widget.subject,
              style: AppTextStyles.caption,
            ),
          ],
        ),
        actions: [
          if (widget.user.role == UserRole.mentor &&
              _chatStatus == 'ACTIVE' &&
              !_completed)
            IconButton(
              onPressed: _loading ? null : _requestChatCompletion,
              tooltip: '풀이 전달 완료',
              icon: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_completed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: AppColors.accent.withValues(alpha: 0.25),
              child: const Text(
                '멘토링이 종료됐어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
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
                                onPressed: () {
                                  setState(() {
                                    _loading = true;
                                    _error = null;
                                  });
                                  _initialize();
                                },
                                child: const Text('다시 연결하기'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          14,
                          18,
                          14,
                          20,
                        ),
                        itemCount: _messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildInitialQuestion();
                          }

                          return _buildMessage(_messages[index - 1]);
                        },
                      ),
          ),
          if (_error == null) _buildComposer(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _readSubscription?.cancel();
    _completedSubscription?.cancel();
    _completionRequestedSubscription?.cancel();
    _completionResponseSubscription?.cancel();

    _chatService.dispose();
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }
}
