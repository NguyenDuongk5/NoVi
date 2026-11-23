import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/ui/content_report.dart';

void main() {
  testWidgets('báo cáo bắt buộc chọn lý do và giữ mô tả', (tester) async {
    final session = Session();
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
      Scaffold(body: ElevatedButton(onPressed: () => showContentReportDialog(context,
        session: session, targetType: 1, targetId: '00000000-0000-0000-0000-000000000001',
        targetTitle: 'Truyện kiểm thử'), child: const Text('Mở'))))));
    await tester.tap(find.text('Mở')); await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('report-description')), 'Mô tả cần được giữ');
    await tester.tap(find.byKey(const Key('submit-report'))); await tester.pump();
    expect(find.text('Vui lòng chọn lý do báo cáo.'), findsOneWidget);
    expect(find.text('Mô tả cần được giữ'), findsOneWidget);
    expect(find.text('Truyện kiểm thử'), findsOneWidget);
  });
}
