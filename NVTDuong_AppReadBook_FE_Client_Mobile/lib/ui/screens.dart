import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme_controller.dart';
import 'auth_sheet.dart';
import 'author_application.dart';
import 'content_report.dart';
import 'home_widgets.dart';
import 'publishing.dart';
import 'ranking_screen.dart';
import 'ranking_widgets.dart';

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
          ExplorePage(session: widget.session),
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
  const ExplorePage({super.key, required this.session});
  final Session session;
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final search = TextEditingController();
  Timer? _searchDebounce;
  List<Novel> items = [];
  List<Category> categories = [];
  List<RankedNovel> rankings = [];
  String? category, error;
  String? rankingError;
  int page = 1, total = 0;
  int searchGeneration = 0;
  int topTab = 0;
  bool loading = true, loadingMore = false, rankingLoading = true;
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
    _searchDebounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), load);
  }

  void _submitSearch(String _) {
    _searchDebounce?.cancel();
    load();
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
    if (!reset && loadingMore) return;
    final mine = reset ? ++searchGeneration : searchGeneration;
    if (reset) {
      page = 1;
      setState(() {
        loading = true;
        error = null;
      });
    } else {
      setState(() {
        loadingMore = true;
        loadMoreError = null;
      });
    }
    try {
      final r = await widget.session.api.get(
        '/api/novels',
        query: {
          'keyword': search.text.trim().isEmpty ? null : search.text.trim(),
          'categoryId': category,
          'page': '$page',
          'pageSize': '12',
        },
      );
      final got = (r['items'] as List)
          .map((e) => Novel.from(Map<String, dynamic>.from(e)))
          .toList();
      if (mounted && mine == searchGeneration) {
        setState(() {
          final combined = reset ? got : [...items, ...got];
          final seen = <String>{};
          items = combined.where((novel) => seen.add(novel.id)).toList();
          total = i(r['totalItems']);
          loading = false;
          loadingMore = false;
          loadMoreError = null;
        });
      }
    } catch (e) {
      if (mounted && mine == searchGeneration) {
        setState(() {
          loading = false;
          loadingMore = false;
          if (reset) {
            error = errorText(e);
          } else {
            loadMoreError = errorText(e);
          }
        });
      }
    }
  }

  void openNovel(Novel novel) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          NovelDetailPage(session: widget.session, novelId: novel.id),
    ),
  );

  void openRankings() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RankingScreen(
        session: widget.session,
        onOpenNovel: (rankingContext, novelId) => Navigator.push(
          rankingContext,
          MaterialPageRoute(
            builder: (_) =>
                NovelDetailPage(session: widget.session, novelId: novelId),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
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
                        Expanded(
                          child: Text(
                            'NoVi',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip:
                              Theme.of(context).brightness == Brightness.dark
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
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.session.user == null
                          ? 'Chào bạn, hôm nay mình đọc gì?'
                          : 'Chào ${widget.session.user!.displayName ?? widget.session.user!.fullName}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    NoviTopTabs(
                      labels: const ['Khám phá', 'Thể loại'],
                      selectedIndex: topTab,
                      onSelected: (value) {
                        if (value == topTab) return;
                        setState(() => topTab = value);
                        if (value == 0 && category != null) {
                          category = null;
                          load();
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SearchBar(
                            key: const Key('home-search'),
                            controller: search,
                            hintText: 'Tìm truyện, tác giả…',
                            textInputAction: TextInputAction.search,
                            elevation: const WidgetStatePropertyAll(0),
                            leading: const Icon(Icons.search),
                            onChanged: _onSearchChanged,
                            onSubmitted: _submitSearch,
                            trailing: search.text.isEmpty
                                ? null
                                : [
                                    IconButton(
                                      tooltip: 'Xóa tìm kiếm',
                                      onPressed: () {
                                        _searchDebounce?.cancel();
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
                    selectedId: category,
                    onSelected: (value) {
                      category = value;
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
                      height: 246,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length > 6 ? 6 : items.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (_, n) => CompactNovelCard(
                          key: Key('explore-compact-novel-${items[n].id}'),
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
                      key: Key('explore-list-novel-${items[n].id}'),
                      novel: items[n],
                      onTap: () => openNovel(items[n]),
                    ),
                  ),
                ),
                if (items.length < total)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    sliver: SliverToBoxAdapter(
                      child: loadingMore
                          ? const Center(child: CircularProgressIndicator())
                          : loadMoreError != null
                          ? OutlinedButton.icon(
                              onPressed: () => load(reset: false),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tải lỗi – Thử lại'),
                            )
                          : OutlinedButton(
                              onPressed: () {
                                page++;
                                load(reset: false);
                              },
                              child: const Text('Xem thêm'),
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
  bool loading = true, saved = false;
  String? error;
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
        final r = await widget.session.api.get(
          '/api/me/library',
          query: {'page': '1', 'pageSize': '100'},
          auth: true,
        );
        saved = (r['items'] as List).any(
          (e) => s(e['novelId']) == widget.novelId,
        );
      }
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = errorText(e);
        });
      }
    }
  }

  Future<void> toggle() async {
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
      setState(() => saved = !saved);
    } catch (e) {
      _snack(e);
    }
  }

  Future<void> reportNovel() async {
    if (!widget.session.authenticated) {
      await showAuth(context, widget.session);
      if (!widget.session.authenticated || !mounted) return;
    }
    final sent = await showContentReportDialog(context,
      session: widget.session, targetType: 1, targetId: widget.novelId,
      targetTitle: novel?.title ?? 'Truyện');
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi báo cáo để quản trị viên xem xét.')));
    }
  }

  void _snack(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  void open(ChapterInfo c, [double position = 0]) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ReaderPage(
        session: widget.session,
        chapters: chapters,
        index: chapters.indexOf(c),
        restorePercent: position,
      ),
    ),
  );
  Future<void> resume() async {
    try {
      final r = await widget.session.api.get(
        '/api/me/novels/${widget.novelId}/continue',
        auth: true,
      );
      if (r['available'] != true) {
        throw ApiException(404, 'Chương không còn khả dụng.');
      }
      final idx = chapters.indexWhere((x) => x.id == s(r['chapterId']));
      if (idx >= 0) open(chapters[idx], d(r['positionPercent']));
    } on ApiException catch (e) {
      if (e.status == 404 && chapters.isNotEmpty) {
        open(chapters.first);
      } else {
        _snack(e);
      }
    } catch (e) {
      _snack(e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(novel?.title ?? 'Chi tiết'),
      actions: [
        IconButton(
          onPressed: toggle,
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
        ),
        PopupMenuButton<String>(
          tooltip: 'Tùy chọn',
          onSelected: (value) { if (value == 'report') reportNovel(); },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'report', child: ListTile(
              contentPadding: EdgeInsets.zero, leading: Icon(Icons.flag_outlined), title: Text('Báo cáo'))),
          ],
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
                  Cover(novel!.cover, width: 112, height: 158),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          novel!.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(novel!.author ?? 'Chưa rõ tác giả'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            novel!.completed ? 'Hoàn thành' : 'Đang cập nhật',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(novel!.description ?? 'Chưa có mô tả.'),
              if (novel!.categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: novel!.categories
                      .map((category) => Chip(label: Text(category.name)))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: chapters.isEmpty
                        ? null
                        : widget.session.authenticated
                        ? resume
                        : () => open(chapters.first),
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('Đọc / Đọc tiếp'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: toggle,
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline),
                    label: Text(saved ? 'Đã lưu' : 'Lưu truyện'),
                  ),
                ],
              ),
              const Divider(),
              const Text('Danh sách chương'),
              if (chapters.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Chưa có chương công khai.')),
                ),
              ...chapters.map(
                (c) => ListTile(
                  title: Text('Chương ${c.number}: ${c.title}'),
                  onTap: () => open(c),
                ),
              ),
            ],
          ),
  );
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
  Timer? debounce;
  ChapterContent? chapter;
  String? sessionId, error;
  int generation = 0, sequence = 0;
  bool loading = true, suppressProgress = false, allowPop = false;
  double? pendingPercent;
  double fontSize = 18;
  int background = 0;
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
      });
    }
  }

  Future<void> loadChapter([double restore = 0]) async {
    final mine = ++generation;
    debounce?.cancel();
    pendingPercent = null;
    suppressProgress = true;
    sessionId = null;
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
        if (mounted && mine == generation && scroll.hasClients) {
          scroll.jumpTo(
            scroll.position.maxScrollExtent * (restore.clamp(0, 100) / 100),
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && mine == generation) suppressProgress = false;
          });
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

  double _currentPercent() =>
      !scroll.hasClients || scroll.position.maxScrollExtent <= 0
      ? 100
      : (scroll.offset / scroll.position.maxScrollExtent * 100)
            .clamp(0, 100)
            .toDouble();

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

  Future<void> reportChapter() async {
    if (chapter == null) return;
    if (!widget.session.authenticated) {
      await showAuth(context, widget.session);
      if (!widget.session.authenticated || !mounted) return;
    }
    final sent = await showContentReportDialog(context,
      session: widget.session, targetType: 2, targetId: chapter!.id,
      targetTitle: 'Chương ${chapter!.number}: ${chapter!.title}');
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi báo cáo để quản trị viên xem xét.')));
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    scroll.dispose();
    super.dispose();
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
          title: Text(chapter?.title ?? 'Đang đọc'),
          actions: [
            IconButton(
              key: const Key('report-chapter'),
              tooltip: 'Báo cáo chương',
              onPressed: chapter == null ? null : reportChapter,
              icon: const Icon(Icons.flag_outlined),
            ),
            PopupMenuButton<int>(
              onSelected: changeReaderSetting,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0, child: Text('Chữ nhỏ')),
                PopupMenuItem(value: 1, child: Text('Chữ vừa')),
                PopupMenuItem(value: 2, child: Text('Chữ lớn')),
                PopupMenuItem(value: 3, child: Text('Nền sáng')),
                PopupMenuItem(value: 4, child: Text('Nền vàng')),
                PopupMenuItem(value: 5, child: Text('Nền tối')),
              ],
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? ErrorRetry(error!, loadChapter)
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scroll,
                      padding: const EdgeInsets.all(22),
                      child: SelectableText(
                        chapter!.content,
                        style: TextStyle(
                          fontSize: fontSize,
                          height: 1.75,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: index > 0 ? () => move(-1) : null,
                        child: const Text('Chương trước'),
                      ),
                      Text('${index + 1}/${widget.chapters.length}'),
                      TextButton(
                        onPressed: index + 1 < widget.chapters.length
                            ? () => move(1)
                            : null,
                        child: const Text('Chương sau'),
                      ),
                    ],
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
class _LibraryPageState extends State<LibraryPage>{List<Map<String,dynamic>>items=[];int page=1,total=0;bool loading=true;String?error;@override void initState(){super.initState();load();}Future<void>load({bool reset=true})async{if(reset){page=1;setState(()=>loading=true);}try{final r=await widget.session.api.get('/api/me/library',query:{'page':'$page','pageSize':'20','sort':'saved'},auth:true);final got=(r['items']as List).map((e)=>Map<String,dynamic>.from(e)).toList();if(mounted)setState((){items=reset?got:[...items,...got];total=i(r['totalItems']);loading=false;error=null;});}catch(e){if(mounted)setState((){loading=false;error=errorText(e);});}}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Tủ sách')),body:loading?const Center(child:CircularProgressIndicator()):error!=null?ErrorRetry(error!,load):RefreshIndicator(onRefresh:load,child:items.isEmpty?ListView(children:const[SizedBox(height:200),Center(child:Text('Tủ sách đang trống.'))]):ListView.builder(itemCount:items.length+(items.length<total?1:0),itemBuilder:(_,n){if(n==items.length)return TextButton(onPressed:(){page++;load(reset:false);},child:const Text('Xem thêm'));final x=items[n],id=s(x['novelId'])!;return ListTile(leading:Cover(s(x['coverUrl']),width:58,height:82),title:Text(s(x['title'])??''),subtitle:Text(s(x['originalAuthor'])??'Chưa rõ tác giả'),trailing:IconButton(icon:const Icon(Icons.bookmark_remove),onPressed:()async{await widget.session.api.delete('/api/me/library/$id',auth:true);load();}),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>NovelDetailPage(session:widget.session,novelId:id))).then((_)=>load()));}))));}
*/

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.session, this.embedded = false});
  final Session session;
  final bool embedded;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}
/*
class _HistoryPageState extends State<HistoryPage>{List<Map<String,dynamic>>items=[];int page=1,total=0;bool loading=true;String?error;@override void initState(){super.initState();load();}Future<void>load({bool reset=true})async{if(reset){page=1;setState(()=>loading=true);}try{final r=await widget.session.api.get('/api/me/history',query:{'page':'$page','pageSize':'20'},auth:true);final got=(r['items']as List).map((e)=>Map<String,dynamic>.from(e)).toList();if(mounted)setState((){items=reset?got:[...items,...got];total=i(r['totalItems']);loading=false;error=null;});}catch(e){if(mounted)setState((){loading=false;error=errorText(e);});}}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Lịch sử đọc')),body:loading?const Center(child:CircularProgressIndicator()):error!=null?ErrorRetry(error!,load):RefreshIndicator(onRefresh:load,child:items.isEmpty?ListView(children:const[SizedBox(height:200),Center(child:Text('Chưa có lịch sử đọc.'))]):ListView.builder(itemCount:items.length+(items.length<total?1:0),itemBuilder:(_,n){if(n==items.length)return TextButton(onPressed:(){page++;load(reset:false);},child:const Text('Xem thêm'));final x=items[n],available=x['available']==true;return ListTile(enabled:available,leading:Icon(available?Icons.menu_book:Icons.lock),title:Text(s(x['novelTitle'])??''),subtitle:Text(available?'Chương ${i(x['chapterNumber'])}: ${s(x['chapterTitle'])??''}':'Không còn khả dụng'),onTap:available?()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>NovelDetailPage(session:widget.session,novelId:s(x['novelId'])!))):null);}))));}
*/

abstract class _PagedPrivateState<T extends StatefulWidget> extends State<T> {
  List<Map<String, dynamic>> items = [];
  int page = 1, total = 0;
  int generation = 0;
  bool loading = true, loadingMore = false;
  String? error, loadMoreError;
  final scroll = ScrollController();
  Session get session;
  String get path;
  Map<String, String?> get extraQuery => {};
  Future<void> load({bool reset = true}) async {
    if (!reset && (loadingMore || items.length >= total)) return;
    final mine = reset ? ++generation : generation;
    if (reset) {
      page = 1;
      setState(() {
        loading = true;
        error = null;
      });
    } else {
      setState(() {
        loadingMore = true;
        loadMoreError = null;
      });
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
      if (mounted && mine == generation) {
        setState(() {
          final combined = reset ? got : [...items, ...got];
          final seen = <String>{};
          items = combined.where((x) {
            final key = s(x['historyId']) ?? s(x['novelId']) ?? x.toString();
            return seen.add(key);
          }).toList();
          total = i(r['totalItems']);
          loading = false;
          loadingMore = false;
          error = null;
          loadMoreError = null;
        });
      }
    } catch (e) {
      if (mounted && mine == generation) {
        setState(() {
          loading = false;
          loadingMore = false;
          if (reset) {
            error = errorText(e);
          } else {
            loadMoreError = errorText(e);
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.extentAfter < 240 &&
          items.length < total &&
          !loadingMore &&
          loadMoreError == null) {
        page++;
        load(reset: false);
      }
    });
    load();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Widget loadMoreFooter() {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (loadMoreError != null) {
      return TextButton.icon(
        onPressed: () => load(reset: false),
        icon: const Icon(Icons.refresh),
        label: const Text('Tải thêm lỗi – Thử lại'),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: Text('Đã tải hết dữ liệu')),
    );
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
                    controller: scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length + (items.length < total ? 1 : 0),
                    itemBuilder: (_, n) {
                      if (n == items.length) {
                        return loadMoreFooter();
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
                    controller: scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length + (items.length < total ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, n) {
                      if (n == items.length) {
                        return loadMoreFooter();
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
