import 'package:material_ui/material_ui.dart';

import '../../services/auth_service.dart';
import '../../services/review_service.dart';
import '../../theme/app_theme.dart';

class ReceivedReviewsScreen extends StatefulWidget {
  const ReceivedReviewsScreen({super.key});

  @override
  State<ReceivedReviewsScreen> createState() => _ReceivedReviewsScreenState();
}

class _ReceivedReviewsScreenState extends State<ReceivedReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _initialized = false;

  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  int _satisfiedCount = 0;
  int _unsatisfiedCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;
      _loadReviews();
    }
  }

  Future<void> _loadReviews({
    bool append = false,
  }) async {
    if (append && (_loadingMore || _page >= _totalPages)) return;

    if (append) {
      setState(() {
        _loadingMore = true;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final token = await AuthScope.read(context).getAccessToken();

      if (token == null || token.isEmpty) {
        throw const ReviewException('로그인이 필요해요.');
      }

      final nextPage = append ? _page + 1 : 1;

      final result = await ReviewService.getReceivedReviews(
        token: token,
        page: nextPage,
        limit: 20,
      );

      final rawReviews = result['reviews'];
      final fetchedReviews = rawReviews is List
          ? rawReviews
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      final summary = result['summary'];
      final pagination = result['pagination'];

      if (!mounted) return;

      setState(() {
        if (append) {
          _reviews.addAll(fetchedReviews);
        } else {
          _reviews = fetchedReviews;
        }

        _totalCount =
            summary is Map ? (summary['total'] as num?)?.toInt() ?? 0 : 0;

        _satisfiedCount = summary is Map
            ? (summary['satisfiedCount'] as num?)?.toInt() ?? 0
            : 0;

        _unsatisfiedCount = summary is Map
            ? (summary['unsatisfiedCount'] as num?)?.toInt() ?? 0
            : 0;

        _page = nextPage;
        _totalPages = pagination is Map
            ? (pagination['totalPages'] as num?)?.toInt() ?? 1
            : 1;

        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } on ReviewException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = '받은 후기를 불러오는 중 오류가 발생했어요.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();

    if (date == null) return '';

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${date.year}.${twoDigits(date.month)}.${twoDigits(date.day)}';
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

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내가 받은 멘토링 후기',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$_totalCount개',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '만족해요',
                  _satisfiedCount,
                  Icons.sentiment_satisfied_alt_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: AppColors.white.withValues(alpha: 0.25),
              ),
              Expanded(
                child: _buildSummaryItem(
                  '불만족해요',
                  _unsatisfiedCount,
                  Icons.sentiment_dissatisfied_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    int count,
    IconData icon,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.white, size: 19),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 11,
              ),
            ),
            Text(
              '$count개',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final sentiment = review['sentiment'] as String?;
    final isSatisfied = sentiment == 'SATISFIED';

    final question = review['question'] is Map
        ? Map<String, dynamic>.from(review['question'])
        : <String, dynamic>{};

    final menteeName = review['menteeName'] as String? ?? '멘티';
    final subject = question['subject'] as String? ?? '과목 미상';
    final level = question['schoolLevel'] as String?;
    final grade = question['grade']?.toString() ?? '-';

    final content = isSatisfied
        ? review['comment'] as String? ?? ''
        : review['dissatisfactionReason'] as String? ?? '';

    final points = (review['pointsAwarded'] as num?)?.toInt() ?? 0;
    final date = _formatDate(review['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                child: Text(
                  menteeName.isNotEmpty ? menteeName.characters.first : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      menteeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$subject · ${_schoolLabel(level)} $grade학년',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSatisfied
                      ? AppColors.primary.withValues(alpha: 0.09)
                      : AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isSatisfied ? '만족해요' : '불만족해요',
                  style: TextStyle(
                    color: isSatisfied ? AppColors.primary : AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              content.trim().isNotEmpty ? content : '별도로 작성된 의견이 없어요.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  date,
                  style: AppTextStyles.caption,
                ),
              ),
              if (points > 0)
                Text(
                  '+$points P 적립',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('받은 후기'),
      ),
      body: _loading && _reviews.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadReviews(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        '후기 목록',
                        style: AppTextStyles.sectionTitle,
                      ),
                      const Spacer(),
                      Text(
                        '총 $_totalCount건',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_error != null && _reviews.isEmpty) ...[
                    const SizedBox(height: 25),
                    Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: OutlinedButton(
                        onPressed: () => _loadReviews(),
                        child: const Text('다시 시도'),
                      ),
                    ),
                  ] else if (_reviews.isEmpty) ...[
                    const SizedBox(height: 35),
                    const Icon(
                      Icons.rate_review_outlined,
                      size: 48,
                      color: AppColors.hint,
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        '아직 받은 후기가 없어요.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ] else ...[
                    for (final review in _reviews) _buildReviewCard(review),
                  ],
                  if (_error != null && _reviews.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ],
                  if (_page < _totalPages) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _loadingMore
                          ? null
                          : () => _loadReviews(append: true),
                      child: _loadingMore
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('더 불러오기'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
