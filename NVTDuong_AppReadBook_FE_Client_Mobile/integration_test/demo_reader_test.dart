import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/ui/home_widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const email = String.fromEnvironment('E2E_DEMO_EMAIL');
const password = String.fromEnvironment('E2E_DEMO_PASSWORD');
const mysql = String.fromEnvironment('E2E_MYSQL');
const title = 'Bên Nhau Trọn Đời';

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 200),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 20),
);

Future<void> tapText(WidgetTester tester, String value) async {
  await tester.tap(find.text(value).first);
  await settle(tester);
}

Future<ProcessResult> sql(String statement) => Process.run(mysql, [
  '--login-path=novi_test_setup',
  '--database=novi_test',
  '--batch',
  '--skip-column-names',
  '--execute=$statement',
]);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('đọc demo, chuyển chương, lịch sử và tiếp tục đọc qua UI', (
    tester,
  ) async {
    expect([email, password, mysql], everyElement(isNotEmpty));
    await const FlutterSecureStorage().deleteAll();
    final session = Session();
    await session.initialize();
    await tester.pumpWidget(NoviApp(session: session));
    await settle(tester);

    await tapText(tester, 'Tôi');
    await tapText(tester, 'Đăng nhập / Đăng ký');
    await tapText(tester, 'Chưa có tài khoản?');
    await tester.enterText(find.byType(TextField).at(0), 'Độc giả Demo NoVi');
    await tester.enterText(find.byType(TextField).at(1), email);
    await tester.enterText(find.byType(TextField).at(2), password);
    await tapText(tester, 'Đăng ký');
    expect(find.text(email), findsOneWidget);
    debugPrint('DEMO_E2E: registered');

    await tapText(tester, 'Khám phá');
    await tester.enterText(find.byType(SearchBar), title);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await settle(tester);
    final resultCard = find.ancestor(
      of: find.text(title),
      matching: find.byType(NovelListCard),
    );
    expect(resultCard, findsOneWidget);
    await tester.tap(resultCard);
    await settle(tester);
    expect(find.text('Danh sách chương'), findsOneWidget);
    debugPrint('DEMO_E2E: detail opened');
    final firstChapter = find.text('Chương 1: Khoảng cách trên trang giấy');
    await tester.scrollUntilVisible(
      firstChapter,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(firstChapter);
    await settle(tester);
    debugPrint('DEMO_E2E: chapter one opened');
    expect(
      find.textContaining(
        'Nội dung minh họa do dự án tạo, không phải bản gốc của tác phẩm.',
      ),
      findsOneWidget,
    );
    await tapText(tester, 'Chương sau');
    expect(find.text('Dấu trang cuối buổi'), findsOneWidget);
    debugPrint('DEMO_E2E: chapter two opened');
    await tester.pageBack();
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    await tapText(tester, 'Tủ sách');
    await tapText(tester, 'Lịch sử');
    expect(find.text(title), findsWidgets);
    debugPrint('DEMO_E2E: history visible');
    await tapText(tester, title);
    await tapText(tester, 'Đọc / Đọc tiếp');
    expect(find.text('Dấu trang cuối buổi'), findsOneWidget);
    debugPrint('DEMO_E2E: continue opened chapter two');

    final evidence = await sql(
      "SELECT (SELECT COUNT(*) FROM reading_session rs JOIN user u ON u.user_id=rs.user_id WHERE u.email='$email'),"
      "(SELECT COUNT(*) FROM reading_history rh JOIN user u ON u.user_id=rh.user_id WHERE u.email='$email'),"
      "(SELECT COUNT(*) FROM reading_progress rp JOIN user u ON u.user_id=rp.user_id WHERE u.email='$email'),"
      "(SELECT COUNT(*) FROM chapter_view cv JOIN user u ON u.user_id=cv.user_id WHERE u.email='$email')",
    );
    expect(evidence.exitCode, 0);
    final counts = evidence.stdout
        .toString()
        .trim()
        .split('\t')
        .map(int.parse)
        .toList();
    expect(counts, everyElement(greaterThan(0)));
    debugPrint('DEMO_E2E: database evidence $counts');
    expect(tester.takeException(), isNull);
  });
}
