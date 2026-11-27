import 'package:flutter/material.dart';

class ReaderAudioControls extends StatefulWidget {
  const ReaderAudioControls({
    super.key,
    required this.isPlaying,
    required this.progress,
    required this.onPrevious,
    required this.onPlayStop,
    required this.onNext,
    required this.onSeek,
  });

  final bool isPlaying;
  final double progress;
  final VoidCallback onPrevious;
  final VoidCallback onPlayStop;
  final VoidCallback onNext;
  final ValueChanged<double> onSeek;

  @override
  State<ReaderAudioControls> createState() => _ReaderAudioControlsState();
}

class _ReaderAudioControlsState extends State<ReaderAudioControls> {
  double? previewProgress;

  @override
  Widget build(BuildContext context) {
    final value = (previewProgress ?? widget.progress)
        .clamp(0.0, 1.0)
        .toDouble();

    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Chương trước',
                onPressed: widget.onPrevious,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              IconButton(
                tooltip: widget.isPlaying ? 'Tạm dừng' : 'Tiếp tục đọc',
                onPressed: widget.onPlayStop,
                icon: Icon(
                  widget.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  size: 32,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Slider(
                      value: value,
                      min: 0,
                      max: 1,
                      onChanged: (newValue) {
                        setState(() => previewProgress = newValue);
                      },
                      onChangeEnd: (newValue) {
                        setState(() => previewProgress = null);
                        widget.onSeek(newValue);
                      },
                    ),
                    const SizedBox(height: 3),
                    Text('${(value * 100).round()}%'),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Chương sau',
                onPressed: widget.onNext,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}