import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_application_1/core/api.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/main.dart';

const approvedEmail = String.fromEnvironment('E2E_APPROVED_EMAIL');
const rejectedEmail = String.fromEnvironment('E2E_REJECTED_EMAIL');
const readerPassword = String.fromEnvironment('E2E_READER_PASSWORD');
const adminEmail = String.fromEnvironment('E2E_ADMIN_EMAIL');
const adminPassword = String.fromEnvironment('E2E_ADMIN_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('độc giả gửi đơn, admin duyệt/từ chối và trạng thái cập nhật', (
    tester,
  ) async {
    expect(approvedEmail, isNotEmpty);
    expect(rejectedEmail, isNotEmpty);
    expect(readerPassword, isNotEmpty);
    expect(adminEmail, isNotEmpty);
    expect(adminPassword, isNotEmpty);

    final session = Session();
    await session.initialize();
    await session.logout();
    await tester.pumpWidget(NoviApp(session: session));
    await tester.pumpAndSettle();

    Future<void> openProfile() async {
      final icon = find.byIcon(Icons.person_outline);
      await tester.tap(
        icon.evaluate().isNotEmpty ? icon : find.byIcon(Icons.person),
      );
      await tester.pumpAndSettle();
    }

    Future<void> login(String email, String password) async {
      await openProfile();
      await tester.tap(find.text('Đăng nhập / Đăng ký'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('auth-email')), email);
      await tester.enterText(find.byKey(const Key('auth-password')), password);
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(session.authenticated, isTrue);
    }

    Future<void> logout() async {
      await openProfile();
      await tester.scrollUntilVisible(
        find.text('Đăng xuất'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      expect(session.authenticated, isFalse);
    }

    Future<void> submitApplication(String email, String message) async {
      await login(email, readerPassword);
      await expectLater(
        session.api.get('/api/admin/author-applications', auth: true),
        throwsA(
          isA<ApiException>().having((error) => error.status, 'status', 403),
        ),
      );
      await tester.tap(find.byKey(const Key('profile-author-application')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('author-application-message')),
        message,
      );
      await tester.tap(find.byKey(const Key('author-application-submit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('author-application-status')),
        findsOneWidget,
      );
      final status = tester.widget<Text>(
        find.byKey(const Key('author-application-status')),
      );
      expect(status.data, 'Đang chờ duyệt');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await logout();
    }

    await submitApplication(approvedEmail, 'Đơn dùng để kiểm thử duyệt.');
    await submitApplication(rejectedEmail, 'Đơn dùng để kiểm thử từ chối.');

    await login(adminEmail, adminPassword);
    await tester.tap(
      find.byKey(const Key('profile-admin-author-applications')),
    );
    await tester.pumpAndSettle();

    final approvedCard = find.ancestor(
      of: find.text(approvedEmail),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: approvedCard, matching: find.text('Duyệt')),
    );
    await tester.pumpAndSettle();

    final rejectedCard = find.ancestor(
      of: find.text(rejectedEmail),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: rejectedCard, matching: find.text('Từ chối')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('admin-author-rejection-reason')),
      'Chưa đủ thông tin kiểm thử.',
    );
    await tester.tap(find.byKey(const Key('admin-author-rejection-confirm')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await logout();

    await login(approvedEmail, readerPassword);
    expect(session.user?.role, 1);
    await session.api.get('/api/author/novels', auth: true);
    expect(session.user?.role, 1);
    await logout();

    await login(rejectedEmail, readerPassword);
    await tester.tap(find.byKey(const Key('profile-author-application')));
    await tester.pumpAndSettle();
    expect(find.text('Đã từ chối'), findsOneWidget);
    expect(find.text('Lý do: Chưa đủ thông tin kiểm thử.'), findsOneWidget);
  });
}
