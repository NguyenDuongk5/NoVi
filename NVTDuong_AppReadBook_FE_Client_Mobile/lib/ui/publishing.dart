import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/session.dart';

String reviewLabel(int value) => switch (value) {
  0 => 'Chờ duyệt',
  1 => 'Đã xuất bản',
  2 => 'Bị từ chối',
  _ => 'Không xác định',
};

class OwnedNovelData {
  OwnedNovelData.from(Map<String, dynamic> j)
    : id = s(j['novelId']) ?? '',
      title = s(j['title']) ?? '',
      author = s(j['originalAuthor']),
      description = s(j['description']),
      sourceUrl = s(j['sourceUrl']),
      sourceType = i(j['sourceType']),
      completionStatus = i(j['completionStatus']),
      reviewStatus = i(j['reviewStatus']),
      visibility = i(j['visibility']),
      rejectReason = s(j['rejectReason']),
      coverUrl = mediaUrl(s(j['coverUrl'])),
      categoryIds = (s(j['categoryIds']) ?? '')
          .split(',')
          .where((e) => e.isNotEmpty)
          .toSet(),
      categoryNames = s(j['categoryNames']),
      revisionId = s(j['revisionId']),
      revisionStatus = j['revisionStatus'] == null
          ? null
          : i(j['revisionStatus']),
      revisionReason = s(j['revisionRejectReason']),
      revisionTitle = s(j['revisionTitle']);

  final String id, title;
  final String? author, description, sourceUrl, rejectReason, coverUrl;
  final int sourceType, completionStatus, reviewStatus, visibility;
  final Set<String> categoryIds;
  final String? categoryNames, revisionId, revisionReason, revisionTitle;
  final int? revisionStatus;
}

class OwnedChapterData {
  OwnedChapterData.from(Map<String, dynamic> j)
    : id = s(j['chapterId']) ?? '',
      number = i(j['chapterNumber']),
      title = s(j['title']) ?? '',
      content = s(j['content']) ?? '',
      reviewStatus = i(j['reviewStatus']),
      visibility = i(j['visibility']),
      rejectReason = s(j['rejectReason']),
      revisionId = s(j['revisionId']),
      revisionStatus = j['revisionStatus'] == null
          ? null
          : i(j['revisionStatus']),
      revisionReason = s(j['revisionRejectReason']),
      revisionTitle = s(j['revisionTitle']),
      revisionContent = s(j['revisionContent']);
  final String id, title, content;
  final int number, reviewStatus, visibility;
  final int? revisionStatus;
  final String? rejectReason, revisionId, revisionReason, revisionTitle;
  final String? revisionContent;
}

class MyNovelsPage extends StatefulWidget {
  const MyNovelsPage({super.key, required this.session});
  final Session session;
  @override
  State<MyNovelsPage> createState() => _MyNovelsPageState();
}

class _MyNovelsPageState extends State<MyNovelsPage> {
  List<OwnedNovelData> items = const [];
  int page = 1, total = 0;
  static const pageSize = 10;
  bool loading = true;
  String? error;

  Future<void> load([int? targetPage]) async {
    final requestedPage = targetPage ?? page;
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final response = await widget.session.api.get(
        '/api/author/novels',
        query: {'page': '$requestedPage', 'pageSize': '$pageSize'},
        auth: true,
      );
      final raw = response['items'] as List;
      final totalItems = i(response['totalItems']);
      if (raw.isEmpty && requestedPage > 1) return load(requestedPage - 1);
      if (mounted) {
        setState(() {
          items = raw
              .map((e) => OwnedNovelData.from(Map<String, dynamic>.from(e)))
              .toList();
          loading = false;
          page = requestedPage;
          total = totalItems;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> edit([OwnedNovelData? novel]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovelEditorPage(session: widget.session, novel: novel),
      ),
    );
    await load();
  }

  Future<void> act(OwnedNovelData novel, String action) async {
    try {
      if (action == 'edit') return edit(novel);
      if (action == 'visibility') {
        if (novel.visibility == 0) {
          final confirmed = await _confirmAction(
            context,
            title: 'Ẩn truyện?',
            message: 'Ẩn “${novel.title}” khỏi độc giả?',
            confirmLabel: 'Ẩn',
          );
          if (!confirmed) return;
        }
        await widget.session.api.patch(
          '/api/author/novels/${novel.id}/visibility?visible=${novel.visibility != 0}',
          auth: true,
        );
      } else if (action == 'delete') {
        final confirmed = await _confirmAction(
          context,
          title: 'Xóa truyện?',
          message:
              'Xóa mềm “${novel.title}”? Truyện sẽ không còn hiển thị công khai.',
          confirmLabel: 'Xóa',
        );
        if (!confirmed) return;
        await widget.session.api.delete(
          '/api/author/novels/${novel.id}',
          auth: true,
        );
      }
      await load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Truyện của tôi')),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('author-create-novel'),
      onPressed: () => edit(),
      icon: const Icon(Icons.add),
      label: const Text('Tạo truyện'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? _PublishingError(error!, load)
        : RefreshIndicator(
            onRefresh: () => load(page),
            child: items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 220),
                      Center(child: Text('Bạn chưa có truyện nào.')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      if (index == items.length) {
                        return _PageControls(
                          page: page,
                          pageSize: pageSize,
                          total: total,
                          onPage: load,
                        );
                      }
                      final n = items[index];
                      return Card(
                        key: Key('author-novel-${n.id}'),
                        child: ListTile(
                          leading: n.coverUrl == null
                              ? const SizedBox(
                                  width: 48,
                                  child: Icon(Icons.menu_book_outlined),
                                )
                              : Image.network(
                                  n.coverUrl!,
                                  width: 48,
                                  height: 66,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    width: 48,
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                          title: Text(n.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(reviewLabel(n.reviewStatus)),
                              if (n.rejectReason?.isNotEmpty == true)
                                Text(
                                  'Lý do: ${n.rejectReason}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              if (n.revisionStatus != null)
                                Text(
                                  'Bản chỉnh sửa: ${reviewLabel(n.revisionStatus!)}${n.revisionReason?.isNotEmpty == true ? ' — ${n.revisionReason}' : ''}',
                                ),
                            ],
                          ),
                          isThreeLine:
                              n.rejectReason != null ||
                              n.revisionStatus != null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AuthorNovelPage(
                                session: widget.session,
                                novel: n,
                              ),
                            ),
                          ).then((_) => load()),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) => act(n, value),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Sửa'),
                              ),
                              PopupMenuItem(
                                value: 'visibility',
                                child: Text(
                                  n.visibility == 0
                                      ? 'Ẩn truyện'
                                      : 'Hiện truyện',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Xóa mềm'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
  );
}

class NovelEditorPage extends StatefulWidget {
  const NovelEditorPage({super.key, required this.session, this.novel});
  final Session session;
  final OwnedNovelData? novel;
  @override
  State<NovelEditorPage> createState() => _NovelEditorPageState();
}

class _NovelEditorPageState extends State<NovelEditorPage> {
  final formKey = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.novel?.title);
  late final author = TextEditingController(text: widget.novel?.author);
  late final description = TextEditingController(
    text: widget.novel?.description,
  );
  late final sourceUrl = TextEditingController(text: widget.novel?.sourceUrl);
  int sourceType = 0, completion = 0;
  Set<String> categories = {};
  List<Category> available = const [];
  XFile? cover;
  bool saving = false, saved = false;
  String? error, coverError;

  bool get dirty =>
      !saved &&
      (title.text != (widget.novel?.title ?? '') ||
          author.text != (widget.novel?.author ?? '') ||
          description.text != (widget.novel?.description ?? '') ||
          sourceUrl.text != (widget.novel?.sourceUrl ?? '') ||
          sourceType != (widget.novel?.sourceType ?? 0) ||
          completion != (widget.novel?.completionStatus ?? 0) ||
          cover != null ||
          categories.difference(widget.novel?.categoryIds ?? {}).isNotEmpty ||
          (widget.novel?.categoryIds ?? {}).difference(categories).isNotEmpty);

  @override
  void initState() {
    super.initState();
    sourceType = widget.novel?.sourceType ?? 0;
    completion = widget.novel?.completionStatus ?? 0;
    categories = {...?widget.novel?.categoryIds};
    for (final controller in [title, author, description, sourceUrl]) {
      controller.addListener(_changed);
    }
    loadCategories();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> loadCategories() async {
    try {
      final r = await widget.session.api.get('/api/categories') as List;
      if (mounted) {
        setState(
          () => available = r
              .map((e) => Category.from(Map<String, dynamic>.from(e)))
              .toList(),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    title.dispose();
    author.dispose();
    description.dispose();
    sourceUrl.dispose();
    super.dispose();
  }

  Future<void> pickCover() async {
    final f = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Ảnh', extensions: ['jpg', 'jpeg', 'png', 'webp']),
      ],
    );
    if (f != null && mounted) {
      setState(() {
        cover = f;
        coverError = null;
      });
    }
  }

  Future<void> save() async {
    if (saving || !formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final body = {
        'title': title.text.trim(),
        'originalAuthor': author.text.trim().isEmpty
            ? null
            : author.text.trim(),
        'sourceType': sourceType,
        'sourceUrl': sourceUrl.text.trim().isEmpty
            ? null
            : sourceUrl.text.trim(),
        'description': description.text.trim().isEmpty
            ? null
            : description.text.trim(),
        'completionStatus': completion,
        'categoryIds': categories.toList(),
      };
      String id;
      if (widget.novel == null) {
        final r = await widget.session.api.post(
          '/api/author/novels',
          auth: true,
          body: body,
        );
        id = s(r['id'])!;
      } else {
        id = widget.novel!.id;
        await widget.session.api.put(
          '/api/author/novels/$id',
          auth: true,
          body: body,
        );
      }
      if (cover != null) {
        try {
          await widget.session.api.uploadFile(
            '/api/media/novels/$id/cover',
            cover!.path,
          );
        } on ApiException catch (e) {
          if (mounted) setState(() => coverError = e.message);
          rethrow;
        }
      }
      if (mounted) {
        setState(() => saved = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu và gửi duyệt.')));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final published = widget.novel?.reviewStatus == 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.novel == null ? 'Đăng tải truyện' : 'Sửa truyện'),
      ),
      body: Form(
        key: formKey,
        canPop: !dirty,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (await _confirmDiscard(context) && context.mounted) {
            setState(() => saved = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pop(context);
            });
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (error != null)
              _PublishingError(error!, () => setState(() => error = null)),
            TextFormField(
              key: const Key('novel-title'),
              controller: title,
              decoration: const InputDecoration(labelText: 'Tên truyện *'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Vui lòng nhập tên truyện.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: author,
              decoration: const InputDecoration(
                labelText: 'Tác giả gốc / dịch giả',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('novel-description'),
              controller: description,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: sourceType,
              decoration: const InputDecoration(labelText: 'Nguồn sáng tác'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Tự sáng tác')),
                DropdownMenuItem(value: 1, child: Text('Dịch / nguồn khác')),
              ],
              onChanged: (v) => setState(() => sourceType = v ?? 0),
            ),
            if (sourceType == 1) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: sourceUrl,
                decoration: const InputDecoration(labelText: 'Đường dẫn nguồn'),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: completion,
              decoration: const InputDecoration(labelText: 'Tiến độ'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Đang cập nhật')),
                DropdownMenuItem(value: 1, child: Text('Hoàn thành')),
                DropdownMenuItem(value: 2, child: Text('Tạm dừng')),
              ],
              onChanged: (v) => setState(() => completion = v ?? 0),
            ),
            const SizedBox(height: 16),
            Text('Thể loại', style: Theme.of(context).textTheme.titleMedium),
            if (published)
              const Text(
                'Thể loại của truyện đã xuất bản được giữ nguyên trong lượt sửa này.',
              ),
            Wrap(
              spacing: 8,
              children: available
                  .map(
                    (c) => FilterChip(
                      label: Text(c.name),
                      selected: categories.contains(c.id),
                      onSelected: published
                          ? null
                          : (selected) => setState(
                              () => selected
                                  ? categories.add(c.id)
                                  : categories.remove(c.id),
                            ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('novel-pick-cover'),
              onPressed: pickCover,
              icon: const Icon(Icons.image_outlined),
              label: Text(cover == null ? 'Chọn ảnh bìa' : cover!.name),
            ),
            if (cover != null) ...[
              const SizedBox(height: 8),
              FutureBuilder<Uint8List>(
                future: cover!.readAsBytes(),
                builder: (_, snapshot) => snapshot.hasData
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          snapshot.data!,
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
            if (coverError != null)
              Text(
                coverError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (published && cover != null)
              const Text('Ảnh bìa mới sẽ tạo revision riêng và cần duyệt.'),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('novel-save'),
              onPressed: saving ? null : save,
              child: saving
                  ? const CircularProgressIndicator()
                  : const Text('Lưu và gửi duyệt'),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthorNovelPage extends StatefulWidget {
  const AuthorNovelPage({
    super.key,
    required this.session,
    required this.novel,
  });
  final Session session;
  final OwnedNovelData novel;
  @override
  State<AuthorNovelPage> createState() => _AuthorNovelPageState();
}

class _AuthorNovelPageState extends State<AuthorNovelPage> {
  List<OwnedChapterData> chapters = const [];
  int page = 1, total = 0;
  static const pageSize = 10;
  bool loading = true;
  String? error;
  Future<void> load([int? targetPage]) async {
    final requestedPage = targetPage ?? page;
    try {
      final response = await widget.session.api.get(
        '/api/author/novels/${widget.novel.id}/chapters',
        query: {'page': '$requestedPage', 'pageSize': '$pageSize'},
        auth: true,
      );
      final r = response['items'] as List;
      final totalItems = i(response['totalItems']);
      if (r.isEmpty && requestedPage > 1) return load(requestedPage - 1);
      if (mounted) {
        setState(() {
          chapters = r
              .map((e) => OwnedChapterData.from(Map<String, dynamic>.from(e)))
              .toList();
          loading = false;
          page = requestedPage;
          total = totalItems;
          error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.message;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> edit([OwnedChapterData? c]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterEditorPage(
          session: widget.session,
          novelId: widget.novel.id,
          chapter: c,
          nextNumber: chapters.length + 1,
        ),
      ),
    );
    await load();
  }

  Future<void> act(OwnedChapterData chapter, String action) async {
    try {
      if (action == 'edit') return edit(chapter);
      if (action == 'visibility') {
        if (chapter.visibility == 0) {
          final confirmed = await _confirmAction(
            context,
            title: 'Ẩn chương?',
            message: 'Ẩn “${chapter.title}” khỏi độc giả?',
            confirmLabel: 'Ẩn',
          );
          if (!confirmed) return;
        }
        await widget.session.api.patch(
          '/api/author/chapters/${chapter.id}/visibility?visible=${chapter.visibility != 0}',
          auth: true,
        );
      } else if (action == 'delete') {
        final confirmed = await _confirmAction(
          context,
          title: 'Xóa chương?',
          message:
              'Xóa mềm “${chapter.title}”? Chương sẽ không còn hiển thị công khai.',
          confirmLabel: 'Xóa',
        );
        if (!confirmed) return;
        await widget.session.api.delete(
          '/api/author/chapters/${chapter.id}',
          auth: true,
        );
      }
      await load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.novel.title)),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('author-create-chapter'),
      onPressed: () => edit(),
      icon: const Icon(Icons.add),
      label: const Text('Thêm chương'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? _PublishingError(error!, load)
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            children: [
              Text(
                'Chương truyện',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...chapters.map(
                (c) => Card(
                  child: ListTile(
                    key: Key('author-chapter-${c.id}'),
                    title: Text('Chương ${c.number}: ${c.title}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reviewLabel(c.reviewStatus)),
                        if (c.rejectReason?.isNotEmpty == true)
                          Text('Lý do: ${c.rejectReason}'),
                        if (c.revisionStatus != null)
                          Text(
                            'Bản chỉnh sửa: ${reviewLabel(c.revisionStatus!)}${c.revisionReason?.isNotEmpty == true ? ' — ${c.revisionReason}' : ''}',
                          ),
                      ],
                    ),
                    onTap: () => edit(c),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => act(c, value),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                        PopupMenuItem(
                          value: 'visibility',
                          child: Text(
                            c.visibility == 0 ? 'Ẩn chương' : 'Hiện chương',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Xóa mềm'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _PageControls(
                page: page,
                pageSize: pageSize,
                total: total,
                onPage: load,
              ),
            ],
          ),
  );
}

class ChapterEditorPage extends StatefulWidget {
  const ChapterEditorPage({
    super.key,
    required this.session,
    required this.novelId,
    this.chapter,
    required this.nextNumber,
  });
  final Session session;
  final String novelId;
  final OwnedChapterData? chapter;
  final int nextNumber;
  @override
  State<ChapterEditorPage> createState() => _ChapterEditorPageState();
}

class _ChapterEditorPageState extends State<ChapterEditorPage> {
  final formKey = GlobalKey<FormState>();
  late final number = TextEditingController(
    text: '${widget.chapter?.number ?? widget.nextNumber}',
  );
  late final title = TextEditingController(
    text: widget.chapter?.revisionStatus == 0
        ? widget.chapter?.revisionTitle
        : widget.chapter?.title,
  );
  late final content = TextEditingController(
    text: widget.chapter?.revisionStatus == 0
        ? widget.chapter?.revisionContent
        : widget.chapter?.content,
  );
  bool saving = false, saved = false;
  String? error;
  bool get dirty =>
      !saved &&
      (number.text != '${widget.chapter?.number ?? widget.nextNumber}' ||
          title.text !=
              (widget.chapter?.revisionStatus == 0
                  ? widget.chapter?.revisionTitle ?? ''
                  : widget.chapter?.title ?? '') ||
          content.text !=
              (widget.chapter?.revisionStatus == 0
                  ? widget.chapter?.revisionContent ?? ''
                  : widget.chapter?.content ?? ''));

  @override
  void initState() {
    super.initState();
    for (final controller in [number, title, content]) {
      controller.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    number.dispose();
    title.dispose();
    content.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final body = {
        'chapterNumber': int.parse(number.text),
        'title': title.text.trim(),
        'content': content.text,
      };
      if (widget.chapter == null) {
        await widget.session.api.post(
          '/api/author/novels/${widget.novelId}/chapters',
          auth: true,
          body: body,
        );
      } else {
        await widget.session.api.put(
          '/api/author/chapters/${widget.chapter!.id}',
          auth: true,
          body: body,
        );
      }
      if (mounted) {
        setState(() => saved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu và gửi duyệt chương.')),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.chapter == null ? 'Thêm chương' : 'Sửa chương'),
    ),
    body: Form(
      key: formKey,
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard(context) && context.mounted) {
          setState(() => saved = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (error != null)
            _PublishingError(error!, () => setState(() => error = null)),
          TextFormField(
            key: const Key('chapter-number'),
            controller: number,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số chương *'),
            validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 1
                ? 'Số chương không hợp lệ.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('chapter-title'),
            controller: title,
            decoration: const InputDecoration(labelText: 'Tên chương *'),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Vui lòng nhập tên chương.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('chapter-content'),
            controller: content,
            minLines: 14,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Nội dung *',
              alignLabelWithHint: true,
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Vui lòng nhập nội dung.'
                : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('chapter-save'),
            onPressed: saving ? null : save,
            child: saving
                ? const CircularProgressIndicator()
                : const Text('Lưu và gửi duyệt'),
          ),
        ],
      ),
    ),
  );
}

class ModerationQueuePage extends StatefulWidget {
  const ModerationQueuePage({super.key, required this.session});
  final Session session;
  @override
  State<ModerationQueuePage> createState() => _ModerationQueuePageState();
}

class _ModerationQueuePageState extends State<ModerationQueuePage> {
  List<Map<String, dynamic>> items = const [];
  int page = 1, total = 0;
  static const pageSize = 10;
  bool loading = true;
  String? error;
  Future<void> load([int? targetPage]) async {
    final requestedPage = targetPage ?? page;
    try {
      final response = await widget.session.api.get(
        '/api/admin/moderation',
        query: {'page': '$requestedPage', 'pageSize': '$pageSize'},
        auth: true,
      );
      final r = response['items'] as List;
      final totalItems = i(response['totalItems']);
      if (r.isEmpty && requestedPage > 1) return load(requestedPage - 1);
      if (mounted) {
        setState(() {
          items = r.map((e) => Map<String, dynamic>.from(e)).toList();
          loading = false;
          page = requestedPage;
          total = totalItems;
          error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.message;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  String typeName(String type) => switch (type.toLowerCase()) {
    'novel' => 'Truyện mới',
    'chapter' => 'Chương mới',
    'novelrevision' => 'Sửa truyện',
    'chapterrevision' => 'Sửa chương',
    _ => type,
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kiểm duyệt nội dung')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? _PublishingError(error!, load)
        : RefreshIndicator(
            onRefresh: () => load(page),
            child: items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 220),
                      Center(child: Text('Không có nội dung chờ duyệt.')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      if (index == items.length) {
                        return _PageControls(
                          page: page,
                          pageSize: pageSize,
                          total: total,
                          onPage: load,
                        );
                      }
                      final x = items[index],
                          id = s(x['id'])!,
                          type = s(x['targetType'])!;
                      return Card(
                        child: ListTile(
                          key: Key('moderation-$type-$id'),
                          leading: const Icon(Icons.fact_check_outlined),
                          title: Text(s(x['title']) ?? ''),
                          subtitle: Text(typeName(type)),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ModerationDetailPage(
                                session: widget.session,
                                id: id,
                                type: type,
                              ),
                            ),
                          ).then((_) => load()),
                        ),
                      );
                    },
                  ),
          ),
  );
}

class ModerationDetailPage extends StatefulWidget {
  const ModerationDetailPage({
    super.key,
    required this.session,
    required this.id,
    required this.type,
  });
  final Session session;
  final String id, type;
  @override
  State<ModerationDetailPage> createState() => _ModerationDetailPageState();
}

class _ModerationDetailPageState extends State<ModerationDetailPage> {
  Map<String, dynamic>? data;
  bool loading = true, processing = false;
  String? error;
  String rejectionDraft = '';
  Future<void> load() async {
    try {
      final r = await widget.session.api.get(
        '/api/admin/moderation/${widget.type}/${widget.id}',
        auth: true,
      );
      if (mounted) {
        setState(() {
          data = Map<String, dynamic>.from(r);
          loading = false;
          error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.message;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> decide(bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _reasonDialog(context, initialValue: rejectionDraft);
      if (reason == null) return;
      rejectionDraft = reason;
    }
    setState(() => processing = true);
    try {
      await widget.session.api.post(
        '/api/admin/moderation/${widget.type}/${widget.id}/decision',
        auth: true,
        body: {'approve': approve, 'reason': reason},
      );
      if (mounted) {
        rejectionDraft = '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Đã duyệt nội dung.' : 'Đã từ chối nội dung.',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.status == 409
                  ? 'Nội dung đã được người khác xử lý. Hàng chờ đã được cập nhật.'
                  : e.message,
            ),
          ),
        );
        if (e.status == 409) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết kiểm duyệt')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? _PublishingError(error!, load)
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                s(data!['title']) ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (s(data!['novelTitle']) != null)
                Text('Truyện: ${s(data!['novelTitle'])}'),
              Text('Người gửi: ${s(data!['submitterName']) ?? ''}'),
              if (s(data!['categoryNames'])?.isNotEmpty == true)
                Text('Thể loại: ${s(data!['categoryNames'])}'),
              if (s(data!['originalAuthor'])?.isNotEmpty == true)
                Text('Tác giả: ${s(data!['originalAuthor'])}'),
              if (s(data!['description'])?.isNotEmpty == true) ...[
                const Divider(),
                Text(s(data!['description'])!),
              ],
              if (s(data!['content'])?.isNotEmpty == true) ...[
                const Divider(),
                SelectableText(s(data!['content'])!),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('moderation-reject'),
                      onPressed: processing ? null : () => decide(false),
                      child: const Text('Từ chối'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('moderation-approve'),
                      onPressed: processing ? null : () => decide(true),
                      child: const Text('Duyệt'),
                    ),
                  ),
                ],
              ),
            ],
          ),
  );
}

Future<String?> _reasonDialog(
  BuildContext context, {
  String initialValue = '',
}) async {
  var value = initialValue;
  final controller = TextEditingController(text: initialValue);
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Lý do từ chối'),
        content: TextField(
          controller: controller,
          key: const Key('moderation-reason'),
          minLines: 3,
          maxLines: 6,
          onChanged: (v) => value = v,
          decoration: InputDecoration(errorText: error),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('moderation-reject-confirm'),
            onPressed: () {
              final reason = value.trim();
              if (reason.isEmpty) {
                setState(() => error = 'Vui lòng nhập lý do.');
                return;
              }
              Navigator.pop(context, reason);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ),
  );
  return result;
}

Future<bool> _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

Future<bool> _confirmDiscard(BuildContext context) => _confirmAction(
  context,
  title: 'Bỏ thay đổi?',
  message: 'Các thay đổi chưa lưu sẽ bị mất.',
  confirmLabel: 'Bỏ thay đổi',
);

class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPage,
  });
  final int page, pageSize, total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final pages = total == 0 ? 1 : (total / pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: page > 1 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Trang trước'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('$page/$pages'),
          ),
          OutlinedButton.icon(
            onPressed: page < pages ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Trang sau'),
          ),
        ],
      ),
    );
  }
}

class _PublishingError extends StatelessWidget {
  const _PublishingError(this.message, this.retry);
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
