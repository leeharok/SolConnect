import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/onboarding/role_select_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

import 'services/api_service.dart';
import 'services/api_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark,
  );

  // 백엔드 연결 확인
  try {
    final result = await ApiService.checkHealth();

    debugPrint('✅ 백엔드 연결 성공!');
    debugPrint('서버 응답: ${result['message']}');
  } catch (error) {
    debugPrint('❌ 백엔드 연결 실패: $error');
  }

  // 현재는 기존 MockAuthService 유지
  final AuthService auth = ApiAuthService();
  await auth.init();

  runApp(SolConnectApp(auth: auth));
}

class SolConnectApp extends StatelessWidget {
  const SolConnectApp({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      service: auth,
      child: MaterialApp(
        title: '솔커넥트',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}

/// 로그인 상태에 따라 첫 화면을 결정합니다.
/// 로그인 X → 로그인 / 역할 미선택 → 멘토·멘티 선택 / 프로필 미완성 → 프로필 작성 / 완료 → 홈
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.currentUser;

    final Widget page;
    if (auth.isInitializing) {
      page = const _Splash();
    } else if (user == null) {
      page = const LoginScreen();
    } else if (user.role == null) {
      page = const RoleSelectScreen();
    } else if (!user.isProfileComplete) {
      page = const ProfileSetupScreen();
    } else {
      page = const HomeShell();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(page.runtimeType), child: page),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: AppLogo(size: 34)));
}
