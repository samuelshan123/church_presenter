import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/server_service.dart';
import 'test_page.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../widgets/app_icon.dart';

class PresenterScreen extends StatefulWidget {
  final ServerService serverService;

  const PresenterScreen({super.key, required this.serverService});

  @override
  State<PresenterScreen> createState() => _PresenterScreenState();
}

class _PresenterScreenState extends State<PresenterScreen> {
  bool _showAllUrls = false;

  @override
  void initState() {
    super.initState();
    widget.serverService.addListener(_onServerStateChanged);
  }

  void _onServerStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.serverService.removeListener(_onServerStateChanged);
    // Don't dispose the service, it's global
    super.dispose();
  }

  Future<void> _toggleServer() async {
    if (widget.serverService.isRunning) {
      await widget.serverService.stopServer();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('🛑 Server stopped')));
      }
    } else {
      final success = await widget.serverService.startServer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✅ Server started on ${widget.serverService.serverUrl}'
                  : '❌ Failed to start server',
            ),
          ),
        );
      }
    }
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('📋 Copied: $url')));
  }

  /// The primary URL plus, behind an expander, any other addresses this device
  /// is listening on. Addresses arrive ranked best-first from ServerService.
  List<Widget> _buildUrlSection() {
    final urls = widget.serverService.serverUrlsWithLabels;
    if (urls.isEmpty) return const [];

    final primary = urls.first;
    final others = urls.skip(1).toList();

    return [
      _buildUrlTile(primary, isPrimary: true),
      if (others.isNotEmpty) ...[
        const SizedBox(height: 4),
        InkWell(
          onTap: () => setState(() => _showAllUrls = !_showAllUrls),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _showAllUrls
                      ? 'Hide other addresses'
                      : 'Other addresses (${others.length})',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                AppIcon(
                  _showAllUrls
                      ? HugeIcons.strokeRoundedArrowUp01
                      : HugeIcons.strokeRoundedArrowDown01,
                  size: 18,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
        if (_showAllUrls) ...others.map((i) => _buildUrlTile(i)),
      ],
    ];
  }

  Widget _buildUrlTile(
    ({String label, String url, bool isRecommended}) info, {
    bool isPrimary = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPrimary && info.isRecommended
                        ? '${info.label} · Recommended'
                        : info.label,
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  Text(
                    info.url,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _copyUrl(info.url),
              child: AppIcon(
                HugeIcons.strokeRoundedCopy01,
                size: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TestPage(serverService: widget.serverService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presenter'),
        elevation: 0,
        actions: [
          if (widget.serverService.isRunning)
            IconButton(
              icon: AppIcon(HugeIcons.strokeRoundedTestTube01),
              tooltip: 'Test Message',
              onPressed: _navigateToTest,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Server Status Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.serverService.isRunning
                        ? [Colors.green.shade400, Colors.teal.shade600]
                        : [Colors.grey.shade300, Colors.grey.shade400],
                  ),
                ),
                child: Column(
                  children: [
                    AppIcon(
                      widget.serverService.isRunning
                          ? HugeIcons.strokeRoundedWifiConnected01
                          : HugeIcons.strokeRoundedWifiDisconnected01,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.serverService.isRunning
                          ? 'Presenter Running'
                          : 'Presenter Offline',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.serverService.isRunning) ...[
                      const SizedBox(height: 8),
                      ..._buildUrlSection(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleServer,
                    icon: AppIcon(
                      widget.serverService.isRunning
                          ? HugeIcons.strokeRoundedStop
                          : HugeIcons.strokeRoundedPlay,
                    ),
                    label: Text(
                      widget.serverService.isRunning
                          ? 'Stop Presenter'
                          : 'Start Presenter',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: widget.serverService.isRunning
                          ? Colors.red
                          : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Information Cards
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIcon(
                          HugeIcons.strokeRoundedInformationCircle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'How to Use',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoItem(
                      '1.',
                      'Start the server by tapping "Start Server"',
                    ),
                    _buildInfoItem(
                      '2.',
                      'Copy the URL and open it in any browser',
                    ),
                    _buildInfoItem(
                      '3.',
                      'Use the Test button to send messages',
                    ),
                    _buildInfoItem(
                      '4.',
                      'Messages will appear on all connected devices',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Current Message Display
            if (widget.serverService.currentMessage != null) ...[
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppIcon(
                            HugeIcons.strokeRoundedMessage01,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Current Message',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.serverService.currentMessage!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              number,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
