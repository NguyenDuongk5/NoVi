import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/theme_controller.dart';
import 'auth_sheet.dart';
import 'author_application.dart';
import 'content_report.dart';
import 'publishing.dart';
import 'home_widgets.dart';
import 'ranking_screen.dart';
import 'ranking_widgets.dart';
import 'reader_toolbar.dart';
import 'reader_settings_page.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'offline_book_store.dart';
import 'reader_audio_controls.dart';

// import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;


String errorText(Object e) =>
    e is ApiException ? e.message : 'Không thể kết nối máy chủ.';

class Cover extends StatelessWidget {
  const Cover(this.url, {super.key, this.width = 82, this.height = 116});
  final String? url;
  final double width, height;
  @override
  Widget build(BuildContext context) =>
      NoviCover(url, width: width, height: height);
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry(this.message, this.retry, {super.key});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
        ),
      ],
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});
  final Session session;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.session,
    builder: (_, _) => Scaffold(
      body: SafeArea(
        bottom: false,
        child: <Widget>[
            ExplorePage(
              session: widget.session,
              onProfileTap: () => setState(() => index = 2),
            ),

          _authGate(
            LibraryHubPage(
              key: ValueKey('library-hub-${widget.session.user?.id}'),
              session: widget.session,
            ),
          ),
          ProfilePage(session: widget.session),
        ][index],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.session.authenticated)
            ContinueReadingPanel(
              key: ValueKey('continue-${widget.session.user?.id}'),
              session: widget.session,
            ),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (v) => setState(() => index = v),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Khám phá',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_outline),
                selectedIcon: Icon(Icons.bookmark),
                label: 'Tủ sách',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Tôi',
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _authGate(Widget child) => widget.session.authenticated
      ? child
      : Center(
          child: FilledButton.icon(
            onPressed: () => showAuth(context, widget.session),
            icon: const Icon(Icons.login),
            label: const Text('Đăng nhập để sử dụng'),
          ),
        );
}

class LibraryHubPage extends StatefulWidget {
  const LibraryHubPage({super.key, required this.session});
  final Session session;
  @override
  State<LibraryHubPage> createState() => _LibraryHubPageState();
}

class _LibraryHubPageState extends State<LibraryHubPage> {
  int section = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Tủ sách',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.bookmark_outline),
                  label: Text('Đã lưu'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.history),
                  label: Text('Lịch sử'),
                ),
              ],
              selected: {section},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => section = value.first),
            ),
          ],
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: section,
          children: [
            LibraryPage(session: widget.session, embedded: true),
            HistoryPage(session: widget.session, embedded: true),
          ],
        ),
      ),
    ],
  );
}

class ContinueReadingPanel extends StatefulWidget {
  const ContinueReadingPanel({super.key, required this.session});
  final Session session;
  @override
  State<ContinueReadingPanel> createState() => _ContinueReadingPanelState();
}

class _ContinueReadingPanelState extends State<ContinueReadingPanel> {
  Map<String, dynamic>? progress;
  Novel? novel;
  bool hidden = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final history = await widget.session.api.get(
        '/api/me/history',
        query: {'page': '1', 'pageSize': '1'},
        auth: true,
      );
      final rows = history['items'] as List;
      if (rows.isEmpty || rows.first['available'] != true) return;
      final novelId = s(rows.first['novelId']);
      if (novelId == null) return;
      final values = await Future.wait([
        widget.session.api.get('/api/me/novels/$novelId/continue', auth: true),
        widget.session.api.get('/api/novels/$novelId'),
      ]);
      if (!mounted || values[0]['available'] != true) return;
      setState(() {
        progress = Map<String, dynamic>.from(values[0]);
        novel = Novel.from(Map<String, dynamic>.from(values[1]));
      });
    } catch (_) {
      // Thanh đọc tiếp không được làm lỗi trang chủ khi mạng gián đoạn.
    }
  }

  Future<void> _open() async {
    final p = progress, n = novel;
    if (p == null || n == null) return;
    try {
      final raw =
          await widget.session.api.get('/api/novels/${n.id}/chapters') as List;
      final chapters = raw
          .map((e) => ChapterInfo.from(Map<String, dynamic>.from(e)))
          .toList();
      final chapterIndex = chapters.indexWhere(
        (c) => c.id == s(p['chapterId']),
      );
      if (!mounted || chapterIndex < 0) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderPage(
            session: widget.session,
            chapters: chapters,
            index: chapterIndex,
            restorePercent: d(p['positionPercent']),
          ),
        ),
      );
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorText(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = progress, n = novel;
    if (hidden || p == null || n == null) return const SizedBox.shrink();
    return ContinueReadingBar(
      coverUrl: n.cover,
      title: n.title,
      chapter: 'Chương ${i(p['chapterNumber'])}: ${s(p['chapterTitle']) ?? ''}',
      onContinue: _open,
      onClose: () => setState(() => hidden = true),
    );
  }
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    required this.session,
    this.onProfileTap,
  });

  final Session session;
  final VoidCallback? onProfileTap;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final search = TextEditingController();
  List<Novel> items = [];
  List<Category> categories = [];
  List<RankedNovel> rankings = [];
  final Set<String> selectedCategoryIds = {};
  String? error;
  String? rankingError;
  int page = 1, total = 0;
  int topTab = 0;
  bool loading = true, rankingLoading = true;
  bool loadingMore = false;
  String? loadMoreError;
  @override
  void initState() {
    super.initState();
    load();
    loadCategories();
    loadRankings();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> loadCategories() async {
    try {
      final r = await widget.session.api.get('/api/categories') as List;
      if (mounted) {
        setState(
          () => categories = r
              .map((e) => Category.from(Map<String, dynamic>.from(e)))
              .toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> loadRankings() async {
    if (mounted) {
      setState(() {
        rankingLoading = true;
        rankingError = null;
      });
    }
    try {
      final response = await widget.session.api.get(
        '/api/novels/rankings',
        query: {'period': 'month', 'page': '1', 'pageSize': '9'},
      );
      final data = RankingPageData.from(Map<String, dynamic>.from(response));
      if (!mounted) return;
      setState(() {
        rankings = data.items;
        rankingLoading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        rankingLoading = false;
        rankingError = errorText(exception);
      });
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([load(), loadRankings(), loadCategories()]);
  }

Future<void> load({bool reset = true}) async {
  final requestedPage = reset ? 1 : page + 1;

  if (reset) {
    setState(() {
      loading = true;
      error = null;
      loadMoreError = null;
    });
  }

  try {
    final r = await widget.session.api.get(
      '/api/novels',
      query: {
        'keyword': search.text.trim().isEmpty ? null : search.text.trim(),
        'categoryId': selectedCategoryIds.isEmpty ? null : selectedCategoryIds.first,
        'page': '$requestedPage',
        'pageSize': '12',
      },
    );

    final got = (r['items'] as List)
        .map((e) => Novel.from(Map<String, dynamic>.from(e)))
        .toList();

    if (!mounted) return;

    setState(() {
      page = requestedPage;
      items = reset ? got : [...items, ...got];
      total = i(r['totalItems']);
      loading = false;
      loadingMore = false;
      loadMoreError = null;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      if (reset) {
        error = errorText(e);
        loading = false;
      } else {
        loadMoreError = errorText(e);
        loadingMore = false;
      }
    });
  }
}

Future<void> loadNextPage() async {
  if (loading || loadingMore || items.length >= total) return;

  setState(() {
    loadingMore = true;
    loadMoreError = null;
  });

  await load(reset: false);
}

Future<void> openNovel(Novel novel) async {
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => NovelDetailPage(
        session: widget.session,
        novelId: novel.id,
      ),
    ),
  );

  try {
    final result = await widget.session.api.get(
      '/api/novels/${novel.id}',
    );
    if (!mounted) return;

    final updated = Novel.from(Map<String, dynamic>.from(result));
    final index = items.indexWhere((item) => item.id == novel.id);

    if (index >= 0) {
      setState(() => items[index] = updated);
    }
  } catch (_) {
    // Giữ số hiện tại nếu không tải lại được.
  }

  await loadRankings();
}

 Future<void> openRankings() async {
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => RankingScreen(
        session: widget.session,
        onOpenNovel: (rankingContext, novelId) async {
          await Navigator.push<void>(
            rankingContext,
            MaterialPageRoute<void>(
              builder: (_) => NovelDetailPage(
                session: widget.session,
                novelId: novelId,
              ),
            ),
          );
        },
      ),
    ),
  );

  if (mounted) await loadRankings();
}

  @override
  Widget build(BuildContext context) => Scaffold(
    body: NotificationListener<ScrollNotification>(
  onNotification: (notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < 500) {
      loadNextPage();
    }
    return false;
  },
  child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RefreshIndicator(
          onRefresh: refreshAll,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                sliver: SliverList.list(
                  children: [
                    Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.auto_stories_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NoVi',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.session.user == null
                                      ? 'Chào bạn, hôm nay mình đọc gì?'
                                      : 'Chào ${widget.session.user!.displayName ?? widget.session.user!.fullName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: Theme.of(context).brightness == Brightness.dark
                                ? 'Chuyển sang giao diện sáng'
                                : 'Chuyển sang giao diện tối',
                            onPressed: () => NoviThemeController.instance.toggle(
                              Theme.of(context).brightness,
                            ),
                            icon: Icon(
                              Theme.of(context).brightness == Brightness.dark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                            ),
                          ),
                          const SizedBox(width: 2),
                          IconButton.filledTonal(
                            tooltip: 'Hồ sơ cá nhân',
                            onPressed: widget.onProfileTap,
                            icon: const Icon(Icons.person_outline_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    NoviTopTabs(
                      labels: const ['Khám phá', 'Thể loại'],
                      selectedIndex: topTab,
                      onSelected: (value) {
                        if (value == topTab) return;
                        setState(() => topTab = value);
                        if (value == 0 && selectedCategoryIds.isNotEmpty) {
                          selectedCategoryIds.clear();
                          load();
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SearchBar(
                            controller: search,
                            hintText: 'Tìm truyện, tác giả…',
                            elevation: const WidgetStatePropertyAll(0),
                            leading: const Icon(Icons.search),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => load(),
                            trailing: search.text.isEmpty
                                ? null
                                : [
                                    IconButton(
                                      tooltip: 'Xóa tìm kiếm',
                                      onPressed: () {
                                        search.clear();
                                        load();
                                      },
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox.square(
                          dimension: 48,
                          child: IconButton.filledTonal(
                            tooltip: 'Bảng xếp hạng',
                            onPressed: openRankings,
                            icon: const Icon(Icons.leaderboard_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              if (topTab == 1)
                SliverToBoxAdapter(
                  child: NoviCategoryFilter(
                    categories: categories,
                    selectedIds: selectedCategoryIds,
                    onSelected: (id) {
                      setState(() {
                        selectedCategoryIds.clear();
                        if (id != null) selectedCategoryIds.add(id);
                      });
                      load();
                    },
                  ),
                ),
              if (loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                SliverFillRemaining(child: ErrorRetry(error!, load))
              else if (items.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('Không có truyện phù hợp.')),
                )
              else ...[
                if (topTab == 0) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          const Expanded(
                            child: NoviSectionTitle('BXH tháng này'),
                          ),
                          TextButton(
                            onPressed: openRankings,
                            child: const Text('Xem tất cả'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: rankingLoading
                          ? const SizedBox(
                              height: 180,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : rankingError != null
                          ? SizedBox(
                              height: 150,
                              child: ErrorRetry(rankingError!, loadRankings),
                            )
                          : rankings.isEmpty
                          ? const SizedBox(
                              height: 100,
                              child: Center(
                                child: Text(
                                  'Chưa có lượt đọc trong tháng này.',
                                ),
                              ),
                            )
                          : RankingPreview(
                              items: rankings,
                              onOpen: (item) => openNovel(item.novel),
                            ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    sliver: const SliverToBoxAdapter(
                      child: NoviSectionTitle('Mới cập nhật'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 270,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length > 6 ? 6 : items.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (_, n) => CompactNovelCard(
                          novel: items[n],
                          onTap: () => openNovel(items[n]),
                        ),
                      ),
                    ),
                  ),
                ],
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    topTab == 0 ? 22 : 24,
                    16,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: NoviSectionTitle(
                      topTab == 0 ? 'Khám phá truyện' : 'Truyện theo thể loại',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    itemBuilder: (_, n) => NovelListCard(
                      novel: items[n],
                      onTap: () => openNovel(items[n]),
                    ),
                  ),
                ),
                if (items.length < total)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: loadMoreError != null
                            ? TextButton(
                                onPressed: loadNextPage,
                                child: const Text('Tải tiếp thất bại. Chạm để thử lại'),
                              )
                            : loadingMore
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  )
                                : const SizedBox(height: 24),
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
  );
}

class NovelDetailPage extends StatefulWidget {
  const NovelDetailPage({
    super.key,
    required this.session,
    required this.novelId,
  });
  final Session session;
  final String novelId;
  @override
  State<NovelDetailPage> createState() => _NovelDetailPageState();
}

class _NovelDetailPageState extends State<NovelDetailPage> {
  Novel? novel;
  List<ChapterInfo> chapters = [];
  bool loading = true;
  bool saved = false;

bool downloadingOffline = false;
double offlineDownloadProgress = 0;

  bool descriptionExpanded = false;
  bool newestFirst = true;
  int chapterPage = 1;
  static const int chaptersPerPage = 20;
  String? error;

  List<ChapterInfo> get orderedChapters {
    final result = [...chapters];
    result.sort(
      (a, b) => newestFirst
          ? b.number.compareTo(a.number)
          : a.number.compareTo(b.number),
    );
    return result;
  }

  int get chapterPageCount =>
      (chapters.length / chaptersPerPage).ceil().clamp(1, 999999).toInt();

  List<ChapterInfo> get visibleChapters {
    final start = (chapterPage - 1) * chaptersPerPage;
    if (start >= chapters.length) return const [];

    final end = (start + chaptersPerPage).clamp(0, chapters.length).toInt();
    return orderedChapters.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    load();
  }



  Future<void> load() async {
    try {
      final values = await Future.wait([
        widget.session.api.get('/api/novels/${widget.novelId}'),
        widget.session.api.get('/api/novels/${widget.novelId}/chapters'),
      ]);

      novel = Novel.from(Map<String, dynamic>.from(values[0]));
      chapters = (values[1] as List)
          .map((e) => ChapterInfo.from(Map<String, dynamic>.from(e)))
          .toList();

      if (widget.session.authenticated) {
        final response = await widget.session.api.get(
          '/api/me/library',
          query: {'page': '1', 'pageSize': '100'},
          auth: true,
        );

        saved = (response['items'] as List).any(
          (item) => s(item['novelId']) == widget.novelId,
        );
      }

      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = errorText(e);
      });
    }
  }

  Future<void> toggleSaved() async {
    if (!widget.session.authenticated) {
      await showAuth(context, widget.session);
      return;
    }

    try {
      if (saved) {
        await widget.session.api.delete(
          '/api/me/library/${widget.novelId}',
          auth: true,
        );
      } else {
        await widget.session.api.put(
          '/api/me/library/${widget.novelId}',
          auth: true,
        );
      }

      if (mounted) setState(() => saved = !saved);
    } catch (e) {
      showMessage(errorText(e));
    }
  }

// tải truyện
Future<void> downloadNovelOffline() async {
  debugPrint('authenticated=${widget.session.authenticated}');

  if (!widget.session.authenticated) {
    showMessage('Vui lòng đăng nhập để tải truyện.');
    await showAuth(context, widget.session);
    return;
  }

  final currentNovel = novel;
  if (currentNovel == null || chapters.isEmpty || downloadingOffline) return;

  setState(() {
    downloadingOffline = true;
    offlineDownloadProgress = 0;
  });

  try {
    final downloadedChapters = <Map<String, dynamic>>[];

    for (var index = 0; index < chapters.length; index++) {
      final chapter = chapters[index];
      final raw = await widget.session.api.get(
        '/api/novels/chapters/${chapter.id}',
      );

      downloadedChapters.add({
        'id': chapter.id,
        'number': chapter.number,
        'title': chapter.title,
        'data': Map<String, dynamic>.from(raw),
      });

      if (mounted) {
        setState(() {
          offlineDownloadProgress = (index + 1) / chapters.length;
        });
      }
    }

    await saveOfflineNovel(widget.novelId, {
      'novelId': widget.novelId,
      'title': currentNovel.title,
      'author': currentNovel.author,
      'cover': currentNovel.cover,
      'description': currentNovel.description,
      'downloadedAt': DateTime.now().toIso8601String(),
      'chapters': downloadedChapters,
    });

    if (mounted) {
      showMessage('Đã tải truyện để đọc offline.');
    }
  } catch (e) {
    if (mounted) {
      showMessage(
        e is ApiException
            ? 'Tải truyện thất bại: ${errorText(e)}'
            : 'Không thể lưu truyện xuống thiết bị: $e',
      );
    }
  } finally {
    if (mounted) {
      setState(() => downloadingOffline = false);
    }
  }
}




  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void showPendingMessage(String feature) {
    showMessage('$feature đang chờ kết nối với máy chủ.');
  }

 Future<void> open(ChapterInfo chapter, [double position = 0]) async {
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ReaderPage(
        session: widget.session,
        chapters: chapters,
        index: chapters.indexOf(chapter),
        restorePercent: position,
      ),
    ),
  );

  if (mounted) await load();
}

  Future<void> readOrResume() async {
    if (!widget.session.authenticated) {
      if (chapters.isNotEmpty) open(chapters.first);
      return;
    }

    try {
      final response = await widget.session.api.get(
        '/api/me/novels/${widget.novelId}/continue',
        auth: true,
      );

      if (response['available'] != true) {
        if (chapters.isNotEmpty) open(chapters.first);
        return;
      }

      final index = chapters.indexWhere(
        (chapter) => chapter.id == s(response['chapterId']),
      );

      if (index >= 0) {
        open(chapters[index], d(response['positionPercent']));
      } else if (chapters.isNotEmpty) {
        open(chapters.first);
      }
    } catch (_) {
      if (chapters.isNotEmpty) {
        open(chapters.first);
      } else {
        showPendingMessage('Đọc truyện');
      }
    }
  }



  Future<void> showGiftDialog() async {
    const beanAmounts = [10, 20, 50, 100];
    int selectedAmount = beanAmounts.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tặng đậu cho tác giả'),
          content: Wrap(
            spacing: 8,
            children: beanAmounts.map((amount) {
              return ChoiceChip(
                label: Text('$amount đậu'),
                selected: selectedAmount == amount,
                onSelected: (_) {
                  setDialogState(() => selectedAmount = amount);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Tặng đậu'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      showPendingMessage('Tặng đậu');
    }
  }

  Future<void> showRatingDialog() async {
    int selectedRating = 5;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Đánh giá truyện'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () {
                  setDialogState(() => selectedRating = index + 1);
                },
                icon: Icon(
                  index < selectedRating ? Icons.star : Icons.star_border,
                ),
                color: Theme.of(context).colorScheme.primary,
              );
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Gửi đánh giá'),
            ),
          ],
        ),
      ),
    );

    if (submitted == true && mounted) {
      showPendingMessage('Đánh giá');
    }
  }

  Future<void> showReportDialog() async {
    final currentNovel = novel;
    if (currentNovel == null) return;
    if (!widget.session.authenticated) {
      await showAuth(context, widget.session);
      if (!widget.session.authenticated || !mounted) return;
    }
    final sent = await showContentReportDialog(
      context,
      session: widget.session,
      targetType: 1,
      targetId: widget.novelId,
      targetTitle: currentNovel.title,
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi báo cáo để quản trị viên xem xét.')),
      );
    }
  }

  Future<void> copyNovelInfo() async {
    await Clipboard.setData(
      ClipboardData(
        text: '${novel!.title}\n${novel!.author ?? ''}',
      ),
    );

    if (mounted) {
      showMessage('Đã sao chép tên truyện và tác giả.');
    }
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Nút quay lại mặc định của AppBar được giữ nguyên.
        title: Text(novel?.title ?? 'Chi tiết'),
        actions: [
          IconButton(
            tooltip: 'Báo cáo truyện',
            onPressed: novel == null ? null : showReportDialog,
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            tooltip: 'Chia sẻ',
            onPressed: novel == null ? null : copyNovelInfo,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: saved ? 'Bỏ lưu truyện' : 'Lưu truyện',
            onPressed: toggleSaved,
            icon: Icon(
              saved ? Icons.bookmark : Icons.bookmark_border,
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? ErrorRetry(error!, load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Cover(novel!.cover, width: 100, height: 142),
                            const SizedBox(height: 8),
                            // SizedBox(
                            //   width: 112,
                            //   child: OutlinedButton.icon(
                            //     onPressed: showGiftDialog,
                            //     icon: const Icon(Icons.card_giftcard_outlined, size: 18),
                            //     label: const Text('Tặng đậu'),
                            //     style: OutlinedButton.styleFrom(
                            //       padding: const EdgeInsets.symmetric(horizontal: 6),
                            //       visualDensity: VisualDensity.compact,
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                novel!.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              TextButton(
                                onPressed: () =>
                                    showPendingMessage('Trang tác giả'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  alignment: Alignment.centerLeft,
                                ),
                                child: Text(
                                  novel!.author ?? 'Chưa rõ tác giả',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Chip(
                                label: Text(
                                  novel!.completed
                                      ? 'Hoàn thành'
                                      : 'Đang cập nhật',
                                ),
                              ),
                              Text('${chapters.length} chương'),
                              Text('${novel!.views} lượt xem'),
                              if (novel!.updatedAt != null)
                                Text(
                                  'Cập nhật ${formatDate(novel!.updatedAt!)}',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (novel!.categories.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: novel!.categories.map((category) {
                            return Chip(label: Text(category.name));
                          }).toList(),
                        ),
                      )
                    else
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Thể loại chưa được máy chủ cung cấp.'),
                        ),
                      ),


                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: showRatingDialog,
                        icon: const Icon(Icons.star_outline),
                        label: const Text('Đánh giá truyện'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      novel!.description ?? 'Chưa có mô tả.',
                      maxLines: descriptionExpanded ? null : 4,
                      overflow: descriptionExpanded
                          ? null
                          : TextOverflow.ellipsis,
                    ),
                    if ((novel!.description?.length ?? 0) > 180)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              descriptionExpanded = !descriptionExpanded;
                            });
                          },
                          child: Text(
                            descriptionExpanded ? 'Thu gọn' : 'Xem thêm',
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    FilledButton.icon(
      onPressed: chapters.isEmpty ? null : readOrResume,
      icon: const Icon(Icons.menu_book_rounded),
      label: const Text('Đọc truyện'),
    ),
    OutlinedButton.icon(
      onPressed: toggleSaved,
      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline),
      label: Text(saved ? 'Đã lưu' : 'Lưu'),   
    ),


OutlinedButton.icon(
  onPressed: downloadingOffline || chapters.isEmpty
      ? null
      : downloadNovelOffline,
  icon: downloadingOffline
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Icon(Icons.download_for_offline_outlined),
  label: Text(
    downloadingOffline
        ? 'Đang tải ${(offlineDownloadProgress * 100).round()}%'
        : 'Tải xuống',
  ),
),



    OutlinedButton.icon(
      onPressed: showGiftDialog,
      icon: const Icon(Icons.card_giftcard_outlined),
      label: const Text('Tặng đậu'),
    ),
    OutlinedButton.icon(
      onPressed: showRatingDialog,
      icon: const Icon(Icons.star_outline),
      label: const Text('Đánh giá'),
    ),
  ],
),

if (downloadingOffline)
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: LinearProgressIndicator(value: offlineDownloadProgress),
  ),

const Divider(height: 32),


                    const Divider(height: 32),
                    Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bình luận truyện',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bình luận sẽ hiển thị tại đây, kèm tên chương.',
        ),
      ],
    ),
  ),
),
const SizedBox(height: 12),
                    Text(
                      'Danh sách chương',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                          alignment: Alignment.centerRight,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<bool>(
                              isDense: true,
                              value: newestFirst,
                              iconSize: 16,
                              style: Theme.of(context).textTheme.labelSmall,
                              items: const [
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('Cũ nhất trước'),
                                ),
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('Mới nhất trước'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  newestFirst = value;
                                  chapterPage = 1;
                                });
                              },
                            ),
                          ),
                        ),
                    if (chapters.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('Chưa có chương công khai.'),
                        ),
                      ),
                    ...visibleChapters.map(
                      (chapter) => ListTile(
                        title: Text(
                          'Chương ${chapter.number}: ${chapter.title}',
                        ),
                        onTap: () => open(chapter),
                      ),
                    ),
                    if (chapters.length > chaptersPerPage)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Trang trước',
                              onPressed: chapterPage > 1
                                  ? () => setState(() => chapterPage--)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('Trang $chapterPage / $chapterPageCount'),
                            IconButton(
                              tooltip: 'Trang sau',
                              onPressed: chapterPage < chapterPageCount
                                  ? () => setState(() => chapterPage++)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ),
                                      ],
                ),
    );
  }
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.session,
    required this.chapters,
    required this.index,
    this.restorePercent = 0,
  });
  final Session session;
  final List<ChapterInfo> chapters;
  final int index;
  final double restorePercent;
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late int index;
  final scroll = ScrollController();
  final commentController = TextEditingController();
  Timer? debounce;
  final FlutterTts tts = FlutterTts();
Timer? sleepTimer;
bool isSpeaking = false;
bool autoNextChapter = true;
int stopAfterMinutes = 30;
double voiceSpeed = 33;
double voicePitch = 33;
String readerVoice = 'vi-VN-language';
  ChapterContent? chapter;
  String? novelTitle;
  String? sessionId, error;
  int generation = 0, sequence = 0;
  bool loading = true, suppressProgress = false, allowPop = false;
  bool showAudioControls = false;
double speechProgress = 0;
int speechOffset = 0;
int speechRunToken = 0;

String readingMode = 'Kết hợp';

final PageController readerPageController = PageController();

int readerPageIndex = 0;
int readerPageCount = 0;

double pendingReaderPercent = 0;
bool restorePagePending = true;
  bool isAutoScrolling = false;
Timer? autoScrollTimer;
  double? pendingPercent;
double fontSize = 18;
double lineSpacing = 4;
double autoScrollSpeed = 25;
String fontFamily = 'serif';
bool twoSidedMargins = true;
bool autoScrollOnOpen = false;
int background = 0;

TextStyle _readerTextStyle(Color foreground) {
  final base = TextStyle(
    fontSize: fontSize,
    height: 1.15 + lineSpacing * 0.15,
    color: foreground,
  );

  switch (fontFamily) {
    case 'sans':
      return base;
    case 'italic':
      return base.copyWith(
        fontStyle: FontStyle.italic,
      );
    default:
      return base.copyWith(fontFamily: 'serif');
  }
}

  @override
  void initState() {
    super.initState();
    index = widget.index;
    scroll.addListener(onScroll);
    loadPrefs();
    loadChapter(widget.restorePercent);
  }

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        fontSize = p.getDouble('reader_font') ?? 18;
        background = p.getInt('reader_bg') ?? 0;
        lineSpacing = p.getDouble('reader_line_spacing') ?? 4;

final savedFont = p.getString('reader_font_family') ?? 'serif';
fontFamily = const ['serif', 'sans', 'italic'].contains(savedFont)
    ? savedFont
    : 'serif';
readingMode = p.getString('reader_mode') ?? 'Kết hợp';
twoSidedMargins =
    p.getBool('reader_two_sided_margins') ?? true;
autoScrollSpeed =
    p.getDouble('reader_auto_scroll_speed') ?? 25;
  
autoScrollOnOpen =
    p.getBool('reader_auto_scroll_open') ?? false;
        voiceSpeed = p.getDouble('reader_voice_speed') ?? 33;
voicePitch = p.getDouble('reader_voice_pitch') ?? 33;
readerVoice = p.getString('reader_voice') ?? 'vi-VN-language';
autoNextChapter = p.getBool('reader_auto_next') ?? true;
stopAfterMinutes = p.getInt('reader_stop_after') ?? 30;
      });
    }
  }

  Future<void> loadChapter([double restore = 0]) async {
    final mine = ++generation;
    debounce?.cancel();
    pendingPercent = null;
pendingPercent = null;
pendingReaderPercent = restore.clamp(0, 100).toDouble();
restorePagePending = true;
readerPageIndex = 0;
suppressProgress = true;
    sequence = 0;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final c = ChapterContent.from(
        Map<String, dynamic>.from(
          await widget.session.api.get(
            '/api/novels/chapters/${widget.chapters[index].id}',
          ),
        ),
      );
      if (mine != generation) return;
      if (novelTitle == null) {
  try {
    final novelData = await widget.session.api.get(
      '/api/novels/${c.novelId}',
    );
    novelTitle = s(novelData['title']);
  } catch (_) {}
}
      if (widget.session.authenticated) {
        final r = await widget.session.api.post(
          '/api/me/novels/${c.novelId}/chapters/${c.id}/sessions',
          auth: true,
        );
        if (mine != generation) return;
        sessionId = s(r['sessionId']);
      await widget.session.api.post(
  '/api/me/novels/${c.novelId}/chapters/${c.id}/views',
  auth: true,
);
      }
      if (!mounted || mine != generation) return;
      setState(() {
        chapter = c;
        loading = false;
      });
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!mounted || mine != generation) return;

  if (readingMode != 'Lật trang' && scroll.hasClients) {
    scroll.jumpTo(
      scroll.position.maxScrollExtent *
          (restore.clamp(0, 100) / 100),
    );
  }

  if (readingMode != 'Lật trang') {
    suppressProgress = false;

    if (autoScrollOnOpen && !isAutoScrolling) {
      toggleAutoScroll();
    }
  }
});
    } catch (e) {
      if (mounted && mine == generation) {
        setState(() {
          loading = false;
          error = errorText(e);
        });
      }
    }
  }

  void onScroll() {
    if (suppressProgress ||
        sessionId == null ||
        chapter == null ||
        !scroll.hasClients) {
      return;
    }
    final mine = generation;
    final value = scroll.position.maxScrollExtent <= 0
        ? 100.0
        : (scroll.offset / scroll.position.maxScrollExtent * 100)
              .clamp(0, 100)
              .toDouble();
    debounce?.cancel();
    pendingPercent = value;
    debounce = Timer(
      const Duration(milliseconds: 700),
      () => save(value, mine),
    );
  }

  Future<void> save(double value, int mine) async {
    final c = chapter, sid = sessionId;
    if (c == null || sid == null || mine != generation) return;
    try {
      await widget.session.api.put(
        '/api/me/novels/${c.novelId}/chapters/${c.id}/progress',
        auth: true,
        body: {
          'sessionId': sid,
          'sequence': ++sequence,
          'positionPercent': value,
        },
      );
      if (mine == generation && pendingPercent == value) pendingPercent = null;
    } on ApiException catch (e) {
      if (e.status == 409 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiến độ mới hơn đã được giữ nguyên.')),
        );
      }
    }
  }

double _currentPercent() {
  if (readingMode == 'Lật trang' && readerPageCount > 0) {
    return (readerPageIndex / readerPageCount * 100)
        .clamp(0, 100)
        .toDouble();
  }

  if (!scroll.hasClients || scroll.position.maxScrollExtent <= 0) {
    return 0;
  }

  return (scroll.offset / scroll.position.maxScrollExtent * 100)
      .clamp(0, 100)
      .toDouble();
}

  Future<void> flushProgress() async {
    debounce?.cancel();
    if (sessionId != null && chapter != null && !suppressProgress) {
      await save(pendingPercent ?? _currentPercent(), generation);
    }
  }

  Future<void> move(int delta) async {
    final next = index + delta;
    if (next < 0 || next >= widget.chapters.length) return;
    await flushProgress();
    index = next;
    speechOffset = 0;
speechProgress = 0;
    await loadChapter();
  }

  Future<void> changeReaderSetting(int value) async {
    final position = _currentPercent();
    suppressProgress = true;
    setState(() {
      if (value < 3) {
        fontSize = [16.0, 18.0, 22.0][value];
      } else {
        background = value - 3;
      }
    });
    final p = await SharedPreferences.getInstance();
    await p.setDouble('reader_font', fontSize);
    await p.setInt('reader_bg', background);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      scroll.jumpTo(scroll.position.maxScrollExtent * position / 100);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) suppressProgress = false;
      });
    });
  }


void _scheduleProgressSave(double value) {
  if (sessionId == null || chapter == null) return;

  final mine = generation;
  pendingPercent = value.clamp(0, 100).toDouble();
  debounce?.cancel();

  debounce = Timer(const Duration(milliseconds: 700), () {
    final latest = pendingPercent;
    if (latest != null) save(latest, mine);
  });
}

void _onReaderPageChanged(int page, int textPageCount) {
  readerPageIndex = page;
  readerPageCount = textPageCount;

  if (mounted) setState(() {});

  final percent =
      textPageCount == 0 ? 0.0 : page / textPageCount * 100;
  _scheduleProgressSave(percent);
}

List<String> _paginateText(String text, double width, double height) {
  if (text.trim().isEmpty) return const [''];

  final lineHeight = fontSize * (1.15 + lineSpacing * 0.15);
  final charsPerLine =
(width / (fontSize * 0.56)).floor().clamp(8, 120).toInt();
  final linesPerPage =
      (height / lineHeight).floor().clamp(5, 80).toInt();
  final capacity =
      (charsPerLine * linesPerPage * 0.68).floor().clamp(40, 2400).toInt();

  final pages = <String>[];
  var start = 0;

  while (start < text.length) {
    var end = (start + capacity).clamp(start + 1, text.length).toInt();

    if (end < text.length) {
      final minimumBreak = start + (capacity * 0.65).floor();
      final newline = text.lastIndexOf('\n', end);
      final space = text.lastIndexOf(' ', end);
      final breakAt = newline > minimumBreak ? newline : space;

      if (breakAt > minimumBreak) end = breakAt + 1;
    }

    final page = text.substring(start, end).trim();
    if (page.isNotEmpty) pages.add(page);

    start = end;
    while (start < text.length && text[start].trim().isEmpty) {
      start++;
    }
  }

  return pages.isEmpty ? const [''] : pages;
}

Widget _chapterText(String text, Color foreground) {
  return SelectableText(
    text,
    textAlign: TextAlign.justify,
    style: _readerTextStyle(foreground),
  );
}

Widget _chapterEndMatter(Color foreground) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 28),
      OutlinedButton.icon(
        onPressed: showChapterGift,
        icon: const Icon(Icons.card_giftcard_outlined),
        label: const Text('Tặng đậu cho tác giả'),
      ),
      const Divider(height: 36),
      Text(
        'Bình luận chương này',
        style: TextStyle(
          color: foreground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Bình luận sẽ hiển thị khi được kết nối với máy chủ.',
        style: TextStyle(color: foreground.withValues(alpha: 0.7)),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: commentController,
        minLines: 2,
        maxLines: 4,
        style: TextStyle(color: foreground),
        decoration: InputDecoration(
          filled: true,
          fillColor:
              background == 2 ? const Color(0xFF29272D) : Colors.white,
          hintText: 'Chia sẻ cảm nhận của bạn…',
          hintStyle: TextStyle(
            color: background == 2 ? Colors.white60 : Colors.black54,
          ),
          enabledBorder: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: submitChapterComment,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Gửi bình luận'),
        ),
      ),
    ],
  );
}


void toggleAutoScroll() {
 if (readingMode == 'Lật trang') return;
  if (isAutoScrolling) {
    autoScrollTimer?.cancel();
    setState(() => isAutoScrolling = false);
    return;
  }

  setState(() => isAutoScrolling = true);
  autoScrollTimer = Timer.periodic(
    const Duration(milliseconds: 80),
    (_) {
      if (!scroll.hasClients ||
          scroll.position.pixels >= scroll.position.maxScrollExtent) {
        autoScrollTimer?.cancel();
        if (mounted) setState(() => isAutoScrolling = false);
        return;
      }

      scroll.jumpTo(
        (scroll.position.pixels + (autoScrollSpeed / 20).clamp(1.0, 5.0).toDouble()).clamp(
          0.0,
          scroll.position.maxScrollExtent,
        ),
      );
    },
  );
}

Future<void> toggleSpeech() async {
  if (isSpeaking) {
  ++speechRunToken; // Vô hiệu hóa vòng đọc cũ
  sleepTimer?.cancel();

  try {
    await tts.stop();
  } catch (_) {}

  if (mounted) {
    setState(() => isSpeaking = false);
  }
  return;
}

  if (chapter == null) return;

  final text = chapter!.content;
  if (speechOffset >= text.length) {
    speechOffset = 0;
    speechProgress = 0;
  }

  final run = ++speechRunToken;

  setState(() {
    isSpeaking = true;
    showAudioControls = true;
  });

  if (stopAfterMinutes > 0) {
    sleepTimer?.cancel();
    sleepTimer = Timer(Duration(minutes: stopAfterMinutes), () async {
      try {
                ++speechRunToken;
        await tts.stop();
      } catch (_) {}
      if (mounted) setState(() => isSpeaking = false);
    });
  }

  try {
    await tts.awaitSpeakCompletion(false);
    await tts.setLanguage('vi-VN');

    if (readerVoice.isNotEmpty) {
      try {
        await tts.setVoice({
          'name': readerVoice,
          'locale': 'vi-VN',
        });
      } catch (e) {
        debugPrint('Không áp dụng được voice đã chọn: $e');
      }
    }

    // Web: rate 1.0 là bình thường. Android/iOS: khoảng 0.5 là bình thường.
    final rate = kIsWeb
        ? (voiceSpeed / 33).clamp(0.5, 3.0).toDouble()
        : (voiceSpeed / 100).clamp(0.1, 1.0).toDouble();

    await tts.setSpeechRate(rate);
    await tts.setPitch((0.5 + voicePitch / 100).clamp(0.5, 2.0).toDouble());

    // Đọc theo các đoạn ngắn để phần trăm tiến triển dần.
  
    while (mounted && run == speechRunToken && isSpeaking) {
      final currentText = chapter?.content ?? '';
      if (currentText.isEmpty) break;

      if (speechOffset >= currentText.length) {
        if (!autoNextChapter || index + 1 >= widget.chapters.length) break;

        await flushProgress();
        index++;
        speechOffset = 0;
        speechProgress = 0;
        await loadChapter();

        if (!mounted || run != speechRunToken || chapter == null) break;
        continue;
      }
const chunkSize = 180;
      final start = speechOffset;
var end = (start + chunkSize).clamp(0, currentText.length).toInt();

if (end < currentText.length) {
  final space = currentText.lastIndexOf(' ', end);
  final newline = currentText.lastIndexOf('\n', end);
  final breakAt = space > newline ? space : newline;

  if (breakAt > start + (chunkSize * 0.6).round()) {
    end = breakAt + 1;
  }
}

final chunk = currentText.substring(start, end);

      final done = Completer<void>();
      void finish() {
        if (!done.isCompleted) done.complete();
      }

      tts.setCompletionHandler(finish);
      tts.setCancelHandler(finish);
      tts.setErrorHandler((_) => finish());

      tts.setProgressHandler((spokenText, startOffset, endOffset, word) {
        if (!mounted || run != speechRunToken || !isSpeaking) return;

        final offset = (start + endOffset).clamp(start, end);
        setState(() {
          speechOffset = offset;
          speechProgress =
              (speechOffset / currentText.length).clamp(0.0, 1.0).toDouble();
        });
      });

      await tts.speak(chunk);
      // Chờ đọc xong đoạn này (có timeout phòng khi Chrome không báo kết thúc).
      await done.future.timeout(
        Duration(seconds: 20 + chunk.length ~/ 4),
        onTimeout: () {},
      );

      if (!mounted || run != speechRunToken || !isSpeaking) return;

      // Chỉ chuyển sang đoạn sau khi đoạn này thực sự đọc xong.
      speechOffset = end;
      speechProgress =
          (speechOffset / currentText.length).clamp(0.0, 1.0).toDouble();
      setState(() {});
    }
  } catch (_) {
    if (mounted && run == speechRunToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không phát được giọng đọc.')),
      );
    }
  } finally {
    if (mounted && run == speechRunToken) {
      sleepTimer?.cancel();
      setState(() => isSpeaking = false);
    }
  }
}

Future<void> stopSpeech() async {
  ++speechRunToken;
  sleepTimer?.cancel();

  try {
    await tts.stop();
  } catch (_) {}
  if (kIsWeb) await Future.delayed(const Duration(milliseconds: 250));
  if (mounted) {
    setState(() {
      isSpeaking = false;
      speechOffset = 0;
      speechProgress = 0;
    });
  }
}
Future<void> seekSpeech(double progress) async {
  final text = chapter?.content ?? '';
  if (text.isEmpty) return;

  final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();

  // Kéo đến cuối chương thì giữ thanh ở 100%, không phát lại từ đầu.
  if (normalizedProgress >= 1.0) {
    await stopSpeech();
    if (!mounted) return;

    speechOffset = text.length;
    speechProgress = 1.0;
    setState(() => showAudioControls = true);
    return;
  }

  var target = (normalizedProgress * text.length)
      .round()
      .clamp(0, text.length - 1)
      .toInt();

  // Nếu đang ở giữa một từ, lùi về đầu từ.
  while (target > 0 &&
      target < text.length &&
      text[target].trim().isNotEmpty &&
      text[target - 1].trim().isNotEmpty) {
    target--;
  }

  // Bỏ qua khoảng trắng để bắt đầu đọc ở ký tự có nội dung.
  while (target < text.length && text[target].trim().isEmpty) {
    target++;
  }

  await stopSpeech();
  if (!mounted) return;

  speechOffset = target;
  speechProgress =
      (target / text.length).clamp(0.0, 1.0).toDouble();

  setState(() => showAudioControls = true);
  await toggleSpeech();
}
Future<void> moveSpeechChapter(int delta) async {
  final next = index + delta;

  if (next < 0 || next >= widget.chapters.length) return;

  await stopSpeech();
  await move(delta);

  speechOffset = 0;
  speechProgress = 0;

  await toggleSpeech();
}
Future<void> reportChapter() async {
  if (chapter == null) return;
  if (!widget.session.authenticated) {
    await showAuth(context, widget.session);
    if (!widget.session.authenticated || !mounted) return;
  }
  final sent = await showContentReportDialog(
    context,
    session: widget.session,
    targetType: 2,
    targetId: chapter!.id,
    targetTitle: 'Chương ${chapter!.number}: ${chapter!.title}',
  );
  if (sent == true && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã gửi báo cáo để quản trị viên xem xét.')),
    );
  }
}

  @override
  void dispose() {
  debounce?.cancel();
  sleepTimer?.cancel();
  autoScrollTimer?.cancel();
  scroll.dispose();
  readerPageController.dispose();
  commentController.dispose();
  unawaited(tts.stop());
  super.dispose();
}

  Future<void> showChapterGift() async {
    const beanAmounts = [10, 20, 50, 100];
    int selected = beanAmounts.first;

    if (!widget.session.authenticated) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Vui lòng đăng nhập để tặng đậu.')),
  );
  return;
}

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tặng đậu cho tác giả'),
          content: Wrap(
            spacing: 8,
            children: beanAmounts.map((amount) {
              return ChoiceChip(
                label: Text('$amount đậu'),
                selected: selected == amount,
                onSelected: (_) {
                  setDialogState(() => selected = amount);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Tặng đậu'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tặng đậu đang chờ kết nối với máy chủ.'),
        ),
      );
    }
  }

  void submitChapterComment() {

    if (!widget.session.authenticated) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Vui lòng đăng nhập để bình luận.')),
  );
  return;
}

    if (commentController.text.trim().isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bình luận đang chờ kết nối với máy chủ.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = [
      const Color(0xfffffbfc),
      const Color(0xfffff1dc),
      const Color(0xff1d1b20),
    ][background];
    final fg = background == 2 ? Colors.white : Colors.black87;
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await flushProgress();
        if (!context.mounted) return;
        setState(() => allowPop = true);
        Navigator.of(context).pop(result);
      },
      child: Scaffold(
        backgroundColor: bg,
       appBar: AppBar(
  backgroundColor: bg,
  foregroundColor: fg,
 leadingWidth: 100,
 titleSpacing: 0,
actions: [
  IconButton(
    tooltip: 'Báo cáo chương',
    onPressed: reportChapter,
    icon: const Icon(Icons.flag_outlined),
  ),
],
  title: Column(
    
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Chương ${widget.chapters[index].number}: '
        '${chapter?.title ?? "Đang đọc"}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 18),
      ),
      Text(
        '${index + 1}/${widget.chapters.length}',
        style: const TextStyle(fontSize: 12),
      ),
    ],
  ),
),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? ErrorRetry(error!, loadChapter)
            : Column(
                children: [
Expanded(
  child: LayoutBuilder(
    builder: (context, constraints) {
      final contentPadding = EdgeInsets.symmetric(
        horizontal: twoSidedMargins ? 22 : 14,
        vertical: 22,
      );

      if (readingMode == 'Lật trang') {
        final pages = _paginateText(
          chapter!.content,
          constraints.maxWidth - contentPadding.horizontal,
          constraints.maxHeight - contentPadding.vertical * 2,
        );

        readerPageCount = pages.length;

        if (restorePagePending) {
          restorePagePending = false;

          final pageToRestore = (pendingReaderPercent / 100 * pages.length)
              .round()
              .clamp(0, pages.length)
              .toInt();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !readerPageController.hasClients) return;

            readerPageController.jumpToPage(pageToRestore);
            readerPageIndex = pageToRestore;
            suppressProgress = false;
          });
        }

        return PageView.builder(
          controller: readerPageController,
          itemCount: pages.length + 1,
          onPageChanged: (page) =>
              _onReaderPageChanged(page, pages.length),
          itemBuilder: (context, page) {
            return SingleChildScrollView(
              padding: contentPadding,
              child: page == pages.length
                  ? _chapterEndMatter(fg)
                  : _chapterText(pages[page], fg),
            );
          },
        );
      }

      return SingleChildScrollView(
        controller: scroll,
        padding: contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _chapterText(chapter!.content, fg),
            _chapterEndMatter(fg),
          ],
        ),
      );
    },
  ),
),
                  if (showAudioControls)
                  ReaderAudioControls(
  isPlaying: isSpeaking,
  progress: speechProgress,
  onPrevious: () => moveSpeechChapter(-1),
  onPlayStop: toggleSpeech,
  onNext: () => moveSpeechChapter(1),
  onSeek: seekSpeech,
),
                  ReaderToolbar(
  canGoPrevious: index > 0,
  canGoNext: index + 1 < widget.chapters.length,
  isAutoScrolling: isAutoScrolling,
  onPrevious: () => move(-1),
onSettings: () async {
  final previousMode = readingMode;
  final previousPercent = _currentPercent();

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ReaderSettingsPage(tts: tts),
    ),
  );

  await loadPrefs();

  pendingReaderPercent = previousPercent;
  restorePagePending = true;

  if (readingMode != previousMode) {
    if (readingMode != 'Kết hợp' && isAutoScrolling) {
      autoScrollTimer?.cancel();
      setState(() => isAutoScrolling = false);
    }

    readerPageIndex = 0;

    if (readingMode != 'Lật trang' && scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !scroll.hasClients) return;

        scroll.jumpTo(
          scroll.position.maxScrollExtent * previousPercent / 100,
        );

        suppressProgress = false;
      });
    }
  }

    // Đang nghe thì khởi động lại giọng đọc để áp dụng cài đặt mới,
  // giữ nguyên vị trí đang đọc.
  if (isSpeaking) {
    final keepOffset = speechOffset;
    ++speechRunToken;
    try {
      await tts.stop();
    } catch (_) {}
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted) return;
    setState(() => isSpeaking = false);
    speechOffset = keepOffset;
    await toggleSpeech();
  }
},
  onAutoScroll: toggleAutoScroll,
onListen: toggleSpeech,
onChapters: () {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    children: [
      Text(
        novelTitle ?? '',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      const Text('Danh sách chương'),
    ],
  ),
),
            Expanded(
              child: ListView.builder(
                itemCount: widget.chapters.length,
                itemBuilder: (context, chapterIndex) {
                  final item = widget.chapters[chapterIndex];
                  return ListTile(
                    title: Text('Chương ${item.number}: ${item.title}'),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      if (chapterIndex == index) return;
                      await flushProgress();
                      index = chapterIndex;
                      await loadChapter();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
},
onComments: () {
  if (readingMode == 'Lật trang' &&
      readerPageController.hasClients) {
    readerPageController.animateToPage(
      readerPageCount,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  } else if (scroll.hasClients) {
    scroll.animateTo(
      scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }
},
  onNext: () => move(1),
),
                ],
              ),
      ),
    );
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.session, this.embedded = false});
  final Session session;
  final bool embedded;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}
/*
class _LibraryPageState extends State<LibraryPage>{List<Map<String,dynamic>>items=[];int page=1,total=0;bool loading=true;String?error;@override void initState(){super.initState();load();}Future<void>load({bool reset=true})async{if(reset){page=1;setState(()=>loading=true);}try{final r=await widget.session.api.get('/api/me/library',query:{'page':'$page','pageSize':'20','sort':'saved'},auth:true);final got=(r['items']as List).map((e)=>Map<String,dynamic>.from(e)).toList();if(mounted)setState((){items=reset?got:[...items,...got];total=i(r['totalItems']);loading=false;error=null;});}catch(e){if(mounted)setState(()=>loading=false;error=errorText(e););}}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Tủ sách')),body:loading?const Center(child:CircularProgressIndicator()):error!=null?ErrorRetry(error!,load):RefreshIndicator(onRefresh:load,child:items.isEmpty?ListView(children:const[SizedBox(height:200),Center(child:Text('Tủ sách đang trống.'))]):ListView.builder(itemCount:items.length+(items.length<total?1:0),itemBuilder:(_,n){if(n==items.length)return TextButton(onPressed:(){page++;load(reset:false);},child:const Text('Xem thêm'));final x=items[n],id=s(x['novelId'])!;return ListTile(leading:Cover(s(x['coverUrl']),width:58,height:82),title:Text(s(x['title'])??''),subtitle:Text(s(x['originalAuthor'])??'Chưa rõ tác giả'),trailing:IconButton(icon:const Icon(Icons.bookmark_remove),onPressed:()async{await widget.session.api.delete('/api/me/library/$id',auth:true);load();}),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>NovelDetailPage(session:widget.session,novelId:id))).then((_)=>load()));}))));}
*/

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.session, this.embedded = false});
  final Session session;
  final bool embedded;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}
/*
class _HistoryPageState extends State<HistoryPage>{List<Map<String,dynamic>>items=[];int page=1,total=0;bool loading=true;String?error;@override void initState(){super.initState();load();}Future<void>load({bool reset=true})async{if(reset){page=1;setState(()=>loading=true);}try{final r=await widget.session.api.get('/api/me/history',query:{'page':'$page','pageSize':'20'},auth:true);final got=(r['items']as List).map((e)=>Map<String,dynamic>.from(e)).toList();if(mounted)setState((){items=reset?got:[...items,...got];total=i(r['totalItems']);loading=false;error=null;});}catch(e){if(mounted)setState(()=>loading=false;error=errorText(e););}}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Lịch sử đọc')),body:loading?const Center(child:CircularProgressIndicator()):error!=null?ErrorRetry(error!,load):RefreshIndicator(onRefresh:load,child:items.isEmpty?ListView(children:const[SizedBox(height:200),Center(child:Text('Chưa có lịch sử đọc.'))]):ListView.builder(itemCount:items.length+(items.length<total?1:0),itemBuilder:(_,n){if(n==items.length)return TextButton(onPressed:(){page++;load(reset:false);},child:const Text('Xem thêm'));final x=items[n],available=x['available']==true;return ListTile(enabled:available,leading:Icon(available?Icons.menu_book:Icons.lock),title:Text(s(x['novelTitle'])??''),subtitle:Text(available?'Chương ${i(x['chapterNumber'])}: ${s(x['chapterTitle'])??''}':'Không còn khả dụng'),onTap:available?()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>NovelDetailPage(session:widget.session,novelId:s(x['novelId'])!))):null);}))));}
*/

abstract class _PagedPrivateState<T extends StatefulWidget> extends State<T> {
  List<Map<String, dynamic>> items = [];
  int page = 1, total = 0;
  bool loading = true;
  String? error;
  Session get session;
  String get path;
  Map<String, String?> get extraQuery => {};
  Future<void> load({bool reset = true}) async {
    if (reset) {
      page = 1;
      setState(() => loading = true);
    }
    try {
      final r = await session.api.get(
        path,
        query: {'page': '$page', 'pageSize': '20', ...extraQuery},
        auth: true,
      );
      final got = (r['items'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (mounted) {
        setState(() {
          items = reset ? got : [...items, ...got];
          total = i(r['totalItems']);
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = errorText(e);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }
}

class _LibraryPageState extends _PagedPrivateState<LibraryPage> {
  @override
  Session get session => widget.session;
  @override
  String get path => '/api/me/library';
  @override
  Map<String, String?> get extraQuery => {'sort': 'saved'};
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded ? null : AppBar(title: const Text('Tủ sách')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? ErrorRetry(error!, load)
        : RefreshIndicator(
            onRefresh: load,
            child: items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('Tủ sách đang trống.')),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length + (items.length < total ? 1 : 0),
                    itemBuilder: (_, n) {
                      if (n == items.length) {
                        return TextButton(
                          onPressed: () {
                            page++;
                            load(reset: false);
                          },
                          child: const Text('Xem thêm'),
                        );
                      }
                      final x = items[n], id = s(x['novelId'])!;
                      final novel = Novel.from(x);
                      return Stack(
                        children: [
                          NovelListCard(
                            novel: novel,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NovelDetailPage(
                                  session: session,
                                  novelId: id,
                                ),
                              ),
                            ).then((_) => load()),
                          ),
                          Positioned(
                            right: 28,
                            bottom: 10,
                            child: IconButton.filledTonal(
                              tooltip: 'Bỏ lưu',
                              icon: const Icon(Icons.bookmark_remove_outlined),
                              onPressed: () async {
                                await session.api.delete(
                                  '/api/me/library/$id',
                                  auth: true,
                                );
                                load();
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
  );
}

class _HistoryPageState extends _PagedPrivateState<HistoryPage> {
  @override
  Session get session => widget.session;
  @override
  String get path => '/api/me/history';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded ? null : AppBar(title: const Text('Lịch sử đọc')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? ErrorRetry(error!, load)
        : RefreshIndicator(
            onRefresh: load,
            child: items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('Chưa có lịch sử đọc.')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length + (items.length < total ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, n) {
                      if (n == items.length) {
                        return TextButton(
                          onPressed: () {
                            page++;
                            load(reset: false);
                          },
                          child: const Text('Xem thêm'),
                        );
                      }
                      final x = items[n], available = x['available'] == true;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        enabled: available,
                        leading: CircleAvatar(
                          backgroundColor: available
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          child: Icon(available ? Icons.menu_book : Icons.lock),
                        ),
                        title: Text(
                          s(x['novelTitle']) ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          available
                              ? 'Chương ${i(x['chapterNumber'])}: ${s(x['chapterTitle']) ?? ''}'
                              : 'Nội dung không còn khả dụng',
                        ),
                        trailing: available
                            ? const Icon(Icons.chevron_right)
                            : const Chip(label: Text('Không khả dụng')),
                        onTap: available
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NovelDetailPage(
                                    session: session,
                                    novelId: s(x['novelId'])!,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
          ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) {
    final u = session.user;
    if (u == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hồ sơ')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FilledButton(
              onPressed: () => showAuth(context, session),
              child: const Text('Đăng nhập / Đăng ký'),
            ),
            const SizedBox(height: 16),
            _appearanceTile(context),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: u.avatar?.isNotEmpty == true
                ? NetworkImage(u.avatar!)
                : null,
            child: u.avatar?.isNotEmpty == true
                ? null
                : Text(
                    (u.displayName ?? u.fullName).characters.first
                        .toUpperCase(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              u.displayName ?? u.fullName,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Center(child: Text(u.email)),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Sửa hồ sơ'),
            onTap: () => editProfile(context, session),
          ),
          if (u.role == 0 || u.role == 1)
            ListTile(
              key: const Key('profile-author-application'),
              leading: const Icon(Icons.badge_outlined),
              title: Text(
                u.role == 1 ? 'Tài khoản tác giả' : 'Đăng ký làm tác giả',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AuthorApplicationPage(session: session),
                ),
              ),
            ),
          if (u.role == 1)
            ListTile(
              key: const Key('profile-my-novels'),
              leading: const Icon(Icons.library_books_outlined),
              title: const Text('Truyện của tôi'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyNovelsPage(session: session),
                ),
              ),
            ),
          _appearanceTile(context),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: session.logout,
          ),
        ],
      ),
    );
  }
}

Widget _appearanceTile(BuildContext context) => ListTile(
  leading: const Icon(Icons.palette_outlined),
  title: const Text('Giao diện'),
  subtitle: Text(switch (NoviThemeController.instance.mode) {
    ThemeMode.light => 'Sáng',
    ThemeMode.dark => 'Tối',
    ThemeMode.system => 'Theo hệ thống',
  }),
  onTap: () => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: RadioGroup<ThemeMode>(
        groupValue: NoviThemeController.instance.mode,
        onChanged: (value) async {
          if (value == null) return;
          await NoviThemeController.instance.setMode(value);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Giao diện',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final option in const [
              (ThemeMode.light, 'Sáng', Icons.light_mode_outlined),
              (ThemeMode.dark, 'Tối', Icons.dark_mode_outlined),
              (
                ThemeMode.system,
                'Theo hệ thống',
                Icons.settings_suggest_outlined,
              ),
            ])
              RadioListTile<ThemeMode>(
                value: option.$1,
                title: Text(option.$2),
                secondary: Icon(option.$3),
              ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> showAuth(BuildContext context, Session session) async {
  final result = await showModalBottomSheet<AuthResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        AuthSheet(onLogin: session.login, onRegister: session.register),
  );
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == AuthResult.register
              ? 'Đăng ký thành công.'
              : 'Đăng nhập thành công.',
        ),
      ),
    );
  }
}

Future<void> editProfile(BuildContext context, Session session) async {
  final full = TextEditingController(text: session.user?.fullName),
      display = TextEditingController(text: session.user?.displayName);
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sửa hồ sơ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: full,
            decoration: const InputDecoration(labelText: 'Họ tên'),
          ),
          TextField(
            controller: display,
            decoration: const InputDecoration(labelText: 'Tên hiển thị'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await session.updateProfile(full.text, display.text);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(errorText(e))));
              }
            }
          },
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
}