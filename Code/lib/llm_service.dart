import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import 'config.dart';
import 'models.dart';

enum LlmStatus { loading, needsDownload, downloading, ready, error }

/// Wraps flutter_edge_ai: download once, load the model, stream replies.
class LlmService extends ChangeNotifier {
  LlmStatus status = LlmStatus.loading;
  int progress = 0;
  String? error;

  /// One-time message for the UI (shown as a SnackBar, then cleared).
  String? notice;

  InferenceModel? _model;
  InferenceChat? _chat;

  /// Earlier messages of a reopened chat, sent along with the next message.
  String? _history;

  /// Max characters of old chat to replay (keeps room inside the context window).
  static const _historyChars = 3000;

  void _set(LlmStatus s) {
    status = s;
    notifyListeners();
  }

  /// Loads the model if it is already on the device, otherwise asks for a download.
  Future<void> init() async {
    _set(LlmStatus.loading);
    try {
      _model = await FlutterEdgeAi.getActiveModel(
        maxTokens: AppConfig.maxTokens,
        preferredBackend: AppConfig.backend,
      );
      await newChat();
      _set(LlmStatus.ready);
    } catch (e) {
      // "No model installed yet" is expected on the first launch.
      if (e is StateError && e.runtimeType.toString().contains('NoActiveModel')) {
        _set(LlmStatus.needsDownload);
      } else {
        error = e.toString();
        _set(LlmStatus.error);
      }
    }
  }

  /// One-time download (needs internet). Afterwards the app is fully offline.
  Future<void> download() async {
    progress = 0;
    _set(LlmStatus.downloading);
    try {
      await FlutterEdgeAi.installModel(
        modelType: AppConfig.modelType,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(AppConfig.modelUrl).withProgress((p) {
        progress = p.toInt();
        notifyListeners();
      }).install();
      await init();
    } catch (e) {
      error = e.toString();
      _set(LlmStatus.error);
    }
  }

  /// Starts a fresh model session. Pass [history] when reopening a saved chat
  /// so the model can continue it (only the most recent part is replayed).
  Future<void> newChat({List<ChatMessage> history = const []}) async {
    await stopGeneration();
    await _chat?.close();
    _chat = await _model!.openChat(
      systemInstruction: AppConfig.systemPrompt,
      enableThinking: false, // plain answers, no <think> reasoning
      maxOutputTokens: AppConfig.maxReplyTokens,
      modelType: AppConfig.modelType,
    );
    _history = _transcript(history);
  }

  /// Turns the newest messages into a short "User: ... / Assistant: ..." text.
  String? _transcript(List<ChatMessage> messages) {
    final lines = <String>[];
    var used = 0;
    for (final m in messages.reversed) {
      final body = stripThink(m.text);
      if (body.isEmpty) continue;
      final room = _historyChars - used;
      if (room <= 0) break;
      final line = '${m.isUser ? 'User' : 'Assistant'}: $body';
      lines.add(line.length > room ? line.substring(line.length - room) : line);
      used += line.length;
    }
    return lines.isEmpty ? null : lines.reversed.join('\n');
  }

  /// Sends [text]; emits the full reply so far each time a new token arrives.
  Stream<String> send(String text) async* {
    try {
      yield* _ask(text);
    } catch (e) {
      // Chat history filled the context window: start fresh and retry once.
      if (!e.runtimeType.toString().contains('ContextLimit')) rethrow;
      await newChat();
      notice = 'Chat got long, so I started a fresh conversation.';
      yield* _ask(text);
    }
  }

  Stream<String> _ask(String text) async* {
    final chat = _chat!;
    final prompt = _history == null
        ? text
        : 'Here is our earlier conversation, for context:\n$_history\n\n'
            'Now answer my new message:\n$text';
    _history = null;
    await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    final reply = StringBuffer();
    await for (final r in chat.generateChatResponseAsync()) {
      if (r is TextResponse) {
        reply.write(r.token);
        yield reply.toString();
      }
    }
  }

  /// Stops a reply in progress. `dynamic` keeps the app compiling even if a
  /// future package version renames this method.
  Future<void> stopGeneration() async {
    try {
      await (_chat as dynamic)?.stopGeneration();
    } catch (_) {}
  }

  @override
  void dispose() {
    _chat?.close();
    _model?.close();
    super.dispose();
  }
}
