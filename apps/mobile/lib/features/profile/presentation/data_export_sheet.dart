import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/contact.dart';
import '../../../core/design/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/data_export.dart';

/// Profile > Privacy & data > "Download my data" (FR-SET-02, T-CMP-03,
/// D-82): asks the server for a copy, shows that it is being prepared, then
/// offers the download (kept 7 days), or a retry when it failed. One
/// primary action at a time (spec 4.1).
Future<void> showDataExport(BuildContext context, {required String uid}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(child: _DataExportSheet(uid: uid)),
    );

class _DataExportSheet extends ConsumerStatefulWidget {
  const _DataExportSheet({required this.uid});

  final String uid;

  @override
  ConsumerState<_DataExportSheet> createState() => _State();
}

class _State extends ConsumerState<_DataExportSheet> {
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<void> Function(AppLocalizations l) action) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action(l);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() => _run((l) async {
    try {
      await ref.read(dataExportsProvider).request();
    } on DataExportLimited catch (e) {
      final after = e.retryAfter;
      _message = after == null
          ? l.dataExportLimited
          : l.dataExportLimitedUntil(_when(after, time: true));
    } catch (_) {
      _message = l.dataExportStartFailed;
    }
  });

  Future<void> _download(DataExportJob job) => _run((l) async {
    try {
      final uri = await ref.read(dataExportsProvider).downloadLink(job.id);
      if (!await ref.read(dataExportOpenerProvider)(uri)) {
        _message = l.dataExportLinkFailed;
      }
    } catch (_) {
      _message = l.dataExportLinkFailed;
    }
  });

  /// The old by-email request, kept as a fallback when an address is set
  /// for the build (D-56).
  Future<void> _email() => _run((l) async {
    final uri = Uri(
      scheme: 'mailto',
      path: dataRequestEmail,
      queryParameters: {
        'subject': l.profileRequestDataSubject,
        'body': l.profileRequestDataBody(widget.uid),
      },
    );
    if (!await ref.read(dataExportOpenerProvider)(uri)) {
      _message = l.profileRequestDataNoMail;
    }
  });

  String _when(DateTime d, {bool time = false}) {
    final m = MaterialLocalizations.of(context);
    final local = d.toLocal();
    final day = m.formatMediumDate(local);
    return time
        ? '$day, ${m.formatTimeOfDay(TimeOfDay.fromDateTime(local))}'
        : day;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final latest = ref.watch(latestDataExportProvider);
    final job = latest.value;

    Widget primary(String key, String label, VoidCallback onPressed) =>
        FilledButton(
          key: Key(key),
          onPressed: _busy ? null : onPressed,
          child: Text(label),
        );

    final (String body, List<Widget> actions) = switch (latest) {
      AsyncLoading() when job == null => (
        l.dataExportIntro,
        const [Center(child: CircularProgressIndicator())],
      ),
      AsyncError() => (
        l.dataExportIntro,
        [primary('data-export-start', l.dataExportStart, _request)],
      ),
      _ => switch (job?.status) {
        DataExportStatus.preparing => (
          l.dataExportPreparing,
          [
            const Center(
              child: CircularProgressIndicator(
                key: Key('data-export-preparing'),
              ),
            ),
          ],
        ),
        DataExportStatus.ready => (
          l.dataExportReady(_when(job!.expiresAt!)),
          [
            primary(
              'data-export-download',
              l.dataExportDownload,
              () => _download(job),
            ),
          ],
        ),
        DataExportStatus.failed => (
          l.dataExportFailed,
          [
            primary('data-export-retry', l.dataExportRetry, _request),
            if (dataRequestEmail.isNotEmpty)
              TextButton(
                key: const Key('data-export-email'),
                onPressed: _busy ? null : _email,
                child: Text(l.dataExportEmailInstead),
              ),
          ],
        ),
        // None yet, or the last one expired.
        _ => (
          l.dataExportIntro,
          [primary('data-export-start', l.dataExportStart, _request)],
        ),
      },
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LwSpacing.lg,
        0,
        LwSpacing.lg,
        LwSpacing.lg,
      ),
      child: Column(
        key: const Key('data-export-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l.dataExportTitle, style: t.titleLarge),
          ),
          const SizedBox(height: LwSpacing.sm),
          Text(body, style: t.bodyLarge),
          const SizedBox(height: LwSpacing.xs),
          Text(l.dataExportPrivacyNote, style: t.bodyMedium),
          if (_message != null) ...[
            const SizedBox(height: LwSpacing.sm),
            Text(
              _message!,
              key: const Key('data-export-message'),
              style: t.bodyMedium,
            ),
          ],
          const SizedBox(height: LwSpacing.lg),
          ...actions,
        ],
      ),
    );
  }
}
