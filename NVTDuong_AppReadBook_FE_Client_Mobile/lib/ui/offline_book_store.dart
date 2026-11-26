export 'offline_book_store_stub.dart'
    if (dart.library.io) 'offline_book_store_io.dart'
    if (dart.library.js_interop) 'offline_book_store_web.dart';