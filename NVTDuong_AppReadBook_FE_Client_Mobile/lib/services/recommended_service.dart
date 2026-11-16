// import 'package:flutter_application_1/models/recommended_manga.dart';
// import 'base/base_service.dart';

// class RecommendedMangaService extends BaseService {
//   static const String _host = 'https://localhost:7112';

//   RecommendedMangaService() : super(baseUrl: '$_host/Manga');

//   Future<List<RecommendedManga>> getAllRecommended() async {
//     final item = await get('/all');

//     return (item as List).map((json) {
//       // clone json để sửa ảnh
//       final Map<String, dynamic> data = Map<String, dynamic>.from(json);

//       final img = data['manga_image'];
//       if (img != null && !img.startsWith('http')) {
//         data['manga_image'] = '$_host/$img';
//       }

//       return RecommendedManga.fromJson(data);
//     }).toList();
//   }
// }
import 'package:flutter_application_1/models/recommended_manga.dart';
import 'base/base_service.dart';

class RecommendedMangaService extends BaseService {
  RecommendedMangaService() : super(baseUrl: 'https://localhost:7112/Manga');

  Future<List<RecommendedManga>> getAllRecommended() async {
    final item = await get('/all');

    return (item as List)
        .map((json) => RecommendedManga.fromJson(json))
        .toList();
  }
}
