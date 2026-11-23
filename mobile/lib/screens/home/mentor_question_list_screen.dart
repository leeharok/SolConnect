import 'package:material_ui/material_ui.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/question_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class MentorQuestionListScreen extends StatefulWidget {
  const MentorQuestionListScreen({super.key});

  @override
  State<MentorQuestionListScreen> createState() =>
      _MentorQuestionListScreenState();
}

class _MentorQuestionListScreenState
    extends State<MentorQuestionListScreen> {
  SchoolLevel? _level;
  int? _grade;
  String _subject = '전체';

  bool _loading = false;
  bool _initialized = false;
  String? _acceptingId;

  List<Map<String, dynamic>> _questions = [];

  static const _subjects = [
    '전체', '수학', '국어', '영어', '과학', '사회', '한국사', '코딩',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;
      _loadQuestions();
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);

    try {
      final token =
          await AuthScope.read(context).getAccessToken();

      if (token == null || token.isEmpty) {
        throw const QuestionException('로그인이 필요해요.');
      }

      final result = await QuestionService.getAvailableQuestions(
        token: token,
        schoolLevel: _level,
        grade: _level == null ? null : _grade,
        subject: _subject == '전체' ? null : _subject,
      );

      final rawQuestions = result['questions'];

      final questions = rawQuestions is List
          ? rawQuestions
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _acceptQuestion(String questionId) async {
    if (_acceptingId != null) return;

    setState(() => _acceptingId = questionId);

    try {
      final token =
          await AuthScope.read(context).getAccessToken();

      if (token == null || token.isEmpty) {
        throw const QuestionException('로그인이 필요해요.');
      }

      final result = await QuestionService.acceptQuestion(
        token: token,
        questionId: questionId,
      );

      if (!mounted) return;

      setState(() {
        _questions.removeWhere(
          (question) => question['id'] == questionId,
        );
        _acceptingId = null;
      });

      final match = result['match'];
      final chatRoomId = match is Map
          ? match['chatRoomId']
          : null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatRoomId != null
                ? '질문 수락 완료! 채팅방이 생성됐어요.'
                : '질문을 수락했어요.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } on QuestionException catch (error) {
      if (!mounted) return;

      setState(() => _acceptingId = null);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );

      await _loadQuestions();
    } catch (error) {
      if (!mounted) return;

      setState(() => _acceptingId = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('질문 수락 중 오류가 발생했어요.')),
      );
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

  String _dateLabel(dynamic value) {
    if (value is! String) return '';

    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';

    return '${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _imagesOf(
    Map<String, dynamic> question,
  ) {
    final raw = question['images'];

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((image) => Map<String, dynamic>.from(image))
        .toList();
  }

  Widget _buildImages(Map<String, dynamic> question) {
    final images = _imagesOf(question);

    if (images.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final path = images[index]['storagePath'] as String?;

          if (path == null || path.isEmpty) {
            return const SizedBox.shrink();
          }

          final url = Uri.parse(ApiService.baseUrl)
              .resolve(path)
              .toString();

          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 112,
              height: 112,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 112,
                height: 112,
                color: AppColors.placeholder,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textSub,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question) {
    final id = question['id'] as String? ?? '';
    final subject = question['subject'] as String? ?? '과목';
    final level = question['schoolLevel'] as String?;
    final grade = question['grade'];
    final content = question['content'] as String? ?? '';
    final curriculum = question['curriculum'] as String?;
    final date = _dateLabel(question['createdAt']);

    final accepting = _acceptingId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _tag(subject, AppColors.primary),
              _tag(
                '${_schoolLabel(level)} ${grade ?? ''}학년',
                AppColors.textSub,
              ),
            ],
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(date, style: AppTextStyles.caption),
          ],
          if (curriculum != null && curriculum.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '교육과정: $curriculum',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSub,
              ),
            ),
          ],
          if (content.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.text,
              ),
            ),
          ],
          if (_imagesOf(question).isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildImages(question),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: accepting || _acceptingId != null
                  ? null
                  : () => _acceptQuestion(id),
              child: accepting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('이 질문 수락하기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('학교급', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            children: [
              _levelChip('전체', null),
              ...SchoolLevel.values.map(
                (level) => _levelChip(level.label, level),
              ),
            ],
          ),
          if (_level != null) ...[
            const SizedBox(height: 12),
            const Text('학년', style: AppTextStyles.label),
            const SizedBox(height: 6),
            DropdownButtonFormField<int?>(
              initialValue: _grade,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('전체 학년'),
                ),
                ...List.generate(
                  _level!.maxGrade,
                  (index) => DropdownMenuItem<int?>(
                    value: index + 1,
                    child: Text('${index + 1}학년'),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _grade = value);
                _loadQuestions();
              },
            ),
          ],
          const SizedBox(height: 12),
          const Text('과목', style: AppTextStyles.label),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _subject,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: _subjects.map((subject) {
              return DropdownMenuItem(
                value: subject,
                child: Text(subject),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _subject = value);
              _loadQuestions();
            },
          ),
        ],
      ),
    );
  }

  Widget _levelChip(String label, SchoolLevel? value) {
    final selected = _level == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? AppColors.white : AppColors.text,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
      ),
      onSelected: (_) {
        setState(() {
          _level = value;
          _grade = null;
        });
        _loadQuestions();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadQuestions,
                  child: _questions.isEmpty
                      ? ListView(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 100),
                            Icon(
                              Icons.inbox_outlined,
                              size: 52,
                              color: AppColors.hint,
                            ),
                            SizedBox(height: 16),
                            Center(
                              child: Text(
                                '아직 등록된 질문이 없어요.',
                                style: AppTextStyles.sectionTitle,
                              ),
                            ),
                            SizedBox(height: 8),
                            Center(
                              child: Text(
                                '새로운 질문이 등록되면 여기에 표시돼요.',
                                style: AppTextStyles.caption,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            16, 16, 16, 28,
                          ),
                          itemCount: _questions.length,
                          itemBuilder: (context, index) {
                            return _buildQuestionCard(
                              _questions[index],
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}
