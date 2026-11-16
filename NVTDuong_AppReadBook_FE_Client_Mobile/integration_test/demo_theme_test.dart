import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/core/theme_controller.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 200),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 20),
);

void main() {
  testWidgets('Windows chụp dữ liệu demo thật ở theme sáng và tối', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await NoviThemeController.instance.setMode(ThemeMode.light);
    final session = Session();
    await session.initialize();
    await tester.pumpWidget(NoviApp(session: session));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'Bên Nhau Trọn Đời');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('Bên Nhau Trọn Đời'), findsWidgets);
    expect(find.byTooltip('Bảng xếp hạng'), findsOneWidget);

    await NoviThemeController.instance.setMode(ThemeMode.dark);
    await settle(tester);
    expect(Theme.of(tester.element(find.text('NoVi'))).brightness, Brightness.dark);

    await tester.tap(find.byTooltip('Bảng xếp hạng'));
    await settle(tester);
    expect(find.text('Bảng xếp hạng'), findsOneWidget);

    await NoviThemeController.instance.setMode(ThemeMode.light);
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
