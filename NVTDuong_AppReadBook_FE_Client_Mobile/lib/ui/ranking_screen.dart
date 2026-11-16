import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/session.dart';
import 'ranking_widgets.dart';

class RankingRequestGate {
  int _current = 0;
  int next() => ++_current;
  int get current => _current;
  bool accepts(int request) => request == _current;
}

class RankingScreen extends StatefulWidget {
  const RankingScreen({
    super.key,
    required this.session,
    required this.onOpenNovel,
    this.initialPeriod = 'month',
  });

  final Session session;
  final void Function(BuildContext context, String novelId) onOpenNovel;
  final String initialPeriod;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  List<Category> categories = [];
  List<RankedNovel> items = [];
  late String period;
  String filter = 'all';
  int page = 1, total = 0;
  final requestGate = RankingRequestGate();
  bool loading = true, loadingMore = false;
  String? error;

  @override
  void initState() {
    super.initState();
    period = widget.initialPeriod;
    _loadCategories();
    load();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await widget.session.api.get('/api/categories') as List;
      if (!mounted) return;
      setState(() {
        categories = response
            .map((e) => Category.from(Map<String, dynamic>.from(e)))
            .toList();
      });
    } catch (_) {
      // Danh sách BXH vẫn dùng được với bộ lọc Tất cả/Hoàn thành.
    }
  }

  Future<void> load({bool reset = true}) async {
    final mine = reset ? requestGate.next() : requestGate.current;
    if (reset) {
      page = 1;
      setState(() {
        loading = true;
        error = null;
      });
    } else {
      setState(() => loadingMore = true);
    }
    try {
      final response = await widget.session.api.get(
        '/api/novels/rankings',
        query: {
          'period': period,
          'page': '$page',
          'pageSize': '20',
          'completed': filter == 'completed' ? 'true' : null,
          'categoryId': filter.startsWith('category:')
              ? filter.substring('category:'.length)
              : null,
        },
      );
      final data = RankingPageData.from(Map<String, dynamic>.from(response));
      if (!mounted || !requestGate.accepts(mine)) return;
      setState(() {
        items = reset ? data.items : [...items, ...data.items];
        total = data.total;
        loading = false;
        loadingMore = false;
        error = null;
      });
    } catch (exception) {
      if (!mounted || !requestGate.accepts(mine)) return;
      setState(() {
        loading = false;
        loadingMore = false;
        error = exception is ApiException
            ? exception.message
            : 'Không thể tải bảng xếp hạng.';
      });
    }
  }

  void _selectPeriod(String value) {
    if (period == value) return;
    setState(() => period = value);
    load();
  }

  void _selectFilter(String value) {
    if (filter == value) return;
    setState(() => filter = value);
    load();
  }

  List<({String id, String label})> get filters => [
    (id: 'all', label: 'Tất cả'),
    (id: 'completed', label: 'Hoàn thành'),
    ...categories.map(
      (category) => (id: 'category:${category.id}', label: category.name),
    ),
  ];

  Future<void> _showFilterSheet() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Lọc bảng xếp hạng',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ...filters.map(
              (item) => ListTile(
                title: Text(item.label),
                trailing: item.id == filter
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(context, item.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) _selectFilter(chosen);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(centerTitle: true, title: const Text('Bảng xếp hạng')),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'week', label: Text('Tuần này')),
                    ButtonSegment(value: 'month', label: Text('Tháng này')),
                    ButtonSegment(value: 'all', label: Text('Tất cả')),
                  ],
                  selected: {period},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) => _selectPeriod(value.first),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 520;
                return Column(
                  children: [
                    if (narrow)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: OutlinedButton.icon(
                          onPressed: _showFilterSheet,
                          icon: const Icon(Icons.tune),
                          label: Text(_filterLabel()),
                        ),
                      ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!narrow)
                            SizedBox(
                              width: 104,
                              child: ColoredBox(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: ListView(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  children: filters.map(_filterTile).toList(),
                                ),
                              ),
                            ),
                          Expanded(child: _rankingContent()),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  String _filterLabel() => filters
      .firstWhere((item) => item.id == filter, orElse: () => filters.first)
      .label;

  Widget _filterTile(({String id, String label}) item) {
    final selected = item.id == filter;
    return InkWell(
      onTap: () => _selectFilter(item.id),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              width: 4,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        child: Text(
          item.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _rankingContent() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: load,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('Chưa có lượt đọc trong kỳ này.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView.separated(
        key: PageStorageKey('ranking-$period-$filter'),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: items.length + (items.length < total ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: loadingMore
                    ? null
                    : () {
                        page++;
                        load(reset: false);
                      },
                child: loadingMore
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tải thêm'),
              ),
            );
          }
          final item = items[index];
          return RankingNovelRow(
            item: item,
            onTap: () => widget.onOpenNovel(context, item.novel.id),
          );
        },
      ),
    );
  }
}
