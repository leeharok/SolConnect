import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 화면은 이 인터페이스만 사용합니다.
/// 백엔드(회원가입/로그인 API)가 준비되면 [ApiAuthService] 같은 구현체를 만들어
/// main.dart에서 MockAuthService 대신 넣으면 됩니다.
abstract class AuthService extends ChangeNotifier {
  AppUser? get currentUser;
  bool get isInitializing;

  // 로그인한 사용자의 인증 토큰 조회
  Future<String?> getAccessToken() async => null;

  Future<void> init();

  Future<void> login({
    required String email,
    required String password,
    required bool keepSignedIn,
  });

  Future<void> signUp({required String email, required String password});

  Future<void> setRole(UserRole role);

  /// 나주 지역 학교 재학 확인용 초대코드 검증 (멘티)
  Future<void> verifyInviteCode(String code);

  Future<void> saveProfile(AppUser user);

  Future<void> logout();
}

/// 백엔드 연동 전 테스트용 구현체. 기기에 로컬 저장합니다.
/// 비밀번호를 평문으로 저장하므로 실제 배포에는 사용하면 안 됩니다.
class MockAuthService extends AuthService {
  static const _usersKey = 'mock_users';
  static const _sessionKey = 'session_email';

  /// 테스트용 초대코드. 실제로는 서버가 학교별 코드를 검증합니다.
  static const demoInviteCodes = {'NAJU2026', 'SOLCONNECT'};

  /// true면 멘토는 @kentech.ac.kr 이메일로 가입해야 함
  static const requireKentechEmailForMentor = false;

  SharedPreferences? _prefs;
  final Map<String, Map<String, dynamic>> _users = {};
  AppUser? _currentUser;
  bool _initializing = true;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  bool get isInitializing => _initializing;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_usersKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.forEach((k, v) => _users[k] = Map<String, dynamic>.from(v));
    }
    final session = _prefs!.getString(_sessionKey);
    if (session != null && _users.containsKey(session)) {
      _currentUser = AppUser.fromJson(
        Map<String, dynamic>.from(_users[session]!['user'] as Map),
      );
    }
    _initializing = false;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs?.setString(_usersKey, jsonEncode(_users));
  }

  Future<void> _fakeDelay() =>
      Future<void>.delayed(const Duration(milliseconds: 500));

  @override
  Future<void> login({
    required String email,
    required String password,
    required bool keepSignedIn,
  }) async {
    await _fakeDelay();
    final key = email.trim().toLowerCase();
    final record = _users[key];
    if (record == null || record['password'] != password) {
      throw const AuthException('이메일 또는 비밀번호가 올바르지 않아요.');
    }
    _currentUser =
        AppUser.fromJson(Map<String, dynamic>.from(record['user'] as Map));
    if (keepSignedIn) {
      await _prefs?.setString(_sessionKey, key);
    } else {
      await _prefs?.remove(_sessionKey);
    }
    notifyListeners();
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await _fakeDelay();
    final key = email.trim().toLowerCase();
    if (_users.containsKey(key)) {
      throw const AuthException('이미 가입된 이메일이에요.');
    }
    final user = AppUser(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      email: key,
    );
    _users[key] = {'password': password, 'user': user.toJson()};
    await _persist();
    await _prefs?.setString(_sessionKey, key);
    _currentUser = user;
    notifyListeners();
  }

  @override
  Future<void> setRole(UserRole role) async {
    final user = _requireUser();
    if (role == UserRole.mentor &&
        requireKentechEmailForMentor &&
        !user.email.endsWith('@kentech.ac.kr')) {
      throw const AuthException('멘토는 KENTECH 이메일(@kentech.ac.kr)로 가입해야 해요.');
    }
    await _update(user.copyWith(role: role));
  }

  @override
  Future<void> verifyInviteCode(String code) async {
    await _fakeDelay();
    if (!demoInviteCodes.contains(code.trim().toUpperCase())) {
      throw const AuthException('유효하지 않은 초대코드예요. 학교에서 받은 코드를 확인해 주세요.');
    }
  }

  @override
  Future<void> saveProfile(AppUser user) async {
    await _fakeDelay();
    await _update(user);
  }

  @override
  Future<void> logout() async {
    await _prefs?.remove(_sessionKey);
    _currentUser = null;
    notifyListeners();
  }

  AppUser _requireUser() {
    final user = _currentUser;
    if (user == null) throw const AuthException('로그인이 필요해요.');
    return user;
  }

  Future<void> _update(AppUser user) async {
    final record = _users[user.email];
    if (record != null) {
      record['user'] = user.toJson();
      await _persist();
    }
    _currentUser = user;
    notifyListeners();
  }
}

/// 위젯 트리 어디서든 AuthScope.of(context)로 접근
class AuthScope extends InheritedNotifier<AuthService> {
  const AuthScope({
    super.key,
    required AuthService service,
    required super.child,
  }) : super(notifier: service);

  static AuthService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope가 위젯 트리에 없습니다.');
    return scope!.notifier!;
  }

  /// 리빌드 구독 없이 호출만 할 때 (버튼 onPressed 등)
  static AuthService read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AuthScope>();
    return scope!.notifier!;
  }
}
