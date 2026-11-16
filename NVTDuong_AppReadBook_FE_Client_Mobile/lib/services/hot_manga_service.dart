import 'package:flutter_application_1/models/hot_manga_stories.dart';
import 'base/base_service.dart';

class HomeService extends BaseService {
  HomeService() : super(baseUrl: 'https://localhost:7112/Manga');

  Future<List<HotMangaStories>> getHotmanga() async {
    final item = await get('/all');

    return (item as List)
        .map((json) => HotMangaStories.fromJson(json))
        .toList();
  }
}
