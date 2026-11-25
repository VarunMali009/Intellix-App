import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_store.dart';
import 'config.dart';
import 'history_drawer.dart';
import 'llm_service.dart';
import 'markdown_text.dart';
import 'models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.llm, required this.store});

  final LlmService llm;
  final ChatStore store;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Conversation _chat = Conversation.create();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<String>? _sub;
  bool _busy = false;

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  String _titleFrom(String text) {
    final t = text.replaceAll('\n', ' ').trim();
    return t.length > 40 ? '${t.substring(0, 40)}…' : t;
  }

  void _send([String? preset]) {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    final reply = ChatMessage('', isUser: false);
    setState(() {
      _chat.messages
        ..add(ChatMessage(text, isUser: true))
        ..add(reply);
      if (_chat.messages.length == 2) _chat.title = _titleFrom(text);
      _busy = true;
    });
    widget.store.save(_chat); // saved right away, so it shows up in history
    _scrollDown();
    _sub = widget.llm.send(text).listen(
      (partial) {
        setState(() => reply.text = partial);
        _scrollDown();
      },
      onError: (Object e) => setState(() => reply.text = 'Sorry, something went wrong.\n$e'),
      onDone: _finish,
    );
  }

  void _finish() {
    if (!mounted) return;
    setState(() => _busy = false);
    widget.store.save(_chat);
    final n = widget.llm.notice;
    if (n != null) {
      widget.llm.notice = null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(n)));
    }
  }

  void _stop() {
    _sub?.cancel();
    widget.llm.stopGeneration();
    final last = _chat.messages.isEmpty ? null : _chat.messages.last;
    if (last != null && !last.isUser && last.text.trim().isEmpty) {
      _chat.messages.removeLast();
    }
    setState(() => _busy = false);
    widget.store.save(_chat); // keeps the part of the reply that was written
  }

  /// Opens a saved (or brand new) conversation.
  Future<void> _open(Conversation c) async {
    _sub?.cancel();
    if (_busy && widget.store.contains(_chat)) widget.store.save(_chat);
    await widget.llm.newChat(history: c.messages);
    if (!mounted) return;
    setState(() {
      _chat = c;
      _busy = false;
    });
    _scrollDown();
  }

  Future<void> _delete(Conversation c) async {
    await widget.store.delete(c);
    if (c.id == _chat.id) await _open(Conversation.create());
  }

  Future<void> _clearAll() async {
    await widget.store.clear();
    await _open(Conversation.create());
  }

  @override
  Widget build(BuildContext context) {
    final msgs = _chat.messages;
    return Scaffold(
      drawer: HistoryDrawer(
        store: widget.store,
        currentId: _chat.id,
        onOpen: _open,
        onNew: () => _open(Conversation.create()),
        onDelete: _delete,
        onClearAll: _clearAll,
      ),
      appBar: AppBar(
        title: Text(
          msgs.isEmpty ? AppConfig.appTitle : _chat.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => _open(Conversation.create()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: msgs.isEmpty
                ? _Welcome(onPick: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) => _Bubble(
                      msg: msgs[i],
                      typing: _busy && i == msgs.length - 1,
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Message Qwen...',
                        filled: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: _busy ? 'Stop' : 'Send',
                    onPressed: _busy ? _stop : _send,
                    icon: Icon(_busy ? Icons.stop : Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, required this.typing});

  final ChatMessage msg;
  final bool typing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = stripThink(msg.text);
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
          );
        },
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: msg.isUser ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: text.isEmpty && typing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : msg.isUser
                  ? Text(text)
                  : MarkdownText(text),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPick});

  final void Function(String) onPick;

  static const _ideas = [
    'Explain quantum computing simply',
    'Write a short poem about rain',
    'Give me 5 tips to learn Flutter',
    'What is the capital of Australia?',
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: t.colorScheme.primary),
            const SizedBox(height: 12),
            Text('How can I help you today?', style: t.textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Running 100% offline on your phone'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final idea in _ideas)
                  ActionChip(label: Text(idea), onPressed: () => onPick(idea)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
