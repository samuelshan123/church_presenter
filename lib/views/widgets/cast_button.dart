import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../services/cast_service.dart';
import 'app_icon.dart';

/// App-bar Cast button: opens a picker of Chromecast / Google TV devices, or,
/// while casting, the option to stop. Hidden where casting isn't available
/// (desktop, or before a Cast receiver app ID is configured).
class CastButton extends StatelessWidget {
  const CastButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cast = context.watch<CastService>();
    if (!cast.isAvailable) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: cast.isConnected
          ? 'Casting to ${cast.deviceName ?? 'TV'}'
          : 'Cast to a TV',
      onPressed: () => showCastSheet(context),
      icon: cast.isConnecting
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : AppIcon(
              HugeIcons.strokeRoundedCast,
              color: cast.isConnected ? colorScheme.primary : null,
            ),
    );
  }
}

Future<void> showCastSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _CastSheet(),
  );
}

class _CastSheet extends StatefulWidget {
  const _CastSheet();

  @override
  State<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<_CastSheet> {
  @override
  void initState() {
    super.initState();
    // An active scan finds TVs faster while the picker is open.
    context.read<CastService>().startDiscovery();
  }

  @override
  Widget build(BuildContext context) {
    final cast = context.watch<CastService>();
    final theme = Theme.of(context);

    // Scrolls when space is tight (a tablet in landscape), instead of
    // overflowing.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: cast.isConnected
            ? _buildConnected(context, cast, theme)
            : _buildPicker(context, cast, theme),
      ),
    );
  }

  Widget _buildConnected(
    BuildContext context,
    CastService cast,
    ThemeData theme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIcon(
              HugeIcons.strokeRoundedCast,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Casting to ${cast.deviceName ?? 'TV'}',
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Everything you present also appears on this TV.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.tonalIcon(
          onPressed: () {
            cast.disconnect();
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: AppIcon(HugeIcons.strokeRoundedCancel01),
          label: const Text('Stop casting'),
        ),
      ],
    );
  }

  Widget _buildPicker(BuildContext context, CastService cast, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Cast to a TV', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Chromecast and Google TV devices on this Wi-Fi',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<GoogleCastDevice>>(
          stream: cast.devicesStream,
          initialData: cast.devices,
          builder: (context, snapshot) {
            final devices = snapshot.data ?? const [];
            if (devices.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Looking for TVs…\n'
                      'Make sure the phone and the TV are on the same Wi-Fi.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final device in devices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AppIcon(
                      HugeIcons.strokeRoundedTv01,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(device.friendlyName),
                    subtitle: device.modelName != null
                        ? Text(device.modelName!)
                        : null,
                    onTap: () {
                      cast.connect(device);
                      Navigator.pop(context);
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
