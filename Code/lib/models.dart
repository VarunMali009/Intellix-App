/// Hides any raw <think>...</think> reasoning text a model may emit.
String stripThink(String s) =>
    s.replaceAll(RegExp(r'<think>[\s\S]*?(</think>|$)'), '').trim();

class ChatMessage {
  ChatMessage(this.text, {required this.isUser});

  String text;
  final bool isUser;

  Map<String, dynamic> toJson() => {'t': text, 'u': isUser};

  factory ChatMessage.fromJson(Map<String, dynamic> j) =>
      ChatMessage(j['t'] as String, isUser: j['u'] as bool);
}

class Conversation {
  Conversation({
    required this.id,
    this.title = 'New chat',
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  })  : updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [];

  factory Conversation.create() =>
      Conversation(id: DateTime.now().microsecondsSinceEpoch.toString());

  final String id;
  String title;
  DateTime updatedAt;
  final List<ChatMessage> messages;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updated': updatedAt.millisecondsSinceEpoch,
        // Empty assistant bubbles (reply not started yet) are not saved.
        'messages': messages
            .where((m) => m.isUser || m.text.trim().isNotEmpty)
            .map((m) => m.toJson())
            .toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String,
        title: j['title'] as String,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(j['updated'] as int),
        messages: (j['messages'] as List)
            .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
      );
}
