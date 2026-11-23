import 'package:material_ui/material_ui.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../onboarding/profile_setup_screen.dart';
import 'home_screen.dart';
import 'chat_list_screen.dart';
import 'my_page_screen.dart';
import 'notification_screen.dart';
import 'question_register_screen.dart';
import 'mentor_question_list_screen.dart';

enum _Tab { chat, alarm, ask, bookmark, myPage }

class _TabSpec {
  const _TabSpec(this.tab, this.icon, this.label);
  final _Tab tab;
  final IconData icon;
  final String label;
}

/// 홈 + 하단 탭바. 탭을 아무것도 선택하지 않은 상태가 홈 화면(디자인 기준).
/// 상단 로고를 누르거나 뒤로가기를 누르면 홈으로 돌아옵니다.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  _Tab? _current; // null = 홈

  final ChatService _chatService = ChatService();

  int _unreadChatCount = 0;
  int _unreadNotificationCount = 0;
  bool _unreadCountInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_unreadCountInitialized) {
      _unreadCountInitialized = true;
      _loadUnreadChatCount();
      _loadUnreadNotificationCount();
    }
  }

  Future<void> _loadUnreadChatCount() async {
    try {
      final token = await AuthScope.read(context).getAccessToken();

      if (!mounted) return;

      if (token == null || token.isEmpty) {
        setState(() => _unreadChatCount = 0);
        return;
      }

      final count = await _chatService.getUnreadCount(token: token);

      if (!mounted) return;

      setState(() {
        _unreadChatCount = count;
      });
    } catch (error) {
      debugPrint('안 읽은 채팅 수 조회 오류: $error');
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final token = await AuthScope.read(context).getAccessToken();

      if (!mounted) return;

      if (token == null || token.isEmpty) {
        setState(() => _unreadNotificationCount = 0);
        return;
      }

      final count = await NotificationService.getUnreadCount(
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _unreadNotificationCount = count;
      });
    } catch (error) {
      debugPrint('안 읽은 알림 수 조회 오류: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUnreadChatCount();
      _loadUnreadNotificationCount();
    }
  }

  List<_TabSpec> _tabsFor(UserRole role) => [
        const _TabSpec(_Tab.chat, Icons.chat_bubble_rounded, '채팅'),
        const _TabSpec(_Tab.alarm, Icons.notifications_rounded, '알림'),
        _TabSpec(
          _Tab.ask,
          role == UserRole.mentee
              ? Icons.photo_camera_rounded
              : Icons.search_rounded,
          role == UserRole.mentee ? '질문하기' : '질문 찾기',
        ),
        if (role == UserRole.mentor)
          const _TabSpec(_Tab.bookmark, Icons.bookmark_rounded, '북마크'),
        const _TabSpec(_Tab.myPage, Icons.home_rounded, '마이페이지'),
      ];

  void _goHome() => setState(() => _current = null);

  void _openSettings() {
    final auth = AuthScope.read(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: const Text('프로필 수정'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ProfileSetupScreen(editing: true),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title:
                  const Text('로그아웃', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                auth.logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).currentUser;
    if (user == null) return const SizedBox.shrink();
    final tabs = _tabsFor(user.role!);

    final Widget body = switch (_current) {
      null => HomeScreen(user: user),
      _Tab.chat => ChatListScreen(
          user: user,
          onChatRead: _loadUnreadChatCount,
        ),
      _Tab.alarm => NotificationScreen(
          user: user,
          onUnreadCountChanged: _loadUnreadNotificationCount,
        ),
      _Tab.ask => user.role == UserRole.mentee
          ? QuestionRegisterScreen(user: user)
          : const MentorQuestionListScreen(),
      _Tab.bookmark => const _EmptyTab(message: '북마크한 질문이 없어요.'),
      _Tab.myPage => MyPageScreen(user: user),
    };

    final title = _current == null
        ? null
        : tabs.firstWhere((t) => t.tab == _current).label;

    return PopScope(
      canPop: _current == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SolHeader(
                title: title,
                onTitleTap: _goHome,
                onSettings: _openSettings,
              ),
              Expanded(child: body),
            ],
          ),
        ),
        bottomNavigationBar: _SolBottomBar(
          tabs: tabs,
          current: _current,
          badges: {
            _Tab.chat: _unreadChatCount,
            _Tab.alarm: _unreadNotificationCount,
          },
          onTap: (t) {
            setState(() => _current = t);
            _loadUnreadChatCount();
            _loadUnreadNotificationCount();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatService.dispose();
    super.dispose();
  }
}

class _SolBottomBar extends StatelessWidget {
  const _SolBottomBar({
    required this.tabs,
    required this.current,
    required this.badges,
    required this.onTap,
  });

  final List<_TabSpec> tabs;
  final _Tab? current;
  final Map<_Tab, int> badges;
  final ValueChanged<_Tab> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: tabs.map((t) {
              final selected = t.tab == current;
              final badge = badges[t.tab] ?? 0;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(t.tab),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(t.icon, color: AppColors.white, size: 26),
                          if (badge > 0)
                            Positioned(
                              right: -4,
                              top: -3,
                              child: CountBadge(count: badge),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? AppColors.accent : AppColors.white,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}
