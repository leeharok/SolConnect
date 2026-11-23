import 'package:material_ui/material_ui.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  UserRole? _selected;
  bool _loading = false;

  Future<void> _next() async {
    final role = _selected;
    if (role == null) return;
    setState(() => _loading = true);
    try {
      // 저장되면 AuthGate가 프로필 작성 화면으로 전환
      await AuthScope.read(context).setRole(role);
    } on AuthException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('역할 선택'),
        actions: [
          TextButton(
            onPressed: () => AuthScope.read(context).logout(),
            child: const Text('나가기', style: TextStyle(color: AppColors.textSub)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepDots(current: 1),
              const SizedBox(height: 28),
              const Text(
                '솔커넥트에서\n어떤 역할로 함께할까요?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              const Text('선택한 역할은 가입 후 바꿀 수 없어요.',
                  style: AppTextStyles.caption),
              const SizedBox(height: 24),
              _RoleCard(
                icon: Icons.edit_note_rounded,
                title: '멘티',
                subtitle: '나주 지역 초·중·고 학생',
                description: '모르는 문제를 찍어 올리고\n대학생 멘토에게 설명을 들어요.',
                selected: _selected == UserRole.mentee,
                onTap: () => setState(() => _selected = UserRole.mentee),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.school_rounded,
                title: '멘토',
                subtitle: 'KENTECH 재학생',
                description: '학생들의 질문에 답하고\n포인트와 봉사시간을 받아요.',
                selected: _selected == UserRole.mentor,
                onTap: () => setState(() => _selected = UserRole.mentor),
              ),
              const Spacer(),
              PrimaryButton(
                label: '다음',
                loading: _loading,
                onPressed: _selected == null ? null : _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accent
                      : AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: selected ? AppColors.primary : AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: selected ? AppColors.white : AppColors.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? AppColors.accent
                                : AppColors.textSub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: selected
                            ? AppColors.white.withValues(alpha: 0.85)
                            : AppColors.textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.accent : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
