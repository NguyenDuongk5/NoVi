import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/session.dart';

class AuthorApplication {
  const AuthorApplication({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.status,
    required this.createdAt,
    this.message,
    this.decisionReason,
    this.reviewedAt,
  });

  factory AuthorApplication.from(Map<String, dynamic> json) =>
      AuthorApplication(
        id: s(json['applicationId']) ?? '',
        userId: s(json['userId']) ?? '',
        fullName: s(json['fullName']) ?? '',
        email: s(json['email']) ?? '',
        message: s(json['message']),
        status: i(json['status']),
        decisionReason: s(json['decisionReason']),
        createdAt: DateTime.tryParse(s(json['createdAt']) ?? ''),
        reviewedAt: DateTime.tryParse(s(json['reviewedAt']) ?? ''),
      );

  final String id, userId, fullName, email;
  final String? message, decisionReason;
  final int status;
  final DateTime? createdAt, reviewedAt;

  String get statusLabel => switch (status) {
    0 => 'Đang chờ duyệt',
    1 => 'Đã duyệt',
    2 => 'Đã từ chối',
    _ => 'Không xác định',
  };
}

class AuthorApplicationPage extends StatefulWidget {
  const AuthorApplicationPage({super.key, required this.session});
  final Session session;

  @override
  State<AuthorApplicationPage> createState() => _AuthorApplicationPageState();
}

class _AuthorApplicationPageState extends State<AuthorApplicationPage> {
  final message = TextEditingController();
  AuthorApplication? application;
  bool loading = true, submitting = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final raw = await widget.session.api.get(
        '/api/author-applications/me',
        auth: true,
      );
      final item = AuthorApplication.from(Map<String, dynamic>.from(raw));
      if (item.status == 1) await widget.session.refreshProfile();
      if (mounted) {
        setState(() {
          application = item;
          loading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        if (e.status == 404) {
          application = null;
        } else {
          error = e.message;
        }
      });
    }
  }

  Future<void> submit() async {
    if (submitting) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.session.api.post(
        '/api/author-applications',
        auth: true,
        body: {
          'message': message.text.trim().isEmpty ? null : message.text.trim(),
        },
      );
      message.clear();
      await load();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đăng ký làm tác giả')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (error != null) ...[
                  _ErrorCard(message: error!, onRetry: load),
                  const SizedBox(height: 16),
                ],
                if (application != null)
                  AuthorApplicationStatusCard(application: application!),
                if (application?.status == 1) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Quyền tài khoản đã được cập nhật. Hãy đăng xuất và đăng nhập lại để nhận JWT mới trước khi dùng API dành cho tác giả.',
                  ),
                ],
                if (application == null || application?.status == 2) ...[
                  const SizedBox(height: 20),
                  TextField(
                    key: const Key('author-application-message'),
                    controller: message,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Lời nhắn (không bắt buộc)',
                      hintText:
                          'Giới thiệu ngắn về mong muốn sáng tác của bạn…',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('author-application-submit'),
                    onPressed: submitting ? null : submit,
                    icon: submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      application?.status == 2 ? 'Gửi lại đơn' : 'Gửi đơn',
                    ),
                  ),
                ],
              ],
            ),
          ),
  );
}

class AuthorApplicationStatusCard extends StatelessWidget {
  const AuthorApplicationStatusCard({super.key, required this.application});
  final AuthorApplication application;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (application.status) {
      1 => Colors.green,
      2 => colors.error,
      _ => colors.primary,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge_outlined, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    application.statusLabel,
                    key: const Key('author-application-status'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (application.message?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(application.message!),
            ],
            if (application.decisionReason?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                'Lý do: ${application.decisionReason}',
                key: const Key('author-application-reason'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AdminAuthorApplicationsPage extends StatefulWidget {
  const AdminAuthorApplicationsPage({super.key, required this.session});
  final Session session;

  @override
  State<AdminAuthorApplicationsPage> createState() =>
      _AdminAuthorApplicationsPageState();
}

class _AdminAuthorApplicationsPageState
    extends State<AdminAuthorApplicationsPage> {
  List<AuthorApplication> items = const [];
  int page = 1, total = 0;
  static const pageSize = 10;
  bool loading = true;
  String? error;
  final processing = <String>{};
  final rejectionDrafts = <String, String>{};

  @override
  void initState() {
    super.initState();
    load();
  }

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
        '/api/admin/author-applications',
        query: {'page': '$requestedPage', 'pageSize': '$pageSize'},
        auth: true,
      );
      final raw = response['items'] as List;
      final totalItems = i(response['totalItems']);
      if (raw.isEmpty && requestedPage > 1) return load(requestedPage - 1);
      final result = raw
          .map((e) => AuthorApplication.from(Map<String, dynamic>.from(e)))
          .toList();
      if (mounted) {
        setState(() {
          items = result;
          loading = false;
          page = requestedPage;
          total = totalItems;
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

  Future<void> decide(AuthorApplication item, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _rejectionReason(
        context,
        initialValue: rejectionDrafts[item.id] ?? '',
      );
      if (reason == null) return;
      rejectionDrafts[item.id] = reason;
    }
    if (processing.contains(item.id)) return;
    setState(() => processing.add(item.id));
    try {
      await widget.session.api.post(
        '/api/admin/author-applications/${item.id}/decision',
        auth: true,
        body: {'approve': approve, 'reason': reason},
      );
      if (mounted) {
        rejectionDrafts.remove(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Đã duyệt yêu cầu.' : 'Đã từ chối yêu cầu.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        final text = e.status == 409
            ? 'Yêu cầu đã được người khác xử lý. Danh sách sẽ được tải lại.'
            : e.message;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
      }
    } finally {
      if (mounted) setState(() => processing.remove(item.id));
      final maxPage = total <= 1 ? 1 : ((total - 1) / pageSize).ceil();
      await load(page > maxPage ? maxPage : page);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yêu cầu tác giả')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? _ErrorCard(message: error!, onRetry: load)
        : RefreshIndicator(
            onRefresh: () => load(page),
            child: items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 220),
                      Center(child: Text('Không có yêu cầu đang chờ.')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      if (index == items.length) {
                        final pages = total == 0
                            ? 1
                            : (total / pageSize).ceil();
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: page > 1 ? () => load(page - 1) : null,
                              child: const Text('Trang trước'),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text('$page/$pages'),
                            ),
                            OutlinedButton(
                              onPressed: page < pages
                                  ? () => load(page + 1)
                                  : null,
                              child: const Text('Trang sau'),
                            ),
                          ],
                        );
                      }
                      final item = items[index];
                      final busy = processing.contains(item.id);
                      return Card(
                        key: Key('admin-author-application-${item.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.fullName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(item.email),
                              if (item.message?.isNotEmpty == true) ...[
                                const SizedBox(height: 10),
                                Text(item.message!),
                              ],
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton(
                                    key: Key('admin-author-reject-${item.id}'),
                                    onPressed: busy
                                        ? null
                                        : () => decide(item, false),
                                    child: const Text('Từ chối'),
                                  ),
                                  FilledButton(
                                    key: Key('admin-author-approve-${item.id}'),
                                    onPressed: busy
                                        ? null
                                        : () => decide(item, true),
                                    child: const Text('Duyệt'),
                                  ),
                                ],
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

Future<String?> _rejectionReason(
  BuildContext context, {
  String initialValue = '',
}) async {
  var reason = initialValue;
  final controller = TextEditingController(text: initialValue);
  String? validation;
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Lý do từ chối'),
        content: TextField(
          controller: controller,
          key: const Key('admin-author-rejection-reason'),
          onChanged: (value) => reason = value,
          maxLength: 1000,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(errorText: validation),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('admin-author-rejection-confirm'),
            onPressed: () {
              final value = reason.trim();
              if (value.isEmpty) {
                setState(() => validation = 'Vui lòng nhập lý do từ chối.');
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ),
  );
  return result;
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
