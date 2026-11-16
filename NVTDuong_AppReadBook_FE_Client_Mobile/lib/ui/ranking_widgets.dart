import 'dart:math';

import 'package:flutter/material.dart';

import '../core/api.dart';
import 'home_widgets.dart';

String compactCount(int value) {
  if (value >= 1000000) {
    final number = value / 1000000;
    return '${number.toStringAsFixed(number >= 10 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final number = value / 1000;
    return '${number.toStringAsFixed(number >= 10 ? 0 : 1)}K';
  }
  return '$value';
}

class RankingBadge extends StatelessWidget {
  const RankingBadge(this.rank, {super.key});
  final int rank;

  @override
  Widget build(BuildContext context) {
    const podiumColors = [
      Color(0xffffc34d),
      Color(0xffb9a6df),
      Color(0xffffa98f),
    ];
    final isPodium = rank >= 1 && rank <= 3;
    final color = isPodium ? podiumColors[rank - 1] : const Color(0xffffe5ee);
    return Semantics(
      label: 'Hạng $rank',
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: isPodium
            ? Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              )
            : Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class RankingNovelRow extends StatelessWidget {
  const RankingNovelRow({
    super.key,
    required this.item,
    required this.onTap,
    this.compact = false,
  });
  final RankedNovel item;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final novel = item.novel;
    return Semantics(
      button: true,
      label:
          '${novel.title}, hạng ${item.rank}, ${item.periodViewCount} lượt đọc trong kỳ',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 7 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                RankingBadge(item.rank),
                const SizedBox(width: 10),
              ],
              NoviCover(
                novel.cover,
                width: compact ? 58 : 72,
                height: compact ? 78 : 96,
                completed: novel.completed,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      novel.author ?? 'Chưa rõ tác giả',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${compactCount(item.periodViewCount)} lượt đọc',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (!compact && item.categories.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: item.categories
                            .take(2)
                            .map(
                              (category) => Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  category.name,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                side: BorderSide.none,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                RankingBadge(item.rank),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class RankingPreview extends StatelessWidget {
  const RankingPreview({super.key, required this.items, required this.onOpen});
  final List<RankedNovel> items;
  final ValueChanged<RankedNovel> onOpen;

  @override
  Widget build(BuildContext context) {
    final groups = <List<RankedNovel>>[];
    for (var start = 0; start < items.length; start += 3) {
      groups.add(items.sublist(start, min(start + 3, items.length)));
    }
    return SizedBox(
      height: 292,
      child: PageView.builder(
        padEnds: false,
        controller: PageController(viewportFraction: .94),
        itemCount: groups.length,
        itemBuilder: (_, page) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  for (var index = 0; index < groups[page].length; index++) ...[
                    Expanded(
                      child: RankingNovelRow(
                        item: groups[page][index],
                        compact: true,
                        onTap: () => onOpen(groups[page][index]),
                      ),
                    ),
                    if (index + 1 < groups[page].length)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
