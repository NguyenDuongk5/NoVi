import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_application_1/core/api.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/main.dart';

const authorEmail = String.fromEnvironment('E2E_AUTHOR_EMAIL');
const authorPassword = String.fromEnvironment('E2E_AUTHOR_PASSWORD');
const adminEmail = String.fromEnvironment('E2E_ADMIN_EMAIL');
const adminPassword = String.fromEnvironment('E2E_ADMIN_PASSWORD');
const readerEmail = String.fromEnvironment('E2E_READER_EMAIL');
const readerPassword = String.fromEnvironment('E2E_READER_PASSWORD');
const coverPath = String.fromEnvironment('E2E_COVER_PATH');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('publishing và revision từ Windows UI đến database', (
    tester,
  ) async {
    for (final value in [
      authorEmail,
      authorPassword,
      adminEmail,
      adminPassword,
      readerEmail,
      readerPassword,
      coverPath,
    ]) {
      expect(value, isNotEmpty);
    }
    final session = Session();
    await session.initialize();

    Future<void> reset() async {
      await session.logout();
      await tester.pumpWidget(NoviApp(key: UniqueKey(), session: session));
      await tester.pumpAndSettle();
    }

    Future<void> login(String email, String password) async {
      await reset();
      final outline = find.byIcon(Icons.person_outline);
      await tester.tap(
        outline.evaluate().isNotEmpty ? outline : find.byIcon(Icons.person),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng nhập / Đăng ký'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('auth-email')), email);
      await tester.enterText(find.byKey(const Key('auth-password')), password);
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(session.authenticated, isTrue);
    }

    Future<void> openProfileEntry(Key key) async {
      if (find.byKey(key).evaluate().isEmpty) {
        final outline = find.byIcon(Icons.person_outline);
        await tester.tap(
          outline.evaluate().isNotEmpty ? outline : find.byIcon(Icons.person),
        );
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    Future<void> moderate(
      String type,
      String id, {
      required bool approve,
      String? reason,
    }) async {
      await login(adminEmail, adminPassword);
      await openProfileEntry(const Key('profile-admin-moderation'));
      final row = find.byKey(Key('moderation-$type-$id'));
      for (var attempt = 0; row.evaluate().isEmpty && attempt < 20; attempt++) {
        final next = find.widgetWithText(OutlinedButton, 'Trang sau');
        if (next.evaluate().isEmpty ||
            tester.widget<OutlinedButton>(next).onPressed == null) {
          break;
        }
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(row, findsOneWidget);
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      if (approve) {
        await tester.tap(find.byKey(const Key('moderation-approve')));
      } else {
        await tester.tap(find.byKey(const Key('moderation-reject')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('moderation-reason')),
          reason!,
        );
        await tester.tap(find.byKey(const Key('moderation-reject-confirm')));
      }
      await tester.pumpAndSettle();
    }

    final suffix = DateTime.now().microsecondsSinceEpoch;
    final novelTitle = 'NoVi E2E $suffix';
    const oldContent = 'Nội dung công khai ban đầu do kiểm thử tạo.';
    const rejectedContent = 'Nội dung chỉnh sửa đang bị từ chối.';
    const finalContent = 'Nội dung chỉnh sửa cuối đã được duyệt.';

    await login(authorEmail, authorPassword);
    await expectLater(
      session.api.get('/api/admin/moderation', auth: true),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
    );
    await openProfileEntry(const Key('profile-my-novels'));
    await tester.tap(find.byKey(const Key('author-create-novel')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('novel-title')), novelTitle);
    await tester.enterText(
      find.byKey(const Key('novel-description')),
      'Truyện dùng riêng cho kiểm thử publishing.',
    );
    await tester.tap(find.byKey(const Key('novel-save')));
    await tester.pumpAndSettle();

    var novels =
        await session.api.get('/api/author/novels', auth: true) as List;
    final novel = Map<String, dynamic>.from(
      novels.firstWhere((e) => e['title'] == novelTitle),
    );
    final novelId = s(novel['novelId'])!;
    await session.api.uploadFile('/api/media/novels/$novelId/cover', coverPath);

    await tester.tap(find.byKey(Key('author-novel-$novelId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('author-create-chapter')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chapter-title')),
      'Chương mở đầu',
    );
    await tester.enterText(
      find.byKey(const Key('chapter-content')),
      oldContent,
    );
    await tester.tap(find.byKey(const Key('chapter-save')));
    await tester.pumpAndSettle();
    var chapters =
        await session.api.get(
              '/api/author/novels/$novelId/chapters',
              auth: true,
            )
            as List;
    final chapterId = s(chapters.first['chapterId'])!;

    await login(readerEmail, readerPassword);
    await expectLater(
      session.api.get('/api/novels/$novelId'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
    );
    await expectLater(
      session.api.get('/api/novels/chapters/$chapterId'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
    );

    await moderate('novel', novelId, approve: true);
    await moderate('chapter', chapterId, approve: true);

    await login(readerEmail, readerPassword);
    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('home-search')), novelTitle);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    // Kết quả cuối là thẻ truyện; kết quả đầu có thể là nội dung ô tìm kiếm.
    final publicNovel = find.text(novelTitle).last;
    await tester.ensureVisible(publicNovel);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(publicNovel);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Chương mở đầu').first);
    await tester.pumpAndSettle();
    expect(find.textContaining(oldContent), findsOneWidget);

    // Tạo chương thứ hai, từ chối, tác giả sửa và gửi lại.
    await login(authorEmail, authorPassword);
    await openProfileEntry(const Key('profile-my-novels'));
    await tester.tap(find.byKey(Key('author-novel-$novelId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('author-create-chapter')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chapter-title')),
      'Chương cần bổ sung',
    );
    await tester.enterText(
      find.byKey(const Key('chapter-content')),
      'Bản đầu cần bổ sung.',
    );
    await tester.tap(find.byKey(const Key('chapter-save')));
    await tester.pumpAndSettle();
    chapters =
        await session.api.get(
              '/api/author/novels/$novelId/chapters',
              auth: true,
            )
            as List;
    final rejectedId = s(
      chapters.firstWhere((e) => e['chapterNumber'] == 2)['chapterId'],
    )!;
    await moderate(
      'chapter',
      rejectedId,
      approve: false,
      reason: 'Cần bổ sung nội dung.',
    );

    await login(authorEmail, authorPassword);
    await openProfileEntry(const Key('profile-my-novels'));
    await tester.tap(find.byKey(Key('author-novel-$novelId')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cần bổ sung nội dung.'), findsOneWidget);
    await tester.tap(find.byKey(Key('author-chapter-$rejectedId')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chapter-content')),
      'Nội dung đã được bổ sung.',
    );
    await tester.tap(find.byKey(const Key('chapter-save')));
    await tester.pumpAndSettle();
    await moderate('chapter', rejectedId, approve: true);

    // Revision chương đã công khai: từ chối vẫn giữ bản cũ, duyệt mới đổi bản công khai.
    await login(authorEmail, authorPassword);
    await openProfileEntry(const Key('profile-my-novels'));
    await tester.tap(find.byKey(Key('author-novel-$novelId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('author-chapter-$chapterId')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chapter-content')),
      rejectedContent,
    );
    await tester.tap(find.byKey(const Key('chapter-save')));
    await tester.pumpAndSettle();
    var publicChapter = await session.api.get(
      '/api/novels/chapters/$chapterId',
    );
    expect(publicChapter['content'], oldContent);
    chapters =
        await session.api.get(
              '/api/author/novels/$novelId/chapters',
              auth: true,
            )
            as List;
    var owned = Map<String, dynamic>.from(
      chapters.firstWhere((e) => e['chapterId'] == chapterId),
    );
    var revisionId = s(owned['revisionId'])!;
    await moderate(
      'chapterRevision',
      revisionId,
      approve: false,
      reason: 'Revision chưa đạt.',
    );
    publicChapter = await session.api.get('/api/novels/chapters/$chapterId');
    expect(publicChapter['content'], oldContent);

    await login(authorEmail, authorPassword);
    await openProfileEntry(const Key('profile-my-novels'));
    await tester.tap(find.byKey(Key('author-novel-$novelId')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Revision chưa đạt.'), findsOneWidget);
    await tester.tap(find.byKey(Key('author-chapter-$chapterId')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chapter-content')),
      finalContent,
    );
    await tester.tap(find.byKey(const Key('chapter-save')));
    await tester.pumpAndSettle();
    chapters =
        await session.api.get(
              '/api/author/novels/$novelId/chapters',
              auth: true,
            )
            as List;
    owned = Map<String, dynamic>.from(
      chapters.firstWhere((e) => e['chapterId'] == chapterId),
    );
    revisionId = s(owned['revisionId'])!;
    await moderate('chapterRevision', revisionId, approve: true);
    publicChapter = await session.api.get('/api/novels/chapters/$chapterId');
    expect(publicChapter['content'], finalContent);
  });
}
