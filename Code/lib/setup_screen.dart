import 'package:flutter/material.dart';

import 'config.dart';
import 'llm_service.dart';

/// Shown until the model is on the device and loaded.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.llm});

  final LlmService llm;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    switch (llm.status) {
      case LlmStatus.needsDownload:
        content = _Info(
          icon: Icons.download_for_offline_outlined,
          title: 'Download the AI model',
          text: 'One-time download (${AppConfig.modelSizeLabel}, Wi-Fi '
              'recommended). After that the chatbot works completely offline.',
          action: FilledButton.icon(
            onPressed: llm.download,
            icon: const Icon(Icons.download),
            label: const Text('Download'),
          ),
        );
      case LlmStatus.downloading:
        content = _Info(
          icon: Icons.downloading,
          title: 'Downloading model...',
          text: '${llm.progress}%  -  please keep the app open.',
          action: LinearProgressIndicator(value: llm.progress / 100),
        );
      case LlmStatus.error:
        content = _Info(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          text: llm.error ?? 'Unknown error',
          action: FilledButton(onPressed: llm.init, child: const Text('Try again')),
        );
      default:
        content = const _Info(
          icon: Icons.memory,
          title: 'Loading model...',
          text: 'Getting Qwen ready on your phone.',
          action: CircularProgressIndicator(),
        );
    }
    return Scaffold(body: SafeArea(child: Center(child: content)));
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: t.colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: t.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          action,
        ],
      ),
    );
  }
}
