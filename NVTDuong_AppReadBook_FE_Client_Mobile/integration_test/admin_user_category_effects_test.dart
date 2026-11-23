import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/ui/screens.dart';

const lockedEmail = String.fromEnvironment('E2E_LOCKED_EMAIL');
const authorEmail = String.fromEnvironment('E2E_AUTHOR_EMAIL');
const password = String.fromEnvironment('E2E_PASSWORD');
const novelId = String.fromEnvironment('E2E_NOVEL_ID');
const expectRestricted = bool.fromEnvironment('E2E_EXPECT_RESTRICTED', defaultValue: true);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UC07 khóa tài khoản và UC29 ẩn thể loại tác động lên Flutter',
      (tester) async {
    expect([lockedEmail, authorEmail, password, novelId], everyElement(isNotEmpty));

    final lockedSession = Session();
    await lockedSession.initialize();
    await lockedSession.logout();
    await tester.pumpWidget(NoviApp(session: lockedSession));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng nhập / Đăng ký'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-email')), lockedEmail);
    await tester.enterText(find.byKey(const Key('auth-password')), password);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    if (expectRestricted) {
      expect(find.textContaining('Tài khoản đang bị khóa'), findsOneWidget);
      expect(lockedSession.authenticated, isFalse);
    } else {
      expect(lockedSession.authenticated, isTrue,
          reason: 'Tài khoản phải đăng nhập lại được sau khi Web mở khóa.');
    }

    final authorSession = Session();
    await authorSession.initialize();
    await authorSession.login(authorEmail, password);
    await tester.pumpWidget(NoviApp(key: UniqueKey(), session: authorSession));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-my-novels')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('author-create-novel')));
    await tester.pumpAndSettle();
    expect(find.text('Ngôn tình'), expectRestricted ? findsNothing : findsOneWidget,
        reason: expectRestricted
            ? 'Thể loại ẩn không được xuất hiện trong form đăng truyện mới.'
            : 'Thể loại hiện lại phải trở lại form đăng truyện mới.');

    final guestSession = Session();
    await guestSession.initialize();
    await tester.pumpWidget(MaterialApp(
      home: NovelDetailPage(session: guestSession, novelId: novelId),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ngôn tình'), findsOneWidget,
        reason: 'Chi tiết truyện cũ vẫn hiển thị thể loại đã gắn dù đang ẩn.');
  });
}
