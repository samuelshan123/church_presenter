import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../controllers/song_sync_controller.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/app_icon.dart';

/// Push via [SongSyncScreen.route()]. The controller is provided globally from
/// main.dart so it survives back-navigation and ongoing syncs don't crash.
class SongSyncScreen extends StatelessWidget {
  const SongSyncScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SongSyncScreen());

  @override
  Widget build(BuildContext context) {
    return const _SongSyncView();
  }
}

// ---------------------------------------------------------------------------
// Internal stateful view (owns initState lifecycle)
// ---------------------------------------------------------------------------

class _SongSyncView extends StatefulWidget {
  const _SongSyncView();

  @override
  State<_SongSyncView> createState() => _SongSyncViewState();
}

class _SongSyncViewState extends State<_SongSyncView> {
  @override
  void initState() {
    super.initState();
    // Load persisted state (last-synced timestamp, local count) after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SongSyncController>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SongSyncController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sync Songs'), centerTitle: true),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final hPad = w < 360 ? 12.0 : 20.0;
          final vSpc = w < 360 ? 12.0 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Status card ──────────────────────────────────────────────
                _StatusCard(ctrl: ctrl),
                SizedBox(height: vSpc),

                // ── Stats grid ───────────────────────────────────────────────
                if (ctrl.status != SyncStatus.idle ||
                    ctrl.stats.localCount > 0 ||
                    ctrl.stats.totalRemote > 0) ...[
                  _StatsGrid(
                    stats: ctrl.stats,
                    // Bucket/inserted figures only mean something during a run,
                    // and just after one while the success banner is up.
                    showSyncDetails:
                        ctrl.isSyncing || ctrl.status == SyncStatus.completed,
                  ),
                  SizedBox(height: vSpc),
                ],

                // ── Progress bar (while syncing) ─────────────────────────────
                if (ctrl.isSyncing) ...[
                  if (ctrl.stats.totalBuckets > 0)
                    _BucketProgressBar(
                      fetched: ctrl.stats.fetchedBuckets,
                      total: ctrl.stats.totalBuckets,
                    )
                  else
                    // Steps 1–4 have no bucket count yet, but can take a while on a
                    // cold sync — show motion so the page doesn't look stalled.
                    const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                      child: LinearProgressIndicator(minHeight: 8),
                    ),
                  SizedBox(height: vSpc),
                ],

                // ── Error box ────────────────────────────────────────────────
                if (ctrl.errorMessage != null) ...[
                  _ErrorBox(message: ctrl.errorMessage!),
                  SizedBox(height: vSpc),
                ],

                // ── Success banner ───────────────────────────────────────────
                if (ctrl.status == SyncStatus.completed) ...[
                  _SuccessBanner(
                    insertedSongs: ctrl.stats.insertedSongs,
                    localCount: ctrl.stats.localCount,
                    missingCount: ctrl.stats.missingCount,
                  ),
                  SizedBox(height: vSpc),
                ],

                // ── Last synced timestamp ────────────────────────────────────
                _LastSyncedRow(lastSyncedAt: ctrl.lastSyncedAt),
                const SizedBox(height: 24),

                // ── Sync / Cancel buttons ─────────────────────────────────────
                if (ctrl.isSyncing)
                  OutlinedButton.icon(
                    onPressed: ctrl.cancelRequested ? null : ctrl.cancelSync,
                    icon: ctrl.cancelRequested
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : AppIcon(HugeIcons.strokeRoundedCancelCircle),
                    label: Text(
                      ctrl.cancelRequested ? 'Cancelling…' : 'Cancel Sync',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: ctrl.isSyncing ? null : ctrl.syncSongs,
                  icon: ctrl.isSyncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : AppIcon(HugeIcons.strokeRoundedRefresh04),
                  label: Text(ctrl.isSyncing ? 'Syncing…' : 'Sync Songs'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: colorScheme.primary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.ctrl});
  final SongSyncController ctrl;

  HugeIconData _iconFor(SyncStatus s) {
    switch (s) {
      case SyncStatus.idle:
        return HugeIcons.strokeRoundedCloudDownload;
      case SyncStatus.completed:
        return HugeIcons.strokeRoundedCheckmarkCircle01;
      case SyncStatus.failed:
        return HugeIcons.strokeRoundedAlertCircle;
      default:
        return HugeIcons.strokeRoundedRefresh04;
    }
  }

  Color _colorFor(SyncStatus s, ColorScheme cs) {
    switch (s) {
      case SyncStatus.completed:
        return Colors.green;
      case SyncStatus.failed:
        return cs.error;
      case SyncStatus.idle:
        return cs.onSurfaceVariant;
      default:
        return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _colorFor(ctrl.status, cs);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final double iconSz = w < 360 ? 22 : 28;
        final double textSz = w < 360 ? 13 : (w > 600 ? 17 : 15);
        final double pad = w < 360 ? 14 : 20;

        return Card(
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Row(
              children: [
                ctrl.isSyncing
                    ? SizedBox.square(
                        dimension: iconSz,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: cs.primary,
                        ),
                      )
                    : AppIcon(
                        _iconFor(ctrl.status),
                        size: iconSz,
                        color: color,
                      ),
                SizedBox(width: w < 360 ? 10 : 16),
                Expanded(
                  child: Text(
                    ctrl.statusMessage,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                      fontSize: textSz,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, this.showSyncDetails = false});
  final SyncStats stats;

  /// Whether to include the bucket/inserted tiles. These describe an in-flight
  /// run, so they're only meaningful while a sync is actually going.
  final bool showSyncDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final items = [
      _StatItem(
        'Saved Songs',
        stats.localCount,
        HugeIcons.strokeRoundedDatabase02,
      ),
      _StatItem(
        'Remote Songs',
        stats.totalRemote,
        HugeIcons.strokeRoundedCloud,
      ),

      // Highlighted when songs are still outstanding — this is the number the
      // user comes back to the page to check.
      _StatItem(
        'Missing',
        stats.missingCount,
        HugeIcons.strokeRoundedDownload04,
        color: stats.missingCount > 0 ? cs.error : null,
      ),
      if (showSyncDetails) ...[
        _StatItem(
          'Total Buckets',
          stats.totalBuckets,
          HugeIcons.strokeRoundedFolder01,
        ),
        _StatItem(
          'Fetched Buckets',
          stats.fetchedBuckets,
          HugeIcons.strokeRoundedFolder02,
        ),
        _StatItem(
          'Inserted',
          stats.insertedSongs,
          HugeIcons.strokeRoundedPlayListAdd,
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w < 340 ? 2 : 3;
        final ratio = w < 340 ? 1.5 : (w > 600 ? 1.0 : 1.15);
        final double iconSz = w < 360 ? 16 : (w > 600 ? 26 : 20);
        final double valSz = w < 360 ? 13 : (w > 600 ? 19 : 15);
        final double lblSz = w < 360 ? 9 : (w > 600 ? 13 : 11);
        final double vPad = w < 360 ? 8 : 12;
        final double hPad = w < 360 ? 4 : 8;
        return GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: cols,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: ratio,
          children: items
              .map(
                (item) => Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: vPad,
                      horizontal: hPad,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(
                          item.icon,
                          size: iconSz,
                          color: item.color ?? cs.primary,
                        ),
                        SizedBox(height: w < 360 ? 4 : 6),
                        Text(
                          '${item.value}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: valSz,
                            color: item.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: lblSz,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatItem {
  const _StatItem(this.label, this.value, this.icon, {this.color});
  final String label;
  final int value;
  final HugeIconData icon;

  /// Overrides the icon/value tint. Null falls back to the theme primary.
  final Color? color;
}

class _BucketProgressBar extends StatelessWidget {
  const _BucketProgressBar({required this.fetched, required this.total});
  final int fetched;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : fetched / total;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final double lblSz = w < 360 ? 10 : (w > 600 ? 14 : 12);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Buckets downloaded',
                  style: theme.textTheme.labelMedium?.copyWith(fontSize: lblSz),
                ),
                Text(
                  '$fetched / $total',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: lblSz,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(HugeIcons.strokeRoundedAlert02, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: cs.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({
    required this.insertedSongs,
    required this.localCount,
    required this.missingCount,
  });
  final int insertedSongs;
  final int localCount;
  final int missingCount;

  @override
  Widget build(BuildContext context) {
    // Songs can remain missing when individual batches failed to download, so
    // don't claim everything is up to date unless it actually is.
    final partial = missingCount > 0;
    final base = Colors.green;
    final accent = partial ? Colors.orange : base;

    final String message;
    if (partial) {
      message =
          'Added $insertedSongs songs. $missingCount still missing — '
          'sync again to retry.';
    } else if (insertedSongs > 0) {
      message =
          'Added $insertedSongs new songs. $localCount songs stored locally.';
    } else {
      message = 'All songs are up to date. $localCount songs stored locally.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.shade200),
      ),
      child: Row(
        children: [
          AppIcon(
            partial
                ? HugeIcons.strokeRoundedInformationCircle
                : HugeIcons.strokeRoundedCheckmarkCircle02,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: accent.shade800)),
          ),
        ],
      ),
    );
  }
}

/// Shows the last-synced time as relative text. Ticks once a minute so
/// "Just now" ages into "3 minutes ago" without needing a controller update.
class _LastSyncedRow extends StatefulWidget {
  const _LastSyncedRow({required this.lastSyncedAt});
  final DateTime? lastSyncedAt;

  @override
  State<_LastSyncedRow> createState() => _LastSyncedRowState();
}

class _LastSyncedRowState extends State<_LastSyncedRow> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  DateTime? get lastSyncedAt => widget.lastSyncedAt;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// 12-hour clock time, e.g. `3:47 PM`.
  String _time(DateTime local) {
    final min = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$h:$min $period';
  }

  String _format(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final elapsed = now.difference(local);

    // Very recent syncs read better as elapsed time than as a clock time.
    if (elapsed.inSeconds < 60) return 'Just now';
    if (elapsed.inMinutes < 60) {
      final m = elapsed.inMinutes;
      return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
    }

    // Compare by calendar day so an 11pm→1am sync reads "Yesterday", not
    // "2 hours ago on the same day".
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final days = today.difference(date).inDays;

    if (days == 0) return 'Today at ${_time(local)}';
    if (days == 1) return 'Yesterday at ${_time(local)}';
    if (days < 7) return '$days days ago at ${_time(local)}';

    final month = _months[local.month - 1];
    // Drop the year for dates inside the current year — it's just noise.
    final year = local.year == now.year ? '' : ' ${local.year}';
    return '${local.day} $month$year at ${_time(local)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final double sz = w < 360 ? 10 : (w > 600 ? 14 : 12);
        final double iconSz = w < 360 ? 15 : 18;
        return Row(
          children: [
            AppIcon(HugeIcons.strokeRoundedClock01, size: iconSz),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lastSyncedAt == null
                    ? 'Never synced'
                    : 'Last synced: ${_format(lastSyncedAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: sz,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
