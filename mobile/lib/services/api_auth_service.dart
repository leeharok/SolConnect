import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ApiAuthService extends AuthService {
  static const String _tokenKey = 'solconnect_access_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  final http.Client _client = http.Client();

  AppUser? _currentUser;
  bool _initializing = true;
  String? _sessionToken;

  // 회원가입 진행 중인 정보는 메모리에만 임시 보관
  String? _pendingEmail;
  String? _pendingPassword;
  String? _verifiedInviteCode;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  bool get isInitializing => _initializing;

  // 토큰 가져오기
  @override
  Future<String?> getAccessToken() async {
    return _sessionToken ?? await _storage.read(key: _tokenKey);
  }

  // 서버 JSON 응답 처리
  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const AuthException('서버 응답 형식이 올바르지 않아요.');
    }

    return decoded;
  }

  // 서버 사용자 정보를 Flutter 모델로 변환
  AppUser _createAppUser(Map<String, dynamic> data) {
    UserRole? role;

    switch (data['role']) {
      case 'MENTEE':
        role = UserRole.mentee;
        break;
      case 'MENTOR':
        role = UserRole.mentor;
        break;
    }

    SchoolLevel? schoolLevel;

    switch (data['schoolLevel']) {
      case 'ELEMENTARY':
        schoolLevel = SchoolLevel.elementary;
        break;
      case 'MIDDLE':
        schoolLevel = SchoolLevel.middle;
        break;
      case 'HIGH':
        schoolLevel = SchoolLevel.high;
        break;
    }

    return AppUser(
      id: data['id'] as String,
      email: data['email'] as String,
      nickname:
          (data['name'] as String?) ?? (data['nickname'] as String?) ?? '',
      role: role,
      schoolLevel: schoolLevel,
      schoolName: data['schoolName'] as String?,
      grade: (data['grade'] as num?)?.toInt(),
      department: data['department'] as String?,
      studentId: data['studentId'] as String?,
      subjects: ((data['subjects'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      bio: data['bio'] as String?,
      points: (data['points'] as num?)?.toInt() ?? 0,
    );
  }

  // 앱 실행 시 기존 로그인 상태 복원
  @override
  Future<void> init() async {
    try {
      _sessionToken = await _storage.read(key: _tokenKey);

      if (_sessionToken != null) {
        final response = await _client.get(
          Uri.parse('${ApiService.baseUrl}/api/auth/me'),
          headers: {
            'Authorization': 'Bearer $_sessionToken',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = _decodeResponse(response);
          _currentUser = _createAppUser(
            data['user'] as Map<String, dynamic>,
          );
        } else if (response.statusCode == 401) {
          await _storage.delete(key: _tokenKey);
          _sessionToken = null;
          _currentUser = null;
        } else {
          debugPrint('회원 정보 조회 실패: ${response.statusCode}');
        }
      }
    } catch (error) {
      debugPrint('인증 초기화 오류: $error');
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  // 실제 로그인
  @override
  Future<void> login({
    required String email,
    required String password,
    required bool keepSignedIn,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiService.baseUrl}/api/auth/login'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = _decodeResponse(response);

      if (response.statusCode != 200 || data['success'] != true) {
        throw AuthException(
          data['message'] as String? ?? '로그인에 실패했어요.',
        );
      }

      final token = data['accessToken'];

      if (token is! String || token.isEmpty) {
        throw const AuthException('인증 토큰을 받지 못했어요.');
      }

      _sessionToken = token;

      if (keepSignedIn) {
        await _storage.write(
          key: _tokenKey,
          value: token,
        );
      } else {
        await _storage.delete(key: _tokenKey);
      }

      _currentUser = _createAppUser(
        data['user'] as Map<String, dynamic>,
      );

      notifyListeners();
    } on AuthException {
      rethrow;
    } catch (error) {
      debugPrint('로그인 오류: $error');
      throw const AuthException(
        '서버에 연결할 수 없어요. 네트워크를 확인해 주세요.',
      );
    }
  }

  // 회원가입 1단계: 이메일 및 비밀번호 임시 보관
  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty || password.length < 8) {
      throw const AuthException('이메일과 비밀번호를 확인해 주세요.');
    }

    _pendingEmail = cleanEmail;
    _pendingPassword = password;
    _verifiedInviteCode = null;

    // 아직 서버에 회원을 생성하지 않음
    // 역할 선택 화면으로 이동하기 위한 임시 사용자
    _currentUser = AppUser(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      email: cleanEmail,
    );

    notifyListeners();
  }

  // 회원가입 2단계: 역할 임시 선택
  @override
  Future<void> setRole(UserRole role) async {
    final user = _currentUser;

    if (_pendingEmail == null || user == null) {
      throw const AuthException('회원가입을 먼저 진행해 주세요.');
    }

    _currentUser = user.copyWith(role: role);

    notifyListeners();
  }

  // 멘티 초대코드 서버 검증
  @override
  Future<void> verifyInviteCode(String code) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiService.baseUrl}/api/auth/verify-invite'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'inviteCode': code.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = _decodeResponse(response);

      if (response.statusCode != 200 || data['success'] != true) {
        throw AuthException(
          data['message'] as String? ?? '초대코드 인증에 실패했어요.',
        );
      }

      _verifiedInviteCode = code.trim().toUpperCase();
    } on AuthException {
      rethrow;
    } catch (error) {
      debugPrint('초대코드 인증 오류: $error');
      throw const AuthException('초대코드 서버에 연결할 수 없어요.');
    }
  }

  // 회원가입 마지막 단계: 프로필과 계정 정보를 서버에 한 번에 저장
  @override
  Future<void> saveProfile(AppUser user) async {
    if (_pendingEmail == null || _pendingPassword == null) {
      throw const AuthException(
        '새 회원가입 흐름이 아니에요. 프로필 수정 API는 별도로 연결해야 해요.',
      );
    }

    if (user.role == null) {
      throw const AuthException('멘티 또는 멘토 역할을 선택해 주세요.');
    }

    final Map<String, dynamic> requestData = {
      'name': user.nickname.trim(),
      'email': _pendingEmail,
      'password': _pendingPassword,
      'role': user.role == UserRole.mentee ? 'MENTEE' : 'MENTOR',
    };

    // 멘티 정보
    if (user.role == UserRole.mentee) {
      if (user.schoolLevel == null ||
          user.schoolName == null ||
          user.grade == null ||
          _verifiedInviteCode == null) {
        throw const AuthException(
          '학교급, 학교, 학년 및 초대코드를 확인해 주세요.',
        );
      }

      String schoolLevel;

      switch (user.schoolLevel!) {
        case SchoolLevel.elementary:
          schoolLevel = 'ELEMENTARY';
          break;
        case SchoolLevel.middle:
          schoolLevel = 'MIDDLE';
          break;
        case SchoolLevel.high:
          schoolLevel = 'HIGH';
          break;
      }

      requestData.addAll({
        'schoolLevel': schoolLevel,
        'schoolName': user.schoolName!.trim(),
        'grade': user.grade,
        'inviteCode': _verifiedInviteCode,
      });
    }

    // 멘토 정보
    if (user.role == UserRole.mentor) {
      if (user.department == null ||
          user.studentId == null ||
          user.subjects.isEmpty) {
        throw const AuthException(
          '학과, 학번 및 담당 과목을 확인해 주세요.',
        );
      }

      requestData.addAll({
        'department': user.department!.trim(),
        'studentId': user.studentId!.trim(),
        'subjects': user.subjects,
        'bio': user.bio,
      });
    }

    try {
      final response = await _client
          .post(
            Uri.parse('${ApiService.baseUrl}/api/auth/register'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response);

      if (response.statusCode != 201 || data['success'] != true) {
        throw AuthException(
          data['message'] as String? ?? '회원가입에 실패했어요.',
        );
      }

      final token = data['accessToken'];

      if (token is! String || token.isEmpty) {
        throw const AuthException('회원가입 인증 토큰을 받지 못했어요.');
      }

      // 회원가입 성공 후 자동 로그인
      _sessionToken = token;

      await _storage.write(
        key: _tokenKey,
        value: token,
      );

      _currentUser = _createAppUser(
        data['user'] as Map<String, dynamic>,
      );

      // 임시 가입 정보 정리
      _pendingEmail = null;
      _pendingPassword = null;
      _verifiedInviteCode = null;

      notifyListeners();
    } on AuthException {
      rethrow;
    } catch (error) {
      debugPrint('회원가입 요청 오류: $error');
      throw const AuthException(
        '회원가입 중 서버 연결 오류가 발생했어요.',
      );
    }
  }

  // 로그아웃
  @override
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);

    _sessionToken = null;
    _currentUser = null;

    _pendingEmail = null;
    _pendingPassword = null;
    _verifiedInviteCode = null;

    notifyListeners();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
