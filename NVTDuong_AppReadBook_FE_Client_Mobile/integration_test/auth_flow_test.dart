import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/ui/auth_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const email = String.fromEnvironment('E2E_AUTH_EMAIL');
  const password = String.fromEnvironment('E2E_AUTH_PASSWORD');
  const lockedEmail = String.fromEnvironment('E2E_LOCKED_EMAIL');

  testWidgets('đăng ký và đăng nhập qua backend novi_test', (tester) async {
    expect(email, isNotEmpty);
    expect(password, isNotEmpty);
    expect(lockedEmail, isNotEmpty);
    final session = Session();
    await session.initialize();

    var formNumber = 0;
    Future<void> show({bool register = false}) async {
      formNumber++;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorSchemeSeed: const Color(0xFFE9588D)),
          home: Scaffold(
            body: AuthSheet(
              key: ValueKey(formNumber),
              initialRegister: register,
              popOnSuccess: false,
              onLogin: session.login,
              onRegister: session.register,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(register: true);
    await tester.enterText(find.byKey(const Key('auth-name')), 'NoVi E2E');
    await tester.enterText(find.byKey(const Key('auth-email')), email);
    await tester.enterText(find.byKey(const Key('auth-password')), password);
    await tester.enterText(find.byKey(const Key('auth-confirm')), password);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(session.authenticated, isTrue);
    await session.logout();

    await show();
    await tester.enterText(find.byKey(const Key('auth-email')), email);
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'Sai-mat-khau-123',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);

    await show();
    await tester.enterText(find.byKey(const Key('auth-email')), email);
    await tester.enterText(find.byKey(const Key('auth-password')), password);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(session.authenticated, isTrue);
    await session.logout();

    await show(register: true);
    await tester.enterText(find.byKey(const Key('auth-name')), 'NoVi E2E');
    await tester.enterText(find.byKey(const Key('auth-email')), email);
    await tester.enterText(find.byKey(const Key('auth-password')), password);
    await tester.enterText(find.byKey(const Key('auth-confirm')), password);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Email này đã được đăng ký.'), findsOneWidget);

    await show();
    await tester.enterText(find.byKey(const Key('auth-email')), lockedEmail);
    await tester.enterText(find.byKey(const Key('auth-password')), password);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Tài khoản đang bị khóa.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
