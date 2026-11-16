import 'package:flutter/material.dart';

import '../core/api.dart';

class NoviTopTabs extends StatelessWidget {
  const NoviTopTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: labels.length,
      separatorBuilder: (_, _) => const SizedBox(width: 24),
      itemBuilder: (_, index) {
        final selected = selectedIndex == index;
        return Semantics(
          selected: selected,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelected(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 28 : 0,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class NoviSectionTitle extends StatelessWidget {
  const NoviSectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      if (subtitle != null)
        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class NoviCategoryFilter extends StatelessWidget {
  const NoviCategoryFilter({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final id = index == 0 ? null : categories[index - 1].id;
          final label = index == 0 ? 'Tất cả' : categories[index - 1].name;
          final selected = selectedId == id;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => onSelected(id),
            showCheckmark: false,
            selectedColor: colors.primary,
            backgroundColor: selected ? colors.primary : colors.surface,
            labelStyle: TextStyle(
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            side: BorderSide(color: colors.primary.withValues(alpha: .14)),
          );
        },
      ),
    );
  }
}

class NoviCover extends StatelessWidget {
  const NoviCover(
    this.url, {
    super.key,
    this.width = 94,
    this.height = 126,
    this.completed = false,
  });

  final String? url;
  final double width;
  final double height;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = mediaUrl(url);
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (resolvedUrl == null)
              fallback
            else
              Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
            if (completed)
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  color: Theme.of(context).colorScheme.primary,
                  child: Text(
                    'Hoàn thành',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.surface,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CompactNovelCard extends StatelessWidget {
  const CompactNovelCard({super.key, required this.novel, required this.onTap});

  final Novel novel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 132,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NoviCover(
              novel.cover,
              width: 132,
              height: 176,
              completed: novel.completed,
            ),
            const SizedBox(height: 8),
            Text(
              novel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              novel.author ?? 'Chưa rõ tác giả',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class NovelListCard extends StatelessWidget {
  const NovelListCard({super.key, required this.novel, required this.onTap});

  final Novel novel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NoviCover(
            novel.cover,
            width: 94,
            height: 126,
            completed: novel.completed,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  novel.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  novel.author ?? 'Chưa rõ tác giả',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (novel.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 7),
                  Text(
                    novel.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined, size: 17),
                    const SizedBox(width: 5),
                    Text('${novel.views} lượt đọc'),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    ),
  );
}

class ContinueReadingBar extends StatelessWidget {
  const ContinueReadingBar({
    super.key,
    required this.coverUrl,
    required this.title,
    required this.chapter,
    required this.onContinue,
    required this.onClose,
  });

  final String? coverUrl;
  final String title;
  final String chapter;
  final VoidCallback onContinue;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    elevation: 5,
    child: SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          children: [
            NoviCover(coverUrl, width: 42, height: 54),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    chapter,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton(onPressed: onContinue, child: const Text('Đọc tiếp')),
            IconButton(
              tooltip: 'Ẩn',
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      ),
    ),
  );
}
