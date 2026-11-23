import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_application_1/core/api.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/main.dart';

const phase = String.fromEnvironment('E2E_PHASE');
const authorEmail = String.fromEnvironment('E2E_AUTHOR_EMAIL');
const readerEmail = String.fromEnvironment('E2E_READER_EMAIL');
const password = String.fromEnvironment('E2E_PASSWORD');
const novelTitle = String.fromEnvironment('E2E_NOVEL_TITLE');
const chapterTitle = 'Chương mở đầu Web handoff';
const oldContent = 'Nội dung công khai ban đầu từ Flutter Windows.';
const rejectedContent = 'Bản chỉnh sửa đang chờ Web từ chối.';
const finalContent = 'Bản chỉnh sửa cuối đã được Web duyệt.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Flutter tác giả bàn giao publishing cho Web admin', (tester) async {
    for (final value in [phase, authorEmail, readerEmail, password, novelTitle]) { expect(value, isNotEmpty); }
    final session = Session(); await session.initialize();
    Future<void> login(String email) async {
      await session.logout(); await tester.pumpWidget(NoviApp(key: UniqueKey(), session: session)); await tester.pumpAndSettle();
      final icon=find.byIcon(Icons.person_outline);await tester.tap(icon.evaluate().isNotEmpty?icon:find.byIcon(Icons.person));await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng nhập / Đăng ký'));await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('auth-email')),email);await tester.enterText(find.byKey(const Key('auth-password')),password);await tester.tap(find.byKey(const Key('auth-submit')));await tester.pumpAndSettle();expect(session.authenticated,isTrue);
    }
    Future<Map<String,dynamic>> ownedNovel() async {final data=await session.api.get('/api/author/novels',auth:true) as List;return Map<String,dynamic>.from(data.firstWhere((e)=>e['title']==novelTitle));}
    Future<Map<String,dynamic>> ownedChapter(String novelId) async {final data=await session.api.get('/api/author/novels/$novelId/chapters',auth:true) as List;return Map<String,dynamic>.from(data.firstWhere((e)=>e['title']==chapterTitle));}
    Future<void> openOwnedNovel(String novelId) async {await tester.tap(find.byKey(const Key('profile-my-novels')));await tester.pumpAndSettle();await tester.tap(find.byKey(Key('author-novel-$novelId')));await tester.pumpAndSettle();}

    if(phase=='create'){
      await login(authorEmail);await tester.tap(find.byKey(const Key('profile-my-novels')));await tester.pumpAndSettle();await tester.tap(find.byKey(const Key('author-create-novel')));await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('novel-title')),novelTitle);await tester.enterText(find.byKey(const Key('novel-description')),'Truyện fixture kiểm thử bàn giao Flutter sang Web.');await tester.tap(find.byKey(const Key('novel-save')));await tester.pumpAndSettle();
      final novel=await ownedNovel();final novelId=s(novel['novelId'])!;await tester.tap(find.byKey(Key('author-novel-$novelId')));await tester.pumpAndSettle();await tester.tap(find.byKey(const Key('author-create-chapter')));await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('chapter-title')),chapterTitle);await tester.enterText(find.byKey(const Key('chapter-content')),oldContent);await tester.tap(find.byKey(const Key('chapter-save')));await tester.pumpAndSettle();final chapter=await ownedChapter(novelId);
      await expectLater(session.api.get('/api/novels/$novelId'),throwsA(isA<ApiException>().having((e)=>e.status,'status',404)));await expectLater(session.api.get('/api/novels/chapters/${chapter['chapterId']}'),throwsA(isA<ApiException>().having((e)=>e.status,'status',404)));return;
    }
    if(phase=='verify-public'){
      await login(readerEmail);
      final explore = find.byIcon(Icons.explore_outlined);
      await tester.tap(
        explore.evaluate().isNotEmpty ? explore : find.byIcon(Icons.explore),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('home-search')), novelTitle);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 450));

      final response = Map<String, dynamic>.from(
        await session.api.get(
          '/api/novels',
          query: {'keyword': novelTitle, 'page': '1', 'pageSize': '12'},
        ),
      );
      final apiItem = Map<String, dynamic>.from(
        (response['items'] as List).firstWhere((item) => item['title'] == novelTitle),
      );
      final result = find.byKey(Key('explore-list-novel-${apiItem['novelId']}'));
      for (var attempt = 0; result.evaluate().isEmpty && attempt < 50; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      for (var attempt = 0; result.evaluate().isEmpty && attempt < 8; attempt++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
        await tester.pumpAndSettle();
      }
      expect(result, findsOneWidget);
      await tester.ensureVisible(result);
      await tester.tap(result);
      await tester.pumpAndSettle();
      final chapter = find.textContaining(chapterTitle).first;
      expect(chapter, findsOneWidget);
      await tester.tap(chapter);
      await tester.pumpAndSettle();
      expect(find.textContaining(oldContent), findsOneWidget);
      return;
    }
    await login(authorEmail);final novel=await ownedNovel();final novelId=s(novel['novelId'])!;final chapter=await ownedChapter(novelId);final chapterId=s(chapter['chapterId'])!;await openOwnedNovel(novelId);
    if(phase=='revision-submit'){
      await tester.tap(find.byKey(Key('author-chapter-$chapterId')));await tester.pumpAndSettle();await tester.enterText(find.byKey(const Key('chapter-content')),rejectedContent);await tester.tap(find.byKey(const Key('chapter-save')));await tester.pumpAndSettle();final publicData=await session.api.get('/api/novels/chapters/$chapterId');expect(publicData['content'],oldContent);return;
    }
    if(phase=='revision-resubmit'){
      expect(find.textContaining('Revision chưa đạt.'),findsOneWidget);await tester.tap(find.byKey(Key('author-chapter-$chapterId')));await tester.pumpAndSettle();await tester.enterText(find.byKey(const Key('chapter-content')),finalContent);await tester.tap(find.byKey(const Key('chapter-save')));await tester.pumpAndSettle();final publicData=await session.api.get('/api/novels/chapters/$chapterId');expect(publicData['content'],oldContent);return;
    }
    if(phase=='verify-final'){final publicData=await session.api.get('/api/novels/chapters/$chapterId');expect(publicData['content'],finalContent);return;}
    fail('E2E_PHASE không hợp lệ: $phase');
  });
}
