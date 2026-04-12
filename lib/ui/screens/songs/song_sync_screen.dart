import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/song_sync_controller.dart';

/// Push via [SongSyncScreen.route()]. The controller is provided globally from
/// main.dart so it survives back-navigation and ongoing syncs don't crash.
class SongSyncScreen extends StatelessWidget {
  const SongSyncScreen({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const SongSyncScreen(),
      );

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
      appBar: AppBar(
        title: const Text('Sync Songs'),
        centerTitle: true,
      ),
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
                ctrl.stats.localCount > 0) ...[
              _StatsGrid(stats: ctrl.stats),
              SizedBox(height: vSpc),
            ],

            // ── Progress bar (while syncing) ─────────────────────────────
            if (ctrl.isSyncing &&
                ctrl.stats.totalBuckets > 0) ...[
              _BucketProgressBar(
                fetched: ctrl.stats.fetchedBuckets,
                total: ctrl.stats.totalBuckets,
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
                    : const Icon(Icons.cancel_outlined),
                label: Text(
                    ctrl.cancelRequested ? 'Cancelling…' : 'Cancel Sync'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
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
                  : const Icon(Icons.sync),
              label: Text(ctrl.isSyncing ? 'Syncing…' : 'Sync Songs'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
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

  IconData _iconFor(SyncStatus s) {
    switch (s) {
      case SyncStatus.idle:
        return Icons.cloud_sync_outlined;
      case SyncStatus.completed:
        return Icons.check_circle_outline;
      case SyncStatus.failed:
        return Icons.error_outline;
      default:
        return Icons.sync;
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
    final cs = Theme.of(context).colorScheme;
    final color = _colorFor(ctrl.status, cs);
    final w = MediaQuery.of(context).size.width;
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
                : Icon(_iconFor(ctrl.status), size: iconSz, color: color),
            SizedBox(width: w < 360 ? 10 : 16),
            Expanded(
              child: Text(
                ctrl.statusMessage,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final SyncStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('Remote Songs', stats.totalRemote, Icons.cloud_outlined),
      _StatItem('Local Songs', stats.localCount, Icons.storage_outlined),
      _StatItem('Missing', stats.missingCount, Icons.download_outlined),
      _StatItem('Total Buckets', stats.totalBuckets, Icons.folder_outlined),
      _StatItem('Fetched Buckets', stats.fetchedBuckets, Icons.folder_open),
      _StatItem('Inserted', stats.insertedSongs, Icons.playlist_add),
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
                padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon,
                        size: iconSz,
                        color: Theme.of(context).colorScheme.primary),
                    SizedBox(height: w < 360 ? 4 : 6),
                    Text(
                      '${item.value}',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: valSz,
                              ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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
  const _StatItem(this.label, this.value, this.icon);
  final String label;
  final int value;
  final IconData icon;
}

class _BucketProgressBar extends StatelessWidget {
  const _BucketProgressBar({required this.fetched, required this.total});
  final int fetched;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : fetched / total;
    final w = MediaQuery.of(context).size.width;
    final double lblSz = w < 360 ? 10 : (w > 600 ? 14 : 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Buckets downloaded',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: lblSz),
            ),
            Text(
              '$fetched / $total',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold, fontSize: lblSz),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
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
          Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer),
            ),
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
  });
  final int insertedSongs;
  final int localCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insertedSongs > 0
                  ? 'Added $insertedSongs new songs. $localCount songs stored locally.'
                  : 'All songs are up to date. $localCount songs stored locally.',
              style: TextStyle(color: Colors.green.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LastSyncedRow extends StatelessWidget {
  const _LastSyncedRow({required this.lastSyncedAt});
  final DateTime? lastSyncedAt;

  String _format(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final diff = today.difference(date).inDays;

    final hour = local.hour;
    final min = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = (hour % 12 == 0 ? 12 : hour % 12);
    final timeStr = '$h:$min $period';

    if (diff == 0) return 'Today at $timeStr';
    if (diff == 1) return 'Yesterday at $timeStr';
    if (diff < 7) return '$diff days ago at $timeStr';
    final d =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    return '$d at $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double sz = w < 360 ? 10 : (w > 600 ? 14 : 12);
    final double iconSz = w < 360 ? 15 : 18;
    return Row(
      children: [
        Icon(Icons.history, size: iconSz),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            lastSyncedAt == null
                ? 'Never synced'
                : 'Last synced: ${_format(lastSyncedAt!)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: sz,
                ),
          ),
        ),
      ],
    );
  }
}
