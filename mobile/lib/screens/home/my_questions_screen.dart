import 'package:material_ui/material_ui.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/question_service.dart';
import '../../theme/app_theme.dart';

class MyQuestionsScreen extends StatefulWidget {
  const MyQuestionsScreen({super.key});

  @override
  State<MyQuestionsScreen> createState() => _MyQuestionsScreenState();
}

class _MyQuestionsScreenState extends State<MyQuestionsScreen> {
  final List<Map<String, dynamic>> _questions = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _initialized = false;
  bool _hasMore = false;

  int _page = 1;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;
      _loadQuestions(refresh: true);
    }
  }

  Future<void> _loadQuestions({bool refresh = false}) async {
    if (!refresh && (_loadingMore || !_hasMore)) return;

    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final token = await AuthScope.read(context).getAccessToken();

      if (token == null || token.isEmpty) {
        throw const QuestionException('로그인이 필요해요.');
      }

      final nextPage = refresh ? 1 : _page + 1;

      final result = await QuestionService.getMyQuestions(
        token: token,
        page: nextPage,
        limit: 20,
      );

      final raw = result['questions'];
      final incoming = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      final pagination = result['pagination'];
      final totalPages = pagination is Map && pagination['totalPages'] is num
          ? (pagination['totalPages'] as num).toInt()
          : nextPage;

      if (!mounted) return;

      setState(() {
        if (refresh) {
          _questions
            ..clear()
            ..addAll(incoming);
        } else {
          _questions.addAll(incoming);
        }

        _page = nextPage;
        _hasMore = nextPage < totalPages;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error.toString();
      });
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'OPEN':
        return '멘토 답변 대기';
      case 'MATCHED':
        return '멘토 매칭 완료';
      case 'IN_PROGRESS':
        return '풀이 진행 중';
      case 'WAITING_REVIEW':
        return '후기 작성 대기';
      case 'CLOSED':
        return '멘토링 완료';
      case 'CANCELED':
        return '취소됨';
      default:
        return '상태 확인 중';
    }
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

  String _formatDate(dynamic value) {
    if (value is! String) return '';

    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';

    return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _imagesOf(Map<String, dynamic> question) {
    final raw = question['images'];

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _showExpandedImage(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 240,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImages(Map<String, dynamic> question) {
    final images = _imagesOf(question);

    if (images.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final path = images[index]['storagePath'] as String?;

          if (path == null || path.isEmpty) {
            return const SizedBox.shrink();
          }

          final url = Uri.parse(ApiService.baseUrl).resolve(path).toString();

          return GestureDetector(
            onTap: () => _showExpandedImage(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 92,
                height: 92,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 92,
                  height: 92,
                  color: AppColors.placeholder,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question) {
    final subject = question['subject'] as String? ?? '과목 미상';
    final level = question['schoolLevel'] as String?;
    final grade = question['grade']?.toString() ?? '-';
    final status = question['status'] as String?;
    final mentor = question['mentor'] is Map
        ? Map<String, dynamic>.from(question['mentor'])
        : null;

    final content = question['content'] as String? ?? '';
    final createdAt = _formatDate(question['createdAt']);

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
              Expanded(
                child: Text(
                  '$subject · ${_schoolLabel(level)} $grade학년',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(status),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '등록일 $createdAt',
              style: AppTextStyles.caption,
            ),
          ],
          if (mentor != null && mentor['name'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: AppColors.textSub,
                ),
                const SizedBox(width: 4),
                Text(
                  '담당 멘토 ${mentor['name']}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ],
          if (content.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.text,
                height: 1.45,
              ),
            ),
          ],
          if (_imagesOf(question).isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildImages(question),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _questions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _questions.isEmpty) {
      return Center(
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
                onPressed: () => _loadQuestions(refresh: true),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '총 ${_questions.length}개 표시 중',
                  style: AppTextStyles.caption,
                ),
              ),
              IconButton(
                onPressed:
                    _loading ? null : () => _loadQuestions(refresh: true),
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
          child: RefreshIndicator(
            onRefresh: () => _loadQuestions(refresh: true),
            child: _questions.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 110),
                      Icon(
                        Icons.assignment_outlined,
                        size: 52,
                        color: AppColors.hint,
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          '아직 등록한 질문이 없어요.',
                          style: AppTextStyles.sectionTitle,
                        ),
                      ),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          '질문을 등록하면 이곳에서 확인할 수 있어요.',
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _questions.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < _questions.length) {
                        return _buildQuestionCard(_questions[index]);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: OutlinedButton(
                            onPressed:
                                _loadingMore ? null : () => _loadQuestions(),
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
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
