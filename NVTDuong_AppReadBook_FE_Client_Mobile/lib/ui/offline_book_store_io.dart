import 'dart:convert';
import 'dart:io';


import 'package:path_provider/path_provider.dart';

Future<void> saveOfflineNovel(
  String novelId,
  Map<String, dynamic> data,
) async {
  final appDirectory = await getApplicationSupportDirectory();
  final offlineDirectory = Directory(
    '${appDirectory.path}${Platform.pathSeparator}offline_books',
  );

  await offlineDirectory.create(recursive: true);

  final safeNovelId = novelId.replaceAll(
    RegExp(r'[^A-Za-z0-9_-]'),
    '_',
  );

  final file = File(
    '${offlineDirectory.path}${Platform.pathSeparator}$safeNovelId.json',
  );

  await file.writeAsString(jsonEncode(data), flush: true);
}


Future<List<Map<String, dynamic>>> listOfflineNovels() async {
  final appDirectory = await getApplicationSupportDirectory();
  final offlineDirectory = Directory(
    '${appDirectory.path}${Platform.pathSeparator}offline_books',
  );

  if (!await offlineDirectory.exists()) return [];

  final novels = <Map<String, dynamic>>[];

  await for (final entity in offlineDirectory.list(followLinks: false)) {
    if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
      continue;
    }

    try {
      final decoded = jsonDecode(await entity.readAsString());
      if (decoded is Map) {
        novels.add(Map<String, dynamic>.from(decoded));
      }
    } on FormatException {
      // Bỏ qua file tải dở hoặc không đọc được.
    } on FileSystemException {
      // Bỏ qua nếu file bị xóa trong lúc đang đọc.
    }
  }

  novels.sort((a, b) {
    final aDate = DateTime.tryParse('${a['downloadedAt'] ?? ''}');
    final bDate = DateTime.tryParse('${b['downloadedAt'] ?? ''}');

    return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      aDate ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  });

  return novels;
}

Future<void> deleteOfflineNovel(String novelId) async {
  final appDirectory = await getApplicationSupportDirectory();
  final offlineDirectory = Directory(
    '${appDirectory.path}${Platform.pathSeparator}offline_books',
  );

  final safeNovelId = novelId.replaceAll(
    RegExp(r'[^A-Za-z0-9_-]'),
    '_',
  );

  final file = File(
    '${offlineDirectory.path}${Platform.pathSeparator}$safeNovelId.json',
  );

  if (await file.exists()) {
    await file.delete();
  }
}