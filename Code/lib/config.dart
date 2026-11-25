import 'package:flutter_edge_ai/flutter_edge_ai.dart';

/// Everything you may want to tweak lives here.
class AppConfig {
  static const appTitle = 'Qwen Chat';

  // Qwen3 0.6B: downloaded once, then it runs 100% offline.
  static const modelUrl =
      'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B.litertlm';
  static const modelType = ModelType.qwen3;
  static const modelSizeLabel = 'about 590 MB';

  /// Context window = system prompt + chat history + reply. Lower = less RAM.
  static const maxTokens = 2048;

  /// Longest single reply.
  static const maxReplyTokens = 768;

  /// CPU works on every phone. Try PreferredBackend.gpu for more speed.
  static const backend = PreferredBackend.cpu;

  static const systemPrompt =
      'You are a helpful, friendly AI assistant. Always reply in clear English. '
      'Keep answers concise unless the user asks for more detail.';
}
