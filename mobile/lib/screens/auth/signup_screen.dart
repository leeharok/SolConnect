import 'package:material_ui/material_ui.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'validators.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _obscure = true;
  bool _loading = false;

  bool get _agreedAll => _agreeTerms && _agreePrivacy;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedAll) {
      showError(context, '필수 약관에 동의해 주세요.');
      return;
    }
    final navigator = Navigator.of(context);
    final auth = AuthScope.read(context);
    setState(() => _loading = true);
    try {
      await auth.signUp(email: _email.text, password: _password.text);
      // 가입 성공 → AuthGate가 멘토/멘티 선택 화면으로 전환
      navigator.popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              const StepDots(current: 0),
              const SizedBox(height: 24),
              LabeledField(
                label: '이메일',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration:
                      const InputDecoration(hintText: 'your@email.com'),
                  validator: Validators.email,
                ),
              ),
              const SizedBox(height: 18),
              LabeledField(
                label: '비밀번호',
                child: TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: '영문+숫자 8자 이상',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.hint,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: Validators.password,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: '비밀번호 확인'),
                validator: (v) =>
                    v != _password.text ? '비밀번호가 일치하지 않아요.' : null,
              ),
              const SizedBox(height: 28),
              _AgreementBox(
                agreeTerms: _agreeTerms,
                agreePrivacy: _agreePrivacy,
                onAll: (v) => setState(() {
                  _agreeTerms = v;
                  _agreePrivacy = v;
                }),
                onTerms: (v) => setState(() => _agreeTerms = v),
                onPrivacy: (v) => setState(() => _agreePrivacy = v),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: '다음',
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgreementBox extends StatelessWidget {
  const _AgreementBox({
    required this.agreeTerms,
    required this.agreePrivacy,
    required this.onAll,
    required this.onTerms,
    required this.onPrivacy,
  });

  final bool agreeTerms;
  final bool agreePrivacy;
  final ValueChanged<bool> onAll;
  final ValueChanged<bool> onTerms;
  final ValueChanged<bool> onPrivacy;

  @override
  Widget build(BuildContext context) {
    Widget row(String text, bool value, ValueChanged<bool> onChanged,
        {bool bold = false}) {
      return InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Checkbox(
                value: value,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => onChanged(v ?? false),
              ),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: bold ? 15 : 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          row('약관 전체 동의', agreeTerms && agreePrivacy, onAll, bold: true),
          const Divider(height: 8, indent: 12, endIndent: 12),
          row('[필수] 서비스 이용약관 동의', agreeTerms, onTerms),
          row('[필수] 개인정보 수집·이용 동의', agreePrivacy, onPrivacy),
        ],
      ),
    );
  }
}
