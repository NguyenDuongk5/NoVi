import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/session.dart';

const reportReasons = <int, String>{
  1: 'Nội dung không phù hợp',
  2: 'Vi phạm bản quyền',
  3: 'Thông tin sai lệch',
  4: 'Spam hoặc quảng cáo',
  5: 'Lý do khác',
};

Future<bool?> showContentReportDialog(
  BuildContext context, {
  required Session session,
  required int targetType,
  required String targetId,
  required String targetTitle,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ContentReportDialog(
    session: session,
    targetType: targetType,
    targetId: targetId,
    targetTitle: targetTitle,
  ),
);

class _ContentReportDialog extends StatefulWidget {
  const _ContentReportDialog({
    required this.session,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
  });
  final Session session;
  final int targetType;
  final String targetId;
  final String targetTitle;

  @override
  State<_ContentReportDialog> createState() => _ContentReportDialogState();
}

class _ContentReportDialogState extends State<_ContentReportDialog> {
  final description = TextEditingController();
  int? reason;
  String? error;
  bool submitting = false;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (submitting) return;
    if (reason == null) {
      setState(() => error = 'Vui lòng chọn lý do báo cáo.');
      return;
    }
    setState(() { submitting = true; error = null; });
    try {
      await widget.session.api.post(
        '/api/content-reports',
        auth: true,
        body: {
          'targetType': widget.targetType,
          'targetId': widget.targetId,
          'reason': reason,
          'description': description.text.trim().isEmpty
              ? null
              : description.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) {
        setState(() {
          submitting = false;
          error = exception is ApiException
              ? exception.message
              : 'Không thể gửi báo cáo. Vui lòng thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Báo cáo nội dung'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.targetTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: const Key('report-reason'),
            initialValue: reason,
            decoration: const InputDecoration(labelText: 'Lý do *'),
            items: reportReasons.entries
                .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                .toList(),
            onChanged: submitting ? null : (value) => setState(() { reason = value; error = null; }),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('report-description'),
            controller: description,
            enabled: !submitting,
            maxLength: 1000,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Mô tả thêm (không bắt buộc)',
              alignLabelWithHint: true,
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(error!, key: const Key('report-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: submitting ? null : () => Navigator.pop(context, false), child: const Text('Hủy')),
      FilledButton(
        key: const Key('submit-report'),
        onPressed: submitting ? null : submit,
        child: submitting
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Gửi báo cáo'),
      ),
    ],
  );
}
