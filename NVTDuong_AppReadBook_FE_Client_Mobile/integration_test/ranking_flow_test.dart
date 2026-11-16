import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/main.dart';

const rankingTitle = String.fromEnvironment('E2E_RANKING_TITLE');
const rankingCategory = String.fromEnvironment('E2E_RANKING_CATEGORY');
const rankingNovelId = String.fromEnvironment('E2E_RANKING_NOVEL_ID');
const narrowCategory = String.fromEnvironment('E2E_NARROW_CATEGORY');
const pageTwoTitle = String.fromEnvironment('E2E_PAGE_TWO_TITLE');
const mysql = String.fromEnvironment('E2E_MYSQL');

final integrationBinding =
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 200),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 20),
);

Future<int> viewCount() async {
  final result = await Process.run(mysql, [
    '--login-path=novi_test_setup',
    '--database=novi_test',
    '--batch',
    '--skip-column-names',
    '--execute=SELECT COUNT(*) FROM chapter_view cv JOIN chapter c ON c.chapter_id=cv.chapter_id WHERE c.novel_id=\'$rankingNovelId\'',
  ]);
  expect(result.exitCode, 0);
  return int.parse(result.stdout.toString().trim());
}

void main() {
  testWidgets('Trang chủ → BXH → lọc → chi tiết giữ dữ liệu thật', (
    tester,
  ) async {
    expect([
      rankingTitle,
      rankingCategory,
      rankingNovelId,
      mysql,
    ], everyElement(isNotEmpty));
    await const FlutterSecureStorage().deleteAll();
    final beforeViews = await viewCount();
    final session = Session();
    await session.initialize();
    await tester.pumpWidget(NoviApp(session: session));
    await settle(tester);

    expect(find.text('BXH tháng này'), findsOneWidget);
    expect(find.byTooltip('Bảng xếp hạng'), findsOneWidget);
    expect(find.text(rankingTitle), findsWidgets);

    await tester.tap(find.byTooltip('Bảng xếp hạng'));
    await settle(tester);
    expect(find.text('Bảng xếp hạng'), findsOneWidget);
    expect(find.text(rankingTitle), findsOneWidget);

    await tester.tap(find.text('Tất cả').first);
    await settle(tester);
    await tester.tap(find.text(rankingCategory).first);
    await settle(tester);
    expect(find.text(rankingTitle), findsOneWidget);

    await tester.tap(find.text(rankingTitle));
    await settle(tester);
    expect(find.text(rankingTitle), findsWidgets);
    await tester.pageBack();
    await settle(tester);
    expect(find.text(rankingCategory), findsWidgets);
    expect(find.text(rankingTitle), findsOneWidget);

    expect(
      await viewCount(),
      beforeViews,
      reason: 'Mở BXH/chi tiết không được tạo chapter_view',
    );
  });

  testWidgets('Windows hẹp: home, bottom sheet, bộ lọc và phân trang', (
    tester,
  ) async {
    expect([narrowCategory, pageTwoTitle], everyElement(isNotEmpty));
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await const FlutterSecureStorage().deleteAll();
    final session = Session();
    await session.initialize();
    await tester.pumpWidget(NoviApp(session: session));
    await settle(tester);

    expect(find.byTooltip('Bảng xếp hạng'), findsOneWidget);
    expect(find.text('BXH tháng này'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture('ranking_home_360x800');

    final preview = find.byType(PageView);
    expect(preview, findsOneWidget);
    await tester.drag(preview, const Offset(-260, 0));
    await settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Bảng xếp hạng'));
    await settle(tester);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tải thêm'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Tải thêm'));
    await settle(tester);
    expect(find.text(pageTwoTitle), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await settle(tester);
    expect(find.text('Lọc bảng xếp hạng'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(narrowCategory),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(narrowCategory));
    await settle(tester);
    expect(
      find.text(pageTwoTitle),
      findsNothing,
      reason: 'Đổi bộ lọc phải bỏ dữ liệu trang 2 cũ',
    );
    expect(find.text(rankingTitle), findsOneWidget);

    for (final label in ['Tuần này', 'Tháng này', 'Tất cả']) {
      await tester.tap(find.text(label).first);
      await settle(tester);
      expect(find.text(rankingTitle), findsOneWidget);
    }

    await tester.tap(find.byIcon(Icons.tune));
    await settle(tester);
    await tester.tap(find.text('Hoàn thành'));
    await settle(tester);
    expect(find.text(rankingTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture('ranking_filter_360x800');

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(1.6),
        ),
        child: NoviApp(session: session),
      ),
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Bảng xếp hạng'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await _capture('ranking_390x844_text_160');
  });
}

Future<void> _capture(String name) async {
  final bytes = await integrationBinding.takeScreenshot(name);
  final directory = Directory('artifacts/screenshots');
  directory.createSync(recursive: true);
  File('${directory.path}/$name.png').writeAsBytesSync(bytes);
}
