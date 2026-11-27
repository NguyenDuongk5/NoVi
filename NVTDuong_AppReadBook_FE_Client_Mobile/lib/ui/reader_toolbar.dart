import 'package:flutter/material.dart';

class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    super.key,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.isAutoScrolling,
    required this.onPrevious,
    required this.onSettings,
    required this.onAutoScroll,
    required this.onListen,
    required this.onChapters,
    required this.onComments,
    required this.onNext,
  });

  final bool canGoPrevious;
  final bool canGoNext;
  final bool isAutoScrolling;

  final VoidCallback onPrevious;
  final VoidCallback onSettings;
  final VoidCallback onAutoScroll;
  final VoidCallback onListen;
  final VoidCallback onChapters;
  final VoidCallback onComments;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: 'Chương trước',
              onPressed: canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton(
              tooltip: 'Cài đặt',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
            IconButton(
              tooltip: isAutoScrolling ? 'Dừng cuộn' : 'Tự cuộn',
              onPressed: onAutoScroll,
              icon: Icon(
                isAutoScrolling
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
            ),
            IconButton(
              tooltip: 'Nghe',
              onPressed: onListen,
              icon: const Icon(Icons.headphones_outlined),
            ),
            IconButton(
              tooltip: 'Danh sách chương',
              onPressed: onChapters,
              icon: const Icon(Icons.menu),
            ),
            // IconButton(
            //   tooltip: 'Bình luận',
            //   onPressed: onComments,
            //   icon: const Icon(Icons.more_horiz_rounded),
            // ),
            IconButton(
              tooltip: 'Chương sau',
              onPressed: canGoNext ? onNext : null,
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ),
    );
  }
}