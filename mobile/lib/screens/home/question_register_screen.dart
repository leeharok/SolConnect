import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/question_service.dart';
import '../../theme/app_theme.dart';

class QuestionRegisterScreen extends StatefulWidget {
  const QuestionRegisterScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  State<QuestionRegisterScreen> createState() =>
      _QuestionRegisterScreenState();
}

class _QuestionRegisterScreenState
    extends State<QuestionRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _curriculumController = TextEditingController();
  final _contentController = TextEditingController();

  final _picker = ImagePicker();

  static const _subjects = [
    '수학',
    '국어',
    '영어',
    '과학',
    '사회',
    '한국사',
    '코딩',
  ];

  String _subject = '수학';
  final List<XFile> _images = [];

  bool _loading = false;

  @override
  void dispose() {
    _curriculumController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // 사진 선택 메뉴
  Future<void> _showImagePicker() async {
    if (_images.length >= 5) {
      _showMessage('사진은 최대 5장까지 첨부할 수 있어요.');
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.background,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: const Text('앨범에서 선택'),
              onTap: () =>
                  Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primary,
              ),
              title: const Text('카메라로 촬영'),
              onTap: () =>
                  Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      List<XFile> selected = [];

      if (source == ImageSource.gallery) {
        selected = await _picker.pickMultiImage(
          imageQuality: 85,
        );
      } else {
        final image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (image != null) {
          selected = [image];
        }
      }

      if (!mounted || selected.isEmpty) return;

      final remaining = 5 - _images.length;
      final accepted = selected.take(remaining).toList();

      setState(() {
        _images.addAll(accepted);
      });

      if (selected.length > remaining) {
        _showMessage('최대 5장까지만 첨부할 수 있어요.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('사진을 불러오지 못했어요.');
      }
    }
  }

  // 사진 삭제
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  // 질문 등록
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final user = widget.user;

    if (user.role != UserRole.mentee) {
      _showMessage('멘티 계정만 질문을 등록할 수 있어요.');
      return;
    }

    if (user.schoolLevel == null || user.grade == null) {
      _showMessage('회원 정보에서 학교급과 학년을 확인해 주세요.');
      return;
    }

    if (_images.isEmpty && _contentController.text.trim().isEmpty) {
      _showMessage('문제 사진이나 질문 내용을 입력해 주세요.');
      return;
    }

    setState(() => _loading = true);

    try {
      final auth = AuthScope.read(context);
      final token = await auth.getAccessToken();

      if (token == null || token.isEmpty) {
        throw const QuestionException(
          '로그인 인증이 만료됐어요. 다시 로그인해 주세요.',
        );
      }

      await QuestionService.createQuestion(
        token: token,
        schoolLevel: user.schoolLevel!,
        grade: user.grade!,
        subject: _subject,
        curriculum: _curriculumController.text,
        content: _contentController.text,
        images: _images,
      );

      if (!mounted) return;

      setState(() {
        _images.clear();
        _curriculumController.clear();
        _contentController.clear();
      });

      _showMessage('질문이 성공적으로 등록됐어요!');
    } on QuestionException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('질문 등록 중 오류가 발생했어요.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            '어떤 문제가 궁금한가요?',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '문제 사진을 올리고 궁금한 내용을 알려주세요.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 24),

          // 학교 및 학년 정보
          _sectionTitle('학습 정보'),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.school_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.schoolName ?? '학교 정보 없음',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user.schoolLevel?.label ?? ''} ${user.grade ?? ''}학년',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.lock_outline,
                  color: AppColors.textSub,
                  size: 18,
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // 과목
          _sectionTitle('과목'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _subject,
            decoration: const InputDecoration(
              hintText: '과목 선택',
            ),
            items: _subjects.map((subject) {
              return DropdownMenuItem(
                value: subject,
                child: Text(subject),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _subject = value);
              }
            },
          ),

          const SizedBox(height: 22),

          // 교육과정
          _sectionTitle('교육과정'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _curriculumController,
            maxLength: 100,
            decoration: const InputDecoration(
              hintText: '예) 2022 개정 교육과정',
              counterText: '',
            ),
          ),

          const SizedBox(height: 22),

          // 사진 첨부
          Row(
            children: [
              _sectionTitle('문제 사진'),
              const Spacer(),
              Text(
                '${_images.length}/5장',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...List.generate(_images.length, (index) {
                final image = _images[index];

                return SizedBox(
                  width: 100,
                  height: 110,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<Uint8List>(
                            future: image.readAsBytes(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Container(
                                  color: AppColors.placeholder,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(),
                                );
                              }

                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                              );
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              if (_images.length < 5)
                InkWell(
                  onTap: _loading ? null : _showImagePicker,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 100,
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.primary,
                          size: 30,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '사진 추가',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),
          const Text(
            'JPG, PNG, WEBP · 사진당 최대 5MB',
            style: AppTextStyles.caption,
          ),

          const SizedBox(height: 22),

          // 질문 내용
          _sectionTitle('질문 내용'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _contentController,
            maxLines: 5,
            maxLength: 5000,
            decoration: const InputDecoration(
              hintText: '어떤 부분이 어려운지 알려주세요. (선택)',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 28),

          // 등록 버튼
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('질문 등록하기'),
            ),
          ),

          const SizedBox(height: 12),
          const Center(
            child: Text(
              '등록된 질문은 멘토들이 확인할 수 있어요.',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: AppTextStyles.sectionTitle);
  }
}
