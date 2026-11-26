import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ReaderSettingsPage extends StatefulWidget {
  const ReaderSettingsPage({super.key, this.tts});

  final FlutterTts? tts;

  @override
  State<ReaderSettingsPage> createState() => _ReaderSettingsPageState();
}

class _ReaderSettingsPageState extends State<ReaderSettingsPage> {
  double fontSize = 18;
  double lineSpacing = 4;
  double voiceSpeed = 33;
  double voicePitch = 33;
  double autoScrollSpeed = 25;
  double autoFlipSeconds = 29;

  int background = 0;
  int stopAfterMinutes = 30;

  String fontFamily = 'serif';
  String voice = 'vi-VN-language';
  String readingMode = 'Kết hợp';
  String playbackMode = 'Phát trong ứng dụng';

  bool twoSidedMargins = true;
  bool autoNextChapter = true;
  bool autoScrollOnOpen = false;

static const List<String> fontFamilies = [
  'serif',
  'sans',
  'italic',
];
late final FlutterTts _tts = widget.tts ?? FlutterTts();
List<Map<String, String>> availableVoices = [];





  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

 Future<void> _loadSettings() async {
  final prefs = await SharedPreferences.getInstance();

  final deviceVoices = <Map<String, String>>[];
  try {
        dynamic rawVoices;
    for (var i = 0; i < 8; i++) {
      rawVoices = await _tts.getVoices;
      if (rawVoices is List && rawVoices.isNotEmpty) break;
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (rawVoices is List) {
      for (final item in rawVoices) {
        if (item is! Map) continue;

        final locale = (item['locale']?.toString() ?? '')
            .replaceAll('_', '-')
            .toLowerCase();

        final name = item['name']?.toString() ?? '';
        if (!locale.startsWith('vi') || name.isEmpty) continue;

        deviceVoices.add(
          item.map(
            (key, value) => MapEntry(
              key.toString(),
              value.toString(),
            ),
          ),
        );
      }
    }
  } catch (_) {
    // Nếu thiết bị không trả danh sách giọng, dùng giọng Việt mặc định.
  }

  if (!mounted) return;

  setState(() {
    availableVoices = deviceVoices;

    fontSize = prefs.getDouble('reader_font') ?? 18;
    background = prefs.getInt('reader_bg') ?? 0;
    lineSpacing = prefs.getDouble('reader_line_spacing') ?? 4;
    voiceSpeed = prefs.getDouble('reader_voice_speed') ?? 33;
    voicePitch = prefs.getDouble('reader_voice_pitch') ?? 33;
    autoScrollSpeed = prefs.getDouble('reader_auto_scroll_speed') ?? 25;
    autoFlipSeconds = prefs.getDouble('reader_auto_flip_seconds') ?? 29;
    stopAfterMinutes = prefs.getInt('reader_stop_after') ?? 30;

final savedFont = prefs.getString('reader_font_family') ?? 'serif';
fontFamily = const ['serif', 'sans', 'italic'].contains(savedFont)
    ? savedFont
    : 'serif';
    twoSidedMargins =
        prefs.getBool('reader_two_sided_margins') ?? true;
    autoNextChapter = prefs.getBool('reader_auto_next') ?? true;
    autoScrollOnOpen =
        prefs.getBool('reader_auto_scroll_open') ?? false;
    
    readingMode = prefs.getString('reader_mode') ?? 'Kết hợp';
playbackMode =
    prefs.getString('reader_playback_mode') ?? 'Phát trong ứng dụng';

    final savedVoice = prefs.getString('reader_voice') ?? '';
    final voiceExists = deviceVoices.any(
      (item) => item['name'] == savedVoice,
    );

    voice = voiceExists
        ? savedVoice
        : deviceVoices.isNotEmpty
            ? deviceVoices.first['name'] ?? ''
            : '';
  });
}

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('reader_font', fontSize);
    await prefs.setInt('reader_bg', background);
    await prefs.setDouble('reader_line_spacing', lineSpacing);
    await prefs.setDouble('reader_voice_speed', voiceSpeed);
    await prefs.setDouble('reader_voice_pitch', voicePitch);
    await prefs.setDouble('reader_auto_scroll_speed', autoScrollSpeed);
    await prefs.setDouble('reader_auto_flip_seconds', autoFlipSeconds);
    await prefs.setInt('reader_stop_after', stopAfterMinutes);

    await prefs.setString('reader_font_family', fontFamily);
    await prefs.setString('reader_voice', voice);
    await prefs.setString('reader_mode', readingMode);
    await prefs.setString('reader_playback_mode', playbackMode);

    await prefs.setBool('reader_two_sided_margins', twoSidedMargins);
    await prefs.setBool('reader_auto_next', autoNextChapter);
    await prefs.setBool('reader_auto_scroll_open', autoScrollOnOpen);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }

  Widget _choices<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: values.map((value) {
        return ChoiceChip(
          label: Text(label(value)),
          selected: value == selected,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          labelPadding: const EdgeInsets.symmetric(horizontal: 7),
          labelStyle: const TextStyle(fontSize: 13),
          onSelected: (_) => setState(() => onSelected(value)),
        );
      }).toList(),
    );
  }

  Widget _sliderRow({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String Function(double)? valueLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        Row(
          children: [
            SizedBox(
              width: 38,
              child: Text(
                valueLabel?.call(value) ?? value.round().toString(),
              ),
            ),
            Expanded(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: (newValue) {
                  setState(() => onChanged(newValue));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt đọc truyện'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    _sliderRow(
                      title: 'Cỡ chữ',
                      value: fontSize,
                      min: 12,
                      max: 36,
                      divisions: 12,
                      onChanged: (value) => fontSize = value,
                      valueLabel: (value) => value.round().toString(),
                    ),

                    _sectionTitle('Kiểu chữ'),
                    _choices<String>(
  values: fontFamilies,
  selected: fontFamily,
  label: (value) => value == 'serif'
    ? 'Có chân'
    : value == 'sans'
        ? 'Không chân'
        : 'Nghiêng',
  onSelected: (value) => fontFamily = value,
),

                    _sliderRow(
                      title: 'Khoảng cách dòng',
                      value: lineSpacing,
                      min: 1,
                      max: 9,
                      divisions: 8,
                      onChanged: (value) => lineSpacing = value,
                      valueLabel: (value) => value.round().toString(),
                    ),

                    _sectionTitle('Canh lề nội dung'),
                    _choices<bool>(
                      values: const [false, true],
                      selected: twoSidedMargins,
                      label: (value) => value ? 'Hai bên' : 'Mặc định',
                      onSelected: (value) => twoSidedMargins = value,
                    ),

                    _sectionTitle('Màu nền'),
                    _choices<int>(
                      values: const [0, 1, 2],
                      selected: background,
                      label: (value) => ['Sáng', 'Vàng', 'Tối'][value],
                      onSelected: (value) => background = value,
                    ),

                    _sectionTitle('Kiểu đọc'),
                    _choices<String>(
                      values: const ['Cuộn đọc', 'Lật trang', 'Kết hợp'],
                      selected: readingMode,
                      label: (value) => value,
                      onSelected: (value) => readingMode = value,
                    ),

                    _sectionTitle('Tự động cuộn khi mở chương'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bật tự động cuộn'),
                      value: autoScrollOnOpen,
                      onChanged: (value) {
                        setState(() => autoScrollOnOpen = value);
                      },
                    ),

                    _sliderRow(
                      title: 'Tốc độ tự động cuộn',
                      value: autoScrollSpeed,
                      min: 1,
                      max: 100,
                      divisions: 99,
                      onChanged: (value) => autoScrollSpeed = value,
                    ),

                    _sliderRow(
                      title: 'Thời gian tự động lật trang (giây)',
                      value: autoFlipSeconds,
                      min: 1,
                      max: 60,
                      divisions: 59,
                      onChanged: (value) => autoFlipSeconds = value,
                    ),

                    _sectionTitle('Chọn giọng đọc'),
                    if (availableVoices.isEmpty)
  const Text(
    'Thiết bị chưa tìm thấy giọng tiếng Việt. '
    'Hãy cài giọng tiếng Việt trong cài đặt đọc văn bản của thiết bị.',
  )
else
  DropdownButtonFormField<String>(
    value: voice.isEmpty ? null : voice,
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      hintText: 'Chọn giọng tiếng Việt',
      isDense: true,
    ),
    items: availableVoices.map((item) {
      final name = item['name']!;
      return DropdownMenuItem(
        value: name,
        child: Text(name, overflow: TextOverflow.ellipsis),
      );
    }).toList(),
    onChanged: (value) {
      if (value != null) setState(() => voice = value);
    },
  ),

                    _sliderRow(
                      title: 'Tốc độ giọng đọc',
                      value: voiceSpeed,
                      min: 1,
                      max: 100,
                      divisions: 99,
                      onChanged: (value) => voiceSpeed = value,
                    ),

                    _sliderRow(
                      title: 'Mức độ giọng đọc',
                      value: voicePitch,
                      min: 1,
                      max: 100,
                      divisions: 99,
                      onChanged: (value) => voicePitch = value,
                    ),

                    _sectionTitle('Tự chuyển chương khi nghe'),
                    _choices<bool>(
                      values: const [false, true],
                      selected: autoNextChapter,
                      label: (value) => value ? 'Bật' : 'Không',
                      onSelected: (value) => autoNextChapter = value,
                    ),

                    _sectionTitle('Tự động dừng đọc sau'),
                    _choices<int>(
                      values: const [0, 5, 10, 15, 30, 45, 60],
                      selected: stopAfterMinutes,
                      label: (value) => value == 0 ? 'Tắt' : '${value}p',
                      onSelected: (value) => stopAfterMinutes = value,
                    ),

                    _sectionTitle('Cách phát giọng đọc'),
                    _choices<String>(
                      values: const [
                        'Phát trong ứng dụng',
                        'Google TTS',
                      ],
                      selected: playbackMode,
                      label: (value) => value,
                      onSelected: (value) => playbackMode = value,
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _saveSettings,
          child: const Text('Lưu cài đặt'),
        ),
      ),
    );
  }
}