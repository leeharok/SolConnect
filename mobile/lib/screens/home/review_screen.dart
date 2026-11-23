import 'package:material_ui/material_ui.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/review_service.dart';
import '../../theme/app_theme.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.chatRoomId,
    required this.partnerName,
    required this.user,
  });

  final String chatRoomId;
  final String partnerName;
  final AppUser user;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _commentController = TextEditingController();

  String? _sentiment;
  bool _loading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submitReview() async {
    FocusScope.of(context).unfocus();

    if (_sentiment == null) {
      _showMessage('만족 또는 불만족을 선택해 주세요.');
      return;
    }

    final reviewText = _commentController.text.trim();

    if (_sentiment == 'UNSATISFIED' && reviewText.length < 100) {
      _showMessage('불만족 사유를 100자 이상 작성해 주세요.');
      return;
    }

    setState(() => _loading = true);

    try {
      final token = await AuthScope.read(context).getAccessToken();

      if (token == null || token.isEmpty) {
        throw const ReviewException('로그인이 필요해요.');
      }

      await ReviewService.submitReview(
        token: token,
        chatRoomId: widget.chatRoomId,
        sentiment: _sentiment!,
        comment: _sentiment == 'SATISFIED' ? _commentController.text : null,
        dissatisfactionReason:
            _sentiment == 'UNSATISFIED' ? _commentController.text : null,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('후기가 등록됐어요!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                '소중한 후기를 남겨주셔서 감사합니다.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('확인'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on ReviewException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error) {
      if (mounted) {
        _showMessage('후기 등록 중 오류가 발생했어요.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _sentimentOption({
    required String value,
    required String label,
    required String description,
    required IconData icon,
    required bool selected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: _loading ? null : () => setState(() => _sentiment = value),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 24,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.07)
                : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 40,
                color: selected ? AppColors.primary : AppColors.textSub,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.primary : AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: selected ? AppColors.primary : AppColors.hint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('멘토링 후기'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: [
            const SizedBox(height: 12),
            const Text(
              '멘토링은 만족스러우셨나요?',
              textAlign: TextAlign.center,
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.partnerName} 멘토와의 멘토링을 평가해 주세요.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 36),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sentimentOption(
                  value: 'SATISFIED',
                  label: '만족해요',
                  description: '도움이 되었어요!',
                  icon: Icons.thumb_up_alt_rounded,
                  selected: _sentiment == 'SATISFIED',
                ),
                const SizedBox(width: 12),
                _sentimentOption(
                  value: 'UNSATISFIED',
                  label: '불만족해요',
                  description: '아쉬운 점이 있었어요.',
                  icon: Icons.thumb_down_alt_rounded,
                  selected: _sentiment == 'UNSATISFIED',
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              _sentiment == 'UNSATISFIED'
                  ? '불만족 사유 (필수 · 100자 이상)'
                  : '추가 의견 (선택)',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              enabled: !_loading,
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: _sentiment == 'UNSATISFIED'
                    ? '아쉬웠던 점과 개선이 필요한 부분을 100자 이상 작성해 주세요.'
                    : '멘토링에서 좋았던 점이나 아쉬웠던 점을 알려주세요.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.card_giftcard_rounded,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '소중한 후기는 더 나은 멘토링 환경을 만드는 데 활용돼요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed:
                    _loading || _sentiment == null ? null : _submitReview,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('후기 제출하기'),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '제출한 후기는 수정할 수 없어요.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
