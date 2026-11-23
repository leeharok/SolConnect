import 'package:material_ui/material_ui.dart';

import '../../models/app_user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});
  final AppUser user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _bannerCount = 3;
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isMentor = user.role == UserRole.mentor;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        // 인사말
        Row(
          children: [
            const ProfileAvatar(size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.3,
                    color: AppColors.text,
                  ),
                  children: [
                    TextSpan(
                      text: user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const TextSpan(text: '님,\n'),
                    TextSpan(
                      text: isMentor ? '오늘도 화이팅하세요!' : '오늘도 열공하세요!',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 게시판
        const Row(
          children: [
            Icon(Icons.manage_search_rounded, size: 20, color: AppColors.text),
            SizedBox(width: 6),
            Text('게시판', style: AppTextStyles.sectionTitle),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _bannerCount,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Container(
              color: AppColors.placeholder,
              alignment: Alignment.center,
              child: Text('공지 배너 ${i + 1}',
                  style: const TextStyle(color: AppColors.textSub)),
            ),
          ),
        ),
        // 진행 표시 (노란 구간 + 초록 라인)
        LayoutBuilder(
          builder: (context, c) {
            final segment = c.maxWidth / _bannerCount;
            return SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(color: AppColors.primary),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    left: segment * _page,
                    width: segment,
                    top: 0,
                    bottom: 0,
                    child: Container(color: AppColors.accent),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // 메인 카드
        Container(
          constraints: const BoxConstraints(minHeight: 280),
          padding: const EdgeInsets.all(20),
          color: AppColors.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: isMentor ? _mentorSummary(user) : _menteeSummary(),
          ),
        ),
      ],
    );
  }

  List<Widget> _menteeSummary() => const [
        Text('최근 내 질문',
            style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        SizedBox(height: 12),
        Text('아직 등록한 질문이 없어요.\n하단의 질문하기로 첫 질문을 올려보세요!',
            style: TextStyle(color: Colors.white70, height: 1.5)),
      ];

  List<Widget> _mentorSummary(AppUser user) => [
        const Text('내 멘토링 현황',
            style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('보유 포인트',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(width: 8),
            Text('${user.points} P',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 16),
        const Text('답변을 기다리는 질문이 여기에 표시돼요.',
            style: TextStyle(color: Colors.white70)),
      ];
}
