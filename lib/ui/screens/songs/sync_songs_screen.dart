import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'song_sync_controller.dart';

/// Entry point: wrap this widget with a [ChangeNotifierProvider] before
/// pushing it, or use [SongSyncPage.route()] which does that automatically.
class SongSyncPage extends StatelessWidget {
  const SongSyncPage({super.key});

  /// Convenience factory — returns a [MaterialPageRoute] that provides the
  /// controller locally so callers don't need a global provider setup.
  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => SongSyncController(),
          child: const SongSyncPage(),
        ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status card ──────────────────────────────────────────────
            _StatusCard(ctrl: ctrl),
            const SizedBox(height: 16),

            // ── Stats grid ───────────────────────────────────────────────
            if (ctrl.status != SyncStatus.idle) ...[
              _StatsGrid(stats: ctrl.stats),
              const SizedBox(height: 16),
            ],

            // ── Progress bar (while syncing) ─────────────────────────────
            if (ctrl.isSyncing &&
                ctrl.stats.totalBuckets > 0) ...[
              _BucketProgressBar(
                fetched: ctrl.stats.fetchedBuckets,
                total: ctrl.stats.totalBuckets,
              ),
              const SizedBox(height: 16),
            ],

            // ── Error box ────────────────────────────────────────────────
            if (ctrl.errorMessage != null) ...[
              _ErrorBox(message: ctrl.errorMessage!),
              const SizedBox(height: 16),
            ],

            // ── Success banner ───────────────────────────────────────────
            if (ctrl.status == SyncStatus.completed) ...[
              _SuccessBanner(
                insertedSongs: ctrl.stats.insertedSongs,
                localCount: ctrl.stats.localCount,
              ),
              const SizedBox(height: 16),
            ],

            // ── Last synced timestamp ────────────────────────────────────
            _LastSyncedRow(lastSyncedAt: ctrl.lastSyncedAt),
            const SizedBox(height: 24),

            // ── Sync button ───────────────────────────────────────────────
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            ctrl.isSyncing
                ? SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: cs.primary,
                    ),
                  )
                : Icon(_iconFor(ctrl.status), size: 28, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                ctrl.statusMessage,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
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

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: items
          .map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 6),
                    Text(
                      '${item.value}',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
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
                          ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Buckets downloaded',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text(
              '$fetched / $total',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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
    final d = dt.toLocal();
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$date at $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.history, size: 18),
        const SizedBox(width: 8),
        Text(
          lastSyncedAt == null
              ? 'Never synced'
              : 'Last synced: ${_format(lastSyncedAt!)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
