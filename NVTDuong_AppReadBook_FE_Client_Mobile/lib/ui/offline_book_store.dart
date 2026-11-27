export 'offline_book_store_stub.dart'
    if (dart.library.io) 'offline_book_store_io.dart'
    if (dart.library.js_interop) 'offline_book_store_web.dart';

//     Future<List<Map<String, dynamic>>> listOfflineNovels() async => [];

// Future<void> deleteOfflineNovel(String novelId) async {
//   throw UnsupportedError(
//     'Xóa truyện offline hiện chưa hỗ trợ trên nền tảng này.',
//   );
// }