import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_application_1/core/api.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/main.dart';

const phase = String.fromEnvironment('E2E_PHASE');
const approvedEmail = String.fromEnvironment('E2E_APPROVED_EMAIL');
const rejectedEmail = String.fromEnvironment('E2E_REJECTED_EMAIL');
const password = String.fromEnvironment('E2E_READER_PASSWORD');
const rejectionReason = 'Thông tin giới thiệu chưa đủ để xét duyệt.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Flutter bàn giao đơn tác giả cho Web admin', (tester) async {
    expect(phase, anyOf('submit', 'verify'));
    expect(approvedEmail, isNotEmpty);
    expect(rejectedEmail, isNotEmpty);
    expect(password, isNotEmpty);
    final session = Session();
    await session.initialize();

    Future<void> reset() async {
      await session.logout();
      await tester.pumpWidget(NoviApp(key: UniqueKey(), session: session));
      await tester.pumpAndSettle();
    }

    Future<void> login(String email) async {
      await reset();
      final outline = find.byIcon(Icons.person_outline);
      await tester.tap(outline.evaluate().isNotEmpty ? outline : find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng nhập / Đăng ký'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('auth-email')), email);
      await tester.enterText(find.byKey(const Key('auth-password')), password);
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(session.authenticated, isTrue);
    }

    Future<void> submit(String email, String message) async {
      await login(email);
      await tester.tap(find.byKey(const Key('profile-author-application')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('author-application-message')), message);
      await tester.tap(find.byKey(const Key('author-application-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('author-application-status')), findsOneWidget);
      expect(find.text('Đang chờ duyệt'), findsOneWidget);
    }

    if (phase == 'submit') {
      await submit(approvedEmail, 'Đơn kiểm thử chuyển từ Flutter sang Web để duyệt.');
      await submit(rejectedEmail, 'Đơn kiểm thử chuyển từ Flutter sang Web để từ chối.');
      return;
    }

    await login(approvedEmail);
    expect(session.user?.role, 1);
    await session.api.get('/api/author/novels', auth: true);
    await login(rejectedEmail);
    await tester.tap(find.byKey(const Key('profile-author-application')));
    await tester.pumpAndSettle();
    expect(find.text('Đã từ chối'), findsOneWidget);
    expect(find.text('Lý do: $rejectionReason'), findsOneWidget);
    await expectLater(
      session.api.get('/api/author/novels', auth: true),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
    );
  });
}
