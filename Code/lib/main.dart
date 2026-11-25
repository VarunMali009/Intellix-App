import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import 'chat_screen.dart';
import 'chat_store.dart';
import 'config.dart';
import 'llm_service.dart';
import 'setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Register the engine that runs .litertlm models (Qwen3 etc.).
  await FlutterEdgeAi.initialize(inferenceEngines: const [LiteRtLmEngine()]);
  runApp(const QwenChatApp());
}

class QwenChatApp extends StatefulWidget {
  const QwenChatApp({super.key});

  @override
  State<QwenChatApp> createState() => _QwenChatAppState();
}

class _QwenChatAppState extends State<QwenChatApp> {
  final _llm = LlmService();
  final _store = ChatStore();

  @override
  void initState() {
    super.initState();
    _store.load(); // saved chats for the history sidebar
    _llm.init();
  }

  @override
  void dispose() {
    _llm.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: _llm,
        builder: (context, _) => _llm.status == LlmStatus.ready
            ? ChatScreen(llm: _llm, store: _store)
            : SetupScreen(llm: _llm),
      ),
    );
  }
}
