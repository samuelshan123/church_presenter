import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/server_service.dart';

class TestPage extends StatefulWidget {
  final ServerService serverService;

  const TestPage({super.key, required this.serverService});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final TextEditingController _inputController = TextEditingController();
  String _lastSentMessage = '';

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      setState(() {
        _inputController.text = data!.text!;
      });
    }
  }

  void _sendMessage() {
    final msg = _inputController.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a message')));
      return;
    }

    widget.serverService.sendMessage(msg, 'text', {});
    setState(() {
      _lastSentMessage = msg;
      _inputController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Message sent successfully'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Message Sender'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Server Status Card
            Card(
              color: widget.serverService.isRunning
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      widget.serverService.isRunning
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 48,
                      color: widget.serverService.isRunning
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.serverService.isRunning
                          ? 'Server Running'
                          : 'Server Offline',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.serverService.isRunning) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.serverService.serverUrl,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Input Section
            Text(
              'Enter Your Message',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _inputController,
              decoration: InputDecoration(
                labelText: 'Message',
                hintText: 'Type your message here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.message),
              ),
              enabled: widget.serverService.isRunning,
              minLines: 3,
              maxLines: 8,
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.serverService.isRunning
                        ? _pasteFromClipboard
                        : null,
                    icon: const Icon(Icons.content_paste),
                    label: const Text('Paste'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: widget.serverService.isRunning
                        ? _sendMessage
                        : null,
                    icon: const Icon(Icons.send),
                    label: const Text('Send Message'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Last Sent Message
            if (_lastSentMessage.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Last Sent Message',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _lastSentMessage,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
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
}
