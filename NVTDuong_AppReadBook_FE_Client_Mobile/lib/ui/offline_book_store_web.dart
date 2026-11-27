import 'dart:convert';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

const String _offlineBoxName = 'offline_books';

Future<Box<dynamic>> _openOfflineBox() async {
  await Hive.initFlutter();

  if (Hive.isBoxOpen(_offlineBoxName)) {
    return Hive.box<dynamic>(_offlineBoxName);
  }

  return Hive.openBox<dynamic>(_offlineBoxName);
}

Future<void> saveOfflineNovel(
  String novelId,
  Map<String, dynamic> data,
) async {
  final box = await _openOfflineBox();

  // Web lưu JSON để đọc lại ổn định sau khi mở lại ứng dụng.
  await box.put(novelId, jsonEncode(data));
  await box.flush();

  print(
    'Đã ghi offline: key=${box.containsKey(novelId)}, tổng=${box.length}',
  );
}

Future<List<Map<String, dynamic>>> listOfflineNovels() async {
  final box = await _openOfflineBox();
  final novels = <Map<String, dynamic>>[];

  for (final key in box.keys) {
    final raw = box.get(key);

    try {
      // Đọc được cả bản cũ lưu Map và bản mới lưu JSON String.
      final decoded = raw is String ? jsonDecode(raw) : raw;

      if (decoded is Map) {
        final novel = <String, dynamic>{};
        decoded.forEach((mapKey, value) {
          novel[mapKey.toString()] = value;
        });

        if (novel['novelId'] != null) {
          novels.add(novel);
        }
      }
    } catch (error) {
      print('Không đọc được truyện offline $key: $error');
    }
  }

  novels.sort((a, b) {
    final aDate = DateTime.tryParse('${a['downloadedAt'] ?? ''}');
    final bDate = DateTime.tryParse('${b['downloadedAt'] ?? ''}');

    return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      aDate ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  });

  // print('Đọc được ${novels.length} truyện offline');
  return novels;
}

Future<void> deleteOfflineNovel(String novelId) async {
  final box = await _openOfflineBox();
  await box.delete(novelId);
  await box.flush();
}