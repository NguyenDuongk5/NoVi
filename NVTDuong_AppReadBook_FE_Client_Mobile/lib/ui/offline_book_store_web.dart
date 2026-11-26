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
  await box.put(novelId, data);
  await box.flush();
}