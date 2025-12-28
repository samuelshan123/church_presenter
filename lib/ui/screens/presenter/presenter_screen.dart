import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/server_service.dart';
import 'test_page.dart';

class PresenterScreen extends StatefulWidget {
  final ServerService serverService;

  const PresenterScreen({super.key, required this.serverService});

  @override
  State<PresenterScreen> createState() => _PresenterScreenState();
}

class _PresenterScreenState extends State<PresenterScreen> {
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

  void _copyUrl() {
    if (widget.serverService.deviceIp != null) {
      Clipboard.setData(ClipboardData(text: widget.serverService.serverUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📋 URL copied to clipboard')),
      );
    }
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
              icon: const Icon(Icons.science),
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
                padding: const EdgeInsets.all(24),
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
                    Icon(
                      widget.serverService.isRunning
                          ? Icons.wifi_tethering
                          : Icons.wifi_off,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.serverService.serverUrl,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
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
                    icon: Icon(
                      widget.serverService.isRunning
                          ? Icons.stop
                          : Icons.play_arrow,
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
                if (widget.serverService.isRunning) ...[
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _copyUrl,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.copy),
                  ),
                ],
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
                        Icon(
                          Icons.info_outline,
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
                          Icon(
                            Icons.message,
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
