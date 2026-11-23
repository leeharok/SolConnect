import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text('솔커넥트', style: AppTextStyles.logo(size: size));
}

/// 로딩 상태를 가진 메인 버튼
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.white,
              ),
            )
          : Text(label),
    );
  }
}

/// 라벨 + 입력창
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// 원형 아바타 (디자인: 초록 테두리 + 사람 아이콘)
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        border: Border.all(color: AppColors.primary, width: size / 24),
      ),
      child: Icon(
        Icons.person_outline_rounded,
        size: size * 0.62,
        color: AppColors.primary,
      ),
    );
  }
}

/// 탭 화면 상단 헤더: 제목(또는 로고) + 설정 아이콘
class SolHeader extends StatelessWidget {
  const SolHeader({super.key, this.title, this.onTitleTap, this.onSettings});
  final String? title;
  final VoidCallback? onTitleTap;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTitleTap,
            child: title == null
                ? const AppLogo(size: 20)
                : Text(title!, style: AppTextStyles.title),
          ),
          const Spacer(),
          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings, color: AppColors.primary),
            tooltip: '설정',
          ),
        ],
      ),
    );
  }
}

/// 노란 숫자 배지
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
          height: 1.1,
        ),
      ),
    );
  }
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error.toString())));
}

/// 회원가입 → 역할 선택 → 프로필 3단계 진행 표시
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.current});
  final int current;

  static const steps = ['계정 만들기', '역할 선택', '프로필'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(steps.length, (i) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == steps.length - 1 ? 0 : 6),
                decoration: BoxDecoration(
                  color: i < current
                      ? AppColors.primary
                      : i == current
                          ? AppColors.accent
                          : AppColors.placeholder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          '${current + 1}/${steps.length}  ${steps[current]}',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
