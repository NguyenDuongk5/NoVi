import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/core/api.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/ui/screens.dart';

const fixtureTitle = String.fromEnvironment('E2E_NOVEL_TITLE');
const categoryName = String.fromEnvironment('E2E_CATEGORY_NAME');
const novelId = String.fromEnvironment('E2E_NOVEL_ID');
const chapterId = String.fromEnvironment('E2E_CHAPTER_ID');
const email1 = String.fromEnvironment('E2E_EMAIL_1');
const email2 = String.fromEnvironment('E2E_EMAIL_2');
const password = String.fromEnvironment('E2E_PASSWORD');
const mysql = String.fromEnvironment('E2E_MYSQL');

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 200),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 15),
  );
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
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

  testWidgets('luồng độc giả Windows với backend và novi_test', (tester) async {
    expect([
      fixtureTitle,
      categoryName,
      novelId,
      chapterId,
      email1,
      email2,
      password,
      mysql,
    ], everyElement(isNotEmpty));
    expect(
      (await sql('SELECT DATABASE()')).stdout.toString().trim(),
      'novi_test',
    );
    await const FlutterSecureStorage().deleteAll();
    final session = Session();
    await session.initialize();
    await tester.pumpWidget(NoviApp(session: session));
    await settle(tester);

    // Khách: tải danh sách, tìm kiếm, lọc, chi tiết và đọc công khai.
    expect(find.text(fixtureTitle), findsWidgets);
    final search = find.byType(SearchBar);
    await tester.enterText(search, fixtureTitle);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    expect(find.text(fixtureTitle), findsWidgets);
    await tapText(tester, categoryName);
    expect(find.text(fixtureTitle), findsWidgets);
    await tapText(tester, fixtureTitle);
    await tapText(tester, 'Chương 1: Chapter one');
    expect(find.textContaining('Flutter scroll and progress'), findsOneWidget);
    await tapText(tester, 'Chương sau');
    expect(find.text('Chapter two'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    // Đăng ký tài khoản thứ nhất qua UI.
    await tapText(tester, 'Hồ sơ');
    await tapText(tester, 'Đăng nhập / Đăng ký');
    await tapText(tester, 'Chưa có tài khoản?');
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Độc giả E2E Một');
    await tester.enterText(fields.at(1), email1);
    await tester.enterText(fields.at(2), password);
    await tapText(tester, 'Đăng ký');
    expect(find.text(email1), findsOneWidget);

    // Sửa hồ sơ.
    await tapText(tester, 'Sửa hồ sơ');
    await tester.enterText(find.byType(TextField).at(1), 'Tên E2E đã sửa');
    await tapText(tester, 'Lưu');
    expect(find.text('Tên E2E đã sửa'), findsOneWidget);

    // Lưu truyện, mở chương, cuộn, đổi font/nền và chuyển chương.
    await tapText(tester, 'Trang chủ');
    await tester.enterText(find.byType(SearchBar), fixtureTitle);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    await tapText(tester, fixtureTitle);
    await tester.tap(find.byIcon(Icons.bookmark_border));
    await settle(tester);
    await tapText(tester, 'Chương 1: Chapter one');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(
      find.byIcon(Icons.more_vert).evaluate().isNotEmpty
          ? find.byIcon(Icons.more_vert)
          : find.byType(PopupMenuButton<int>),
    );
    await settle(tester);
    await tapText(tester, 'Chữ lớn');
    await tester.tap(find.byType(PopupMenuButton<int>));
    await settle(tester);
    await tapText(tester, 'Nền vàng');
    await tapText(tester, 'Chương sau');
    expect(find.text('Chapter two'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    await tapText(tester, 'Tủ sách');
    expect(find.text(fixtureTitle), findsOneWidget);
    await tapText(tester, 'Lịch sử');
    expect(find.text(fixtureTitle), findsWidgets);

    // Continue phải mở chương gần nhất; dựng lại app vẫn đọc token an toàn.
    final restoreProgressRequests = <Object?>[];
    session.api.onRequest = (method, path, body) {
      if (method == 'PUT' && path.endsWith('/progress')) {
        restoreProgressRequests.add(body);
      }
    };
    await tapText(tester, fixtureTitle);
    await tapText(tester, 'Tiếp tục đọc');
    expect(find.text('Chapter two'), findsOneWidget);
    expect(
      restoreProgressRequests,
      isEmpty,
      reason: 'Khôi phục vị trí không được tự gửi progress=0',
    );
    session.api.onRequest = null;
    await tester.pageBack();
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    final restoredSession = Session();
    await restoredSession.initialize();
    await tester.pumpWidget(NoviApp(session: restoredSession));
    await settle(tester);
    await tapText(tester, 'Hồ sơ');
    expect(find.text(email1), findsOneWidget);

    // Đăng xuất rồi đăng nhập lại qua UI.
    await tapText(tester, 'Đăng xuất');
    await tapText(tester, 'Đăng nhập / Đăng ký');
    await tester.enterText(find.byType(TextField).at(0), email1);
    await tester.enterText(find.byType(TextField).at(1), password);
    await tapText(tester, 'Đăng nhập');
    expect(find.text(email1), findsOneWidget);

    // Token không hợp lệ phải nhận 401, đăng xuất và xóa secure storage.
    restoredSession.token = 'invalid-e2e-token';
    await tapText(tester, 'Tủ sách');
    expect(find.text('Đăng nhập để sử dụng'), findsOneWidget);
    expect(
      await const FlutterSecureStorage().read(key: 'access_token'),
      isNull,
    );

    // Tài khoản hai không được thấy dữ liệu riêng tài khoản một.
    await tapText(tester, 'Hồ sơ');
    await tapText(tester, 'Đăng nhập / Đăng ký');
    await tapText(tester, 'Chưa có tài khoản?');
    await tester.enterText(find.byType(TextField).at(0), 'Độc giả E2E Hai');
    await tester.enterText(find.byType(TextField).at(1), email2);
    await tester.enterText(find.byType(TextField).at(2), password);
    await tapText(tester, 'Đăng ký');
    await tapText(tester, 'Tủ sách');
    expect(find.text('Tủ sách đang trống.'), findsOneWidget);
    await tapText(tester, 'Lịch sử');
    expect(find.text('Chưa có lịch sử đọc.'), findsOneWidget);

    // Khóa tài khoản làm API trả 403: không crash; 401 được test riêng ở unit.
    final locked = await sql("UPDATE user SET status=0 WHERE email='$email2'");
    expect(locked.exitCode, 0);
    await tester.drag(find.byType(ListView), const Offset(0, 200));
    await tester.pumpAndSettle();

    // Đối chiếu session/history/progress/view tài khoản một.
    final evidence = await sql(
      "SELECT (SELECT COUNT(*) FROM reading_session rs JOIN user u ON u.user_id=rs.user_id WHERE u.email='$email1'),(SELECT COUNT(*) FROM reading_history rh JOIN user u ON u.user_id=rh.user_id WHERE u.email='$email1'),(SELECT COUNT(*) FROM reading_progress rp JOIN user u ON u.user_id=rp.user_id WHERE u.email='$email1'),(SELECT COUNT(*) FROM chapter_view cv JOIN user u ON u.user_id=cv.user_id WHERE u.email='$email1')",
    );
    expect(evidence.exitCode, 0);
    final counts = evidence.stdout
        .toString()
        .trim()
        .split('\t')
        .map(int.parse)
        .toList();
    expect(counts, everyElement(greaterThan(0)));

    // Nội dung bị ẩn sau khi đã từng tải không được mở lại và app không crash.
    await tapText(tester, 'Trang chủ');
    await tester.enterText(find.byType(SearchBar), fixtureTitle);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    await tapText(tester, fixtureTitle);
    final hidden = await sql(
      "UPDATE chapter SET visibility=1 WHERE chapter_id='$chapterId'",
    );
    expect(hidden.exitCode, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          session: restoredSession,
          chapters: [
            ChapterInfo.from({
              'chapterId': chapterId,
              'chapterNumber': 1,
              'title': 'Chapter one',
            }),
          ],
          index: 0,
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Thử lại'), findsOneWidget);
    final restored = await sql(
      "UPDATE chapter SET visibility=0 WHERE chapter_id='$chapterId'",
    );
    expect(restored.exitCode, 0);
  });
}
