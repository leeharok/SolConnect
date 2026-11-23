import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solconnect/main.dart';
import 'package:solconnect/services/auth_service.dart';

void main() {
  testWidgets('로그아웃 상태면 로그인 화면이 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = MockAuthService();
    await auth.init();

    await tester.pumpWidget(SolConnectApp(auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('회원가입'), findsOneWidget);
  });
}
