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