import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.status, this.message, {this.fieldErrors = const {}});
  final int status;
  final String message;
  final Map<String, List<String>> fieldErrors;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({this.tokenProvider, this.onUnauthorized});
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5148',
  );
  final String? Function()? tokenProvider;
  final Future<void> Function()? onUnauthorized;
  void Function(String method, String path, Object? body)? onRequest;
  Uri _uri(String path, [Map<String, String?> query = const {}]) =>
      Uri.parse('$baseUrl$path').replace(
        queryParameters: {
          for (final e in query.entries)
            if (e.value != null) e.key: e.value!,
        },
      );
  Future<dynamic> get(
    String path, {
    Map<String, String?> query = const {},
    bool auth = false,
  }) => _send('GET', path, query: query, auth: auth);
  Future<dynamic> post(String path, {Object? body, bool auth = false}) =>
      _send('POST', path, body: body, auth: auth);
  Future<dynamic> put(String path, {Object? body, bool auth = false}) =>
      _send('PUT', path, body: body, auth: auth);
  Future<dynamic> patch(String path, {Object? body, bool auth = false}) =>
      _send('PATCH', path, body: body, auth: auth);
  Future<dynamic> delete(String path, {bool auth = false}) =>
      _send('DELETE', path, auth: auth);
  Future<dynamic> uploadFile(String path, String filePath) async {
    final token = tokenProvider?.call();
    if (token == null) throw ApiException(401, 'Vui lòng đăng nhập.');
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    late final http.Response response;
    try {
      response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 30)),
      ).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw ApiException(0, 'Tải ảnh quá thời gian. Vui lòng thử lại.');
    } on http.ClientException {
      throw ApiException(0, 'Không thể kết nối máy chủ.');
    }
    if (response.statusCode == 401) await onUnauthorized?.call();
    dynamic decoded;
    if (response.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {}
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['message'] ?? decoded['detail'] ?? decoded['title'])
                ?.toString()
          : null;
      throw ApiException(response.statusCode, message ?? 'Tải ảnh thất bại.');
    }
    return decoded;
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String?> query = const {},
    Object? body,
    bool auth = false,
  }) async {
    onRequest?.call(method, path, body);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (auth) {
      final token = tokenProvider?.call();
      if (token == null) throw ApiException(401, 'Vui lòng đăng nhập.');
      headers['Authorization'] = 'Bearer $token';
    }
    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    late final http.Response response;
    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      response = await http.Response.fromStream(
        streamed,
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException(
        0,
        'Yêu cầu mất quá nhiều thời gian. Vui lòng thử lại.',
      );
    } on http.ClientException {
      throw ApiException(
        0,
        'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.',
      );
    }
    if (response.statusCode == 401 && auth) await onUnauthorized?.call();
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = response.body;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final fieldErrors = <String, List<String>>{};
      if (decoded is Map && decoded['errors'] is Map) {
        for (final entry in (decoded['errors'] as Map).entries) {
          final value = entry.value;
          fieldErrors[entry.key.toString()] = value is List
              ? value.map((item) => item.toString()).toList()
              : [value.toString()];
        }
      }
      final message = decoded is Map
          ? (decoded['message'] ?? decoded['detail'] ?? decoded['title'])
                ?.toString()
          : null;
      final safeMessage = switch (response.statusCode) {
        429 => 'Bạn thao tác quá nhiều. Vui lòng thử lại sau.',
        >= 500 => 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
        _ => message,
      };
      throw ApiException(
        response.statusCode,
        safeMessage ?? 'Yêu cầu thất bại (${response.statusCode}).',
        fieldErrors: fieldErrors,
      );
    }
    return decoded;
  }
}

String? mediaUrl(String? value) {
  if (value == null || value.isEmpty) return null;
  if (Uri.tryParse(value)?.hasScheme == true) return value;
  final root = Uri.parse(ApiClient.baseUrl);
  return root
      .resolve(value.startsWith('/') ? value.substring(1) : value)
      .toString();
}

String? s(dynamic v) => v?.toString();
int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

class Novel {
  Novel.from(Map<String, dynamic> j)
    : id = s(j['novelId'])!,
      title = s(j['title']) ?? '',
      author = s(j['originalAuthor']),
      cover = mediaUrl(s(j['coverUrl'])),
      description = s(j['description']),
      completionStatus = i(j['completionStatus']),
      updatedAt = DateTime.tryParse(s(j['updatedAt']) ?? ''),
      views = i(j['viewCount']),
      categories = (j['categories'] as List? ?? const [])
          .map((e) => Category.from(Map<String, dynamic>.from(e)))
          .toList();
  final String id, title;
  final String? author, cover, description;
  final int completionStatus;
  final DateTime? updatedAt;
  final int views;
  final List<Category> categories;
  bool get completed => completionStatus == 1;
}

class Category {
  Category.from(Map<String, dynamic> j)
    : id = s(j['categoryId'])!,
      name = s(j['name']) ?? '';
  final String id, name;
}

class RankedNovel {
  RankedNovel.from(Map<String, dynamic> j)
    : rank = i(j['rank']),
      periodViewCount = i(j['periodViewCount']),
      novel = Novel.from(j),
      categories = (j['categories'] as List? ?? const [])
          .map((e) => Category.from(Map<String, dynamic>.from(e)))
          .toList();

  final int rank;
  final int periodViewCount;
  final Novel novel;
  final List<Category> categories;
}

class RankingPageData {
  RankingPageData.from(Map<String, dynamic> j)
    : items = (j['items'] as List)
          .map((e) => RankedNovel.from(Map<String, dynamic>.from(e)))
          .toList(),
      page = i(j['page']),
      pageSize = i(j['pageSize']),
      total = i(j['totalItems']),
      period = s(j['period']) ?? 'month',
      periodStartUtc = DateTime.tryParse(s(j['periodStartUtc']) ?? ''),
      periodEndUtc = DateTime.tryParse(s(j['periodEndUtc']) ?? '');

  final List<RankedNovel> items;
  final int page, pageSize, total;
  final String period;
  final DateTime? periodStartUtc, periodEndUtc;
}

class ChapterInfo {
  ChapterInfo.from(Map<String, dynamic> j)
    : id = s(j['chapterId'])!,
      number = i(j['chapterNumber']),
      title = s(j['title']) ?? '';
  final String id, title;
  final int number;
}

class ChapterContent extends ChapterInfo {
  ChapterContent.from(super.j)
    : novelId = s(j['novelId'])!,
      content = s(j['content']) ?? '',
      super.from();
  final String novelId, content;
}

class UserProfile {
  UserProfile.from(Map<String, dynamic> j)
    : id = s(j['userId'])!,
      fullName = s(j['fullName']) ?? '',
      displayName = s(j['displayName']),
      avatar = mediaUrl(s(j['avatarUrl'])),
      email = s(j['email']) ?? '',
      role = i(j['role']);
  final String id, fullName, email;
  final String? displayName, avatar;
  final int role;
  Map<String, dynamic> toJson() => {
    'userId': id,
    'fullName': fullName,
    'displayName': displayName,
    'avatarUrl': avatar,
    'email': email,
    'role': role,
  };
}
