import 'package:flutter/material.dart';

import 'chat_store.dart';
import 'models.dart';

/// ChatGPT-style sidebar that lists all saved chats.
class HistoryDrawer extends StatelessWidget {
  const HistoryDrawer({
    super.key,
    required this.store,
    required this.currentId,
    required this.onOpen,
    required this.onNew,
    required this.onDelete,
    required this.onClearAll,
  });

  final ChatStore store;
  final String currentId;
  final void Function(Conversation) onOpen;
  final VoidCallback onNew;
  final void Function(Conversation) onDelete;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () {
                    Navigator.pop(context);
                    onNew();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New chat'),
                ),
              ),
              Expanded(
                child: store.chats.isEmpty
                    ? const Center(child: Text('Your chats will appear here'))
                    : ListView.builder(
                        itemCount: store.chats.length,
                        itemBuilder: (context, i) => _tile(context, store.chats[i]),
                      ),
              ),
              if (store.chats.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: const Text('Delete all chats'),
                  onTap: () async {
                    if (await _confirm(context, 'Delete all chats?')) {
                      onClearAll();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Conversation c) {
    return ListTile(
      selected: c.id == currentId,
      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_when(c.updatedAt)),
      onTap: () {
        Navigator.pop(context);
        onOpen(c);
      },
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'rename') {
            final name = await _askName(context, c.title);
            if (name != null) store.rename(c, name);
          } else if (await _confirm(context, 'Delete this chat?')) {
            onDelete(c);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<String?> _askName(BuildContext context, String current) {
    final ctrl = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(controller: ctrl, autofocus: true, maxLength: 60),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
  }

  String _when(DateTime d) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
