import 'package:material_ui/material_ui.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/validators.dart';

const kSubjects = ['국어', '수학', '영어', '과학', '사회', '한국사', '코딩'];

/// 프로필 작성(가입 마지막 단계) 겸 프로필 수정 화면
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.editing = false});

  /// true면 마이페이지에서 들어온 '프로필 수정' 모드
  final bool editing;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AppUser _user;
  late final TextEditingController _nickname;
  // 멘티
  late final TextEditingController _schoolName;
  final _inviteCode = TextEditingController();
  SchoolLevel? _level;
  int? _grade;
  // 멘토
  late final TextEditingController _department;
  late final TextEditingController _studentId;
  late final TextEditingController _bio;
  late Set<String> _subjects;

  bool _loading = false;
  bool _initialized = false;

  bool get _isMentee => _user.role == UserRole.mentee;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _user = AuthScope.read(context).currentUser!;
    _nickname = TextEditingController(text: _user.nickname);
    _schoolName = TextEditingController(text: _user.schoolName);
    _level = _user.schoolLevel;
    _grade = _user.grade;
    _department = TextEditingController(text: _user.department);
    _studentId = TextEditingController(text: _user.studentId);
    _bio = TextEditingController(text: _user.bio);
    _subjects = {..._user.subjects};
  }

  @override
  void dispose() {
    for (final c in [
      _nickname,
      _schoolName,
      _inviteCode,
      _department,
      _studentId,
      _bio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_isMentee && (_level == null || _grade == null)) {
      showError(context, '학교급과 학년을 선택해 주세요.');
      return;
    }
    if (!_isMentee && _subjects.isEmpty) {
      showError(context, '멘토링 가능한 과목을 하나 이상 선택해 주세요.');
      return;
    }

    final auth = AuthScope.read(context);
    final navigator = Navigator.of(context);
    setState(() => _loading = true);
    try {
      if (_isMentee && !widget.editing) {
        await auth.verifyInviteCode(_inviteCode.text);
      }
      final updated = _isMentee
          ? _user.copyWith(
              nickname: _nickname.text.trim(),
              schoolLevel: _level,
              schoolName: _schoolName.text.trim(),
              grade: _grade,
            )
          : _user.copyWith(
              nickname: _nickname.text.trim(),
              department: _department.text.trim(),
              studentId: _studentId.text.trim(),
              subjects: kSubjects.where(_subjects.contains).toList(),
              bio: _bio.text.trim(),
            );
      await auth.saveProfile(updated);
      if (widget.editing) {
        navigator.pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('프로필을 저장했어요.')),
          );
        }
      }
      // 가입 단계라면 AuthGate가 홈 화면으로 전환
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
        title: Text(widget.editing ? '프로필 수정' : '프로필 작성'),
        actions: [
          if (!widget.editing)
            TextButton(
              onPressed: () => AuthScope.read(context).logout(),
              child: const Text('나가기',
                  style: TextStyle(color: AppColors.textSub)),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              if (!widget.editing) ...[
                const StepDots(current: 2),
                const SizedBox(height: 24),
              ],
              Center(
                child: Column(
                  children: [
                    const ProfileAvatar(size: 84),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _user.role!.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LabeledField(
                label: '닉네임',
                child: TextFormField(
                  controller: _nickname,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    hintText: '앱에서 보여질 이름',
                    counterText: '',
                  ),
                  validator: (v) => Validators.required(v, '닉네임'),
                ),
              ),
              const SizedBox(height: 18),
              ...(_isMentee ? _menteeFields() : _mentorFields()),
              const SizedBox(height: 32),
              PrimaryButton(
                label: widget.editing ? '저장하기' : '시작하기',
                loading: _loading,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _menteeFields() {
    return [
      LabeledField(
        label: '학교급',
        child: Wrap(
          spacing: 8,
          children: SchoolLevel.values.map((l) {
            final selected = _level == l;
            return ChoiceChip(
              label: Text(l.label),
              selected: selected,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: selected ? AppColors.white : AppColors.text,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
              onSelected: (_) => setState(() {
                _level = l;
                if (_grade != null && _grade! > l.maxGrade) _grade = null;
              }),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 18),
      LabeledField(
        label: '학교 이름',
        child: TextFormField(
          controller: _schoolName,
          decoration: const InputDecoration(hintText: '예) 나주중학교'),
          validator: (v) => Validators.required(v, '학교 이름'),
        ),
      ),
      const SizedBox(height: 18),
      LabeledField(
        label: '학년',
        child: DropdownButtonFormField<int>(
          // ignore: deprecated_member_use
          value: _grade,
          hint: const Text('학년 선택',
              style: TextStyle(color: AppColors.hint, fontSize: 15)),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          dropdownColor: AppColors.white,
          items: List.generate(
            (_level ?? SchoolLevel.elementary).maxGrade,
            (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}학년')),
          ),
          onChanged: _level == null ? null : (v) => setState(() => _grade = v),
        ),
      ),
      if (!widget.editing) ...[
        const SizedBox(height: 18),
        LabeledField(
          label: '학교 초대코드',
          child: TextFormField(
            controller: _inviteCode,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: '학교에서 받은 초대코드 입력',
              helperText: '나주 지역 학교 재학 확인을 위해 필요해요.',
              helperStyle: AppTextStyles.caption,
            ),
            validator: (v) => Validators.required(v, '초대코드'),
          ),
        ),
      ],
    ];
  }

  List<Widget> _mentorFields() {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LabeledField(
              label: '학과',
              child: TextFormField(
                controller: _department,
                decoration: const InputDecoration(hintText: '예) 에너지공학부'),
                validator: (v) => Validators.required(v, '학과'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LabeledField(
              label: '학번',
              child: TextFormField(
                controller: _studentId,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '예) 20220000'),
                validator: (v) => Validators.required(v, '학번'),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      LabeledField(
        label: '멘토링 가능 과목',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kSubjects.map((s) {
            final selected = _subjects.contains(s);
            return FilterChip(
              label: Text(s),
              selected: selected,
              labelStyle: TextStyle(
                color: selected ? AppColors.white : AppColors.text,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
              onSelected: (v) => setState(
                () => v ? _subjects.add(s) : _subjects.remove(s),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 18),
      LabeledField(
        label: '한 줄 소개 (선택)',
        child: TextFormField(
          controller: _bio,
          maxLength: 60,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: '예) 수학 개념을 쉽게 설명해 드려요!',
          ),
        ),
      ),
    ];
  }
}
