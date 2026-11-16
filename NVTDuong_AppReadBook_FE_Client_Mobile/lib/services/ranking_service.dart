// import 'package:flutter_application_1/models/ranking_stories.dart';
// import 'base/base_service.dart';

// /// Service gọi API RankingStories
// /// Dùng để lấy danh sách truyện xếp hạng từ backend
// class RankingStoriesService extends BaseService {
//   // Chú ý: đổi baseUrl đúng với BE của bạn
//   // RankingStoriesService() : super(baseUrl: 'https://localhost:7112/Manga');
//   RankingStoriesService() : super(baseUrl: 'https://localhost:7112/Manga');

//   /// GET /Manga/all
//   /// Lấy toàn bộ danh sách truyện xếp hạng
//   Future<List<RankingStories>> getAllRanking() async {
//     final item = await get('/all');
//     print('RAW API RESULT = $item');

//     final List list = item as List;

//     return List.generate(list.length, (index) {
//       // final json = list[index];
//       final rs = RankingStories.fromJson(list[index], index);

//       print('PARSED ITEM $index = ${rs.title}');
//       // return RankingStories.fromJson(json, index);
//       return rs;
//     });
//   }
// }
import 'package:flutter_application_1/models/ranking_stories.dart';
import 'base/base_service.dart';

class RankingStoriesService extends BaseService {
  RankingStoriesService() : super(baseUrl: 'https://localhost:7112/Manga');

  /// Dùng chung API Manga/all
  Future<List<RankingStories>> getAllRanking() async {
    final item = await get('/all');

    print('RAW API RESULT = $item');

    final List list = item as List;

    // sort theo lượt xem (ranking)
    list.sort(
      (a, b) => (b['manga_views'] ?? 0).compareTo(a['manga_views'] ?? 0),
    );

    return List.generate(list.length, (index) {
      final rs = RankingStories.fromJson(list[index], index);
      print('PARSED ITEM $index = ${rs.title}');
      return rs;
    });
  }
}
