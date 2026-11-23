class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _hasLetter = RegExp(r'[A-Za-z]');
  static final _hasDigit = RegExp(r'\d');

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return '이메일을 입력해 주세요.';
    if (!_emailRegex.hasMatch(value)) return '올바른 이메일 형식이 아니에요.';
    return null;
  }

  static String? password(String? v) {
    final value = v ?? '';
    if (value.length < 8) return '8자 이상 입력해 주세요.';
    if (!_hasLetter.hasMatch(value) || !_hasDigit.hasMatch(value)) {
      return '영문과 숫자를 함께 사용해 주세요.';
    }
    return null;
  }

  static String? required(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field을(를) 입력해 주세요.' : null;
}
