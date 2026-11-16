import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/api.dart';
import 'package:flutter_application_1/core/theme_controller.dart';
import 'package:flutter_application_1/ui/screens.dart';
import 'package:flutter_application_1/ui/home_widgets.dart';
import 'package:flutter_application_1/ui/ranking_screen.dart';
import 'package:flutter_application_1/ui/ranking_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Lựa chọn giao diện được lưu và khôi phục trên thiết bị', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = NoviThemeController.instance;
    await controller.setMode(ThemeMode.dark);
    expect(
      (await SharedPreferences.getInstance()).getString('novi_theme_mode'),
      'dark',
    );
    await controller.setMode(ThemeMode.system);
  });

  test('DTO truyện đọc đúng phản hồi backend', () {
    final novel = Novel.from(<String, dynamic>{
      'novelId': 'novel-1',
      'title': 'Truyện thử',
      'viewCount': 12,
      'updatedAt': '2026-10-30T00:00:00Z',
    });

    expect(novel.id, 'novel-1');
    expect(novel.title, 'Truyện thử');
    expect(novel.views, 12);
  });

  testWidgets('Ảnh bìa trống dùng placeholder cục bộ', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Cover(null))),
    );

    expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
  });

  testWidgets('Thẻ truyện chỉ hiện nhãn hoàn thành từ dữ liệu backend', (
    tester,
  ) async {
    final novel = Novel.from(<String, dynamic>{
      'novelId': 'novel-1',
      'title': 'Một truyện có tên rất dài để kiểm tra bố cục',
      'completionStatus': 1,
      'viewCount': 25,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NovelListCard(novel: novel, onTap: () {}),
        ),
      ),
    );

    expect(find.text('Hoàn thành'), findsOneWidget);
    expect(find.text('25 lượt đọc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Thanh đọc tiếp có nút đọc và đóng riêng', (tester) async {
    var continued = false;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContinueReadingBar(
            coverUrl: null,
            title: 'Truyện đang đọc',
            chapter: 'Chương 2: Trở lại',
            onContinue: () => continued = true,
            onClose: () => closed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Đọc tiếp'));
    await tester.tap(find.byIcon(Icons.close));
    expect(continued, isTrue);
    expect(closed, isTrue);
  });

  testWidgets('Tab đầu trang giữ đúng mục được chọn', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: NoviTopTabs(
              labels: const ['Khám phá', 'Thể loại'],
              selectedIndex: selected,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Thể loại'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  test('DTO bảng xếp hạng giữ số hạng và số lượt đọc chính xác', () {
    final data = RankingPageData.from(<String, dynamic>{
      'items': [
        {
          'rank': 21,
          'novelId': 'novel-21',
          'title': 'Truyện xếp hạng',
          'periodViewCount': 1234567,
          'completionStatus': 1,
          'categories': [
            {'categoryId': 'category-1', 'name': 'Kỳ ảo'},
          ],
        },
      ],
      'period': 'month',
      'page': 2,
      'pageSize': 20,
      'totalItems': 30,
      'periodStartUtc': '2026-09-30T17:00:00Z',
      'periodEndUtc': '2026-10-30T00:00:00Z',
    });

    expect(data.items.single.rank, 21);
    expect(data.items.single.periodViewCount, 1234567);
    expect(data.items.single.categories.single.name, 'Kỳ ảo');
    expect(compactCount(1234567), '1.2M');
  });

  test('Response BXH cũ không được cổng request chấp nhận', () {
    final gate = RankingRequestGate();
    final oldRequest = gate.next();
    final newRequest = gate.next();

    expect(gate.accepts(oldRequest), isFalse);
    expect(gate.accepts(newRequest), isTrue);
  });

  testWidgets('Hàng BXH không tràn ở 360px với chữ lớn và dữ liệu dài', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final item = RankedNovel.from(<String, dynamic>{
      'rank': 1,
      'novelId': 'novel-long',
      'title':
          'Tên truyện rất dài dùng để kiểm tra hai dòng không che huy hiệu',
      'originalAuthor': 'Tên tác giả cũng rất dài',
      'periodViewCount': 123456789,
      'completionStatus': 1,
      'categories': [
        {'categoryId': 'category-1', 'name': 'Thể loại có tên rất dài'},
        {'categoryId': 'category-2', 'name': 'Kỳ ảo phương Đông'},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RankingNovelRow(item: item, onTap: () {}),
          ),
        ),
      ),
    );

    expect(find.text('123M lượt đọc'), findsOneWidget);
    expect(find.byType(RankingBadge), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
