class HotMangaStories {
  final String mangaId;
  final String mangaTitle;
  final String mangaImage;

  /// Tạm thời để list rỗng (chưa có bảng category)
  final List<String> categoryId;

  HotMangaStories({
    required this.mangaId,
    required this.mangaTitle,
    required this.mangaImage,
    required this.categoryId,
  });

  factory HotMangaStories.fromJson(Map<String, dynamic> json) {
    return HotMangaStories(
      mangaId: json['manga_id'] ?? '',
      mangaTitle: json['manga_title'] ?? '', // FIX typo BE
      mangaImage: json['manga_image'] ?? 'assets/imgs/default.jpg',
      categoryId: [], // chưa xử lý logic
    );
  }
}
