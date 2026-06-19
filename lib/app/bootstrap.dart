import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/app_state.dart';
import '../../core/services/token_store.dart';
import '../../core/services/editor_state.dart';
import '../../core/services/build_center_state.dart';
import '../../core/workflow/ai_workflow_engine.dart';
import '../../core/ai/ai_config_state.dart';
import '../../core/chat/chat_conversation_state.dart';

class MoonXideBootstrap extends StatelessWidget {
  final Widget child;

  const MoonXideBootstrap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(tokenStore: TokenStore())),
        ChangeNotifierProvider(create: (_) => EditorState()),
        ChangeNotifierProvider(create: (_) => BuildCenterState()),
        ChangeNotifierProvider(create: (_) => AiWorkflowEngine()),
        ChangeNotifierProvider(create: (_) => AiConfigState()..load()),
        ChangeNotifierProvider(create: (_) => ChatConversationState()),
      ],
      child: child,
    );
  }
}