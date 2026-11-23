import 'package:material_ui/material_ui.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/point_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../onboarding/profile_setup_screen.dart';
import 'point_history_screen.dart';
import 'received_reviews_screen.dart';
import 'my_questions_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  int? _latestPoints;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.user.role == UserRole.mentor) {
        _loadLatestPoints();
      }
    });
  }

  Future<void> _loadLatestPoints() async {
    try {
      final token = await AuthScope.read(context).getAccessToken();

      if (token == null || token.isEmpty) return;

      final result = await PointService.getMyTransactions(
        token: token,
      );

      final data = result['data'];

      if (data is! Map || data['balance'] is! num) return;

      if (!mounted) return;

      setState(() {
        _latestPoints = (data['balance'] as num).toInt();
      });
    } catch (_) {
      // 조회에 실패하면 기존 사용자 정보를 유지합니다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isMentee = user.role == UserRole.mentee;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        // 프로필 카드
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const ProfileAvatar(size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RoleChip(role: user.role!),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(user.email, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isMentee) ...[
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PointHistoryScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text(
                    '보유 포인트',
                    style: TextStyle(color: AppColors.white, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    '${_latestPoints ?? user.points} P',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text('내 정보', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 8),
        _InfoCard(
          rows: isMentee
              ? [
                  ('학교', user.schoolName ?? '-'),
                  (
                    '학년',
                    '${user.schoolLevel?.label ?? ''} ${user.grade ?? '-'}학년'
                  ),
                ]
              : [
                  ('학과', user.department ?? '-'),
                  ('학번', user.studentId ?? '-'),
                  ('소개', (user.bio?.isNotEmpty ?? false) ? user.bio! : '-'),
                ],
        ),
        if (isMentee) ...[
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MyQuestionsScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '내 질문',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '내가 등록한 질문과 멘토링 상태를 확인해요.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.hint,
                  ),
                ],
              ),
            ),
          ),
        ],
        if (!isMentee) ...[
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ReceivedReviewsScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.rate_review_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '받은 후기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '멘티들이 남긴 멘토링 후기를 확인해요.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.hint,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('멘토링 과목', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: user.subjects
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(s,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ProfileSetupScreen(editing: true),
          )),
          child: const Text('프로필 수정'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => AuthScope.read(context).logout(),
          child: const Text('로그아웃', style: TextStyle(color: AppColors.textSub)),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(rows[i].$1, style: AppTextStyles.caption),
                  ),
                  Expanded(
                    child: Text(rows[i].$2,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, color: AppColors.background),
          ],
        ],
      ),
    );
  }
}
