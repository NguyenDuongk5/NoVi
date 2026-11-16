import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/api.dart';
import 'package:flutter_application_1/ui/auth_sheet.dart';

Widget _app({
  required LoginSubmit login,
  required RegisterSubmit register,
  bool dark = false,
  bool initialRegister = false,
}) => MaterialApp(
  theme: ThemeData(colorSchemeSeed: const Color(0xFFE9588D)),
  darkTheme: ThemeData.dark().copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFE9588D),
      brightness: Brightness.dark,
    ),
  ),
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Scaffold(
    body: AuthSheet(
      onLogin: login,
      onRegister: register,
      initialRegister: initialRegister,
    ),
  ),
);

void main() {
  Future<void> noopLogin(String email, String password) async {}
  Future<void> noopRegister(
    String name,
    String email,
    String password,
    String confirm,
  ) async {}

  testWidgets('đăng nhập không gửi khi trống hoặc email sai', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(login: (email, password) async => calls++, register: noopRegister),
    );

    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();
    expect(find.text('Vui lòng nhập email.'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);
    expect(calls, 0);

    await tester.enterText(find.byKey(const Key('auth-email')), 'email-sai');
    await tester.enterText(find.byKey(const Key('auth-password')), '12345678');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();
    expect(find.text('Email không đúng định dạng.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('đăng ký kiểm tra mật khẩu 8 ký tự và nhập lại', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        login: noopLogin,
        register: (name, email, password, confirm) async => calls++,
        initialRegister: true,
      ),
    );
    await tester.enterText(find.byKey(const Key('auth-name')), 'Dương');
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'duong@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), '1234567');
    await tester.enterText(find.byKey(const Key('auth-confirm')), '1234568');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();
    expect(find.text('Mật khẩu phải có từ 8 đến 128 ký tự.'), findsOneWidget);
    expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('401, khóa và email trùng có thông báo riêng', (tester) async {
    await tester.pumpWidget(
      _app(
        login: (email, password) => throw ApiException(401, 'server text'),
        register: noopRegister,
      ),
    );
    await tester.enterText(find.byKey(const Key('auth-email')), 'a@b.com');
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();
    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        login: (email, password) => throw ApiException(403, 'server text'),
        register: noopRegister,
      ),
    );
    await tester.enterText(find.byKey(const Key('auth-email')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('auth-password')), 'password');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();
    expect(find.text('Tài khoản đang bị khóa.'), findsOneWidget);
  });

  testWidgets('validation errors backend đặt đúng dưới trường', (tester) async {
    await tester.pumpWidget(
      _app(
        login: noopLogin,
        register: (name, email, password, confirm) => throw ApiException(
          400,
          'One or more validation errors occurred.',
          fieldErrors: const {
            'Password': ['minimum length is 8'],
          },
        ),
        initialRegister: true,
      ),
    );
    await tester.enterText(find.byKey(const Key('auth-name')), 'Dương');
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'duong@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), '12345678');
    await tester.enterText(find.byKey(const Key('auth-confirm')), '12345678');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();
    expect(find.text('Mật khẩu phải có từ 8 đến 128 ký tự.'), findsOneWidget);
    expect(find.byKey(const Key('auth-general-error')), findsNothing);
  });

  testWidgets('loading chặn gửi lặp và dispose an toàn', (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        login: (email, password) {
          calls++;
          return pending.future;
        },
        register: noopRegister,
      ),
    );
    await tester.enterText(find.byKey(const Key('auth-email')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('auth-password')), 'password');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('auth-submit')), warnIfMissed: false);
    expect(calls, 1);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.completeError(ApiException(500, 'server'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('form hẹp sáng và tối không bị tràn', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        _app(
          login: noopLogin,
          register: noopRegister,
          initialRegister: true,
          dark: dark,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
