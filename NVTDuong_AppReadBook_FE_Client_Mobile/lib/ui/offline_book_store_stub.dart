// Future<void> saveOfflineNovel(
//   String novelId,
//   Map<String, dynamic> data,
// ) async {
//   throw UnsupportedError(
//     'Tải offline hiện chưa hỗ trợ trên nền tảng này.',
//   );
// }

Future<void> saveOfflineNovel(
  String novelId,
  Map<String, dynamic> data,
) async {
  throw UnsupportedError('Tải offline hiện chưa hỗ trợ trên nền tảng này.');
}

Future<List<Map<String, dynamic>>> listOfflineNovels() async => [];

Future<void> deleteOfflineNovel(String novelId) async {
  throw UnsupportedError('Xóa truyện offline hiện chưa hỗ trợ trên nền tảng này.');
}