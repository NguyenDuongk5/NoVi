import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/api.dart';
import 'package:flutter_application_1/core/session.dart';
import 'package:flutter_application_1/ui/author_application.dart';
import 'package:flutter_application_1/ui/screens.dart';
import 'package:flutter_application_1/ui/publishing.dart';

Session _sessionWithRole(int role) {
  final session = Session();
  session
    ..token = 'test-token'
    ..expiresAt = DateTime.now().toUtc().add(const Duration(hours: 1))
    ..user = UserProfile.from(<String, dynamic>{
      'userId': '00000000-0000-0000-0000-000000000001',
      'fullName': 'Người kiểm thử',
      'displayName': 'Kiểm thử',
      'email': 'test@novi.test',
      'role': role,
    });
  return session;
}

void main() {
  test('DTO đơn tác giả đọc trạng thái và lý do từ backend', () {
    final application = AuthorApplication.from(<String, dynamic>{
      'applicationId': 'application-1',
      'userId': 'user-1',
      'fullName': 'Độc giả',
      'email': 'reader@novi.test',
      'message': 'Tôi muốn sáng tác.',
      'status': 2,
      'decisionReason': 'Cần bổ sung giới thiệu.',
      'createdAt': '2026-11-20T00:00:00Z',
    });

    expect(application.statusLabel, 'Đã từ chối');
    expect(application.decisionReason, 'Cần bổ sung giới thiệu.');
  });

  testWidgets('thẻ trạng thái hiển thị lý do từ chối', (tester) async {
    final application = AuthorApplication(
      id: 'application-1',
      userId: 'user-1',
      fullName: 'Độc giả',
      email: 'reader@novi.test',
      status: 2,
      createdAt: DateTime.utc(2026, 11, 20),
      decisionReason: 'Thông tin chưa đầy đủ.',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthorApplicationStatusCard(application: application),
        ),
      ),
    );

    expect(find.text('Đã từ chối'), findsOneWidget);
    expect(find.text('Lý do: Thông tin chưa đầy đủ.'), findsOneWidget);
  });

  testWidgets('người đọc không thấy lối vào admin', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProfilePage(session: _sessionWithRole(0))),
    );

    expect(find.byKey(const Key('profile-author-application')), findsOneWidget);
    expect(
      find.byKey(const Key('profile-admin-author-applications')),
      findsNothing,
    );
  });

  testWidgets('admin không còn lối vào chức năng quản trị trên Flutter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProfilePage(session: _sessionWithRole(2))),
    );

    expect(find.byKey(const Key('profile-admin-author-applications')), findsNothing);
    expect(find.byKey(const Key('profile-admin-moderation')), findsNothing);
    expect(find.byKey(const Key('profile-author-application')), findsNothing);
  });

  testWidgets('tác giả thấy Truyện của tôi nhưng không thấy kiểm duyệt', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ProfilePage(session: _sessionWithRole(1))),
    );
    expect(find.byKey(const Key('profile-my-novels')), findsOneWidget);
    expect(find.byKey(const Key('profile-admin-moderation')), findsNothing);
  });

  testWidgets('admin không thấy kiểm duyệt hay Truyện của tôi', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ProfilePage(session: _sessionWithRole(2))),
    );
    expect(find.byKey(const Key('profile-admin-moderation')), findsNothing);
    expect(find.byKey(const Key('profile-my-novels')), findsNothing);
  });

  test('DTO publishing giữ nội dung công khai và revision riêng', () {
    final chapter = OwnedChapterData.from({
      'chapterId': 'chapter-1',
      'chapterNumber': 1,
      'title': 'Bản công khai',
      'content': 'Nội dung cũ',
      'reviewStatus': 1,
      'revisionId': 'revision-1',
      'revisionStatus': 0,
      'revisionTitle': 'Bản đang duyệt',
      'revisionContent': 'Nội dung mới',
    });
    expect(chapter.content, 'Nội dung cũ');
    expect(chapter.revisionContent, 'Nội dung mới');
    expect(chapter.revisionStatus, 0);
  });
}
