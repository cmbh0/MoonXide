import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../core/ai/ai_config_state.dart';
import '../../core/chat/chat_conversation_state.dart';
import '../../core/chat/chat_role.dart';
import '../../core/workflow/ai_workflow_engine.dart';
import '../../core/workflow/ai_task_step_status.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final inputController = TextEditingController();
  bool showPlan = true;

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }

  Future<void> _send(ChatConversationState chat, AiConfigState aiConfig, AiWorkflowEngine workflow) async {
    final text = inputController.text.trim();
    if (text.isEmpty || chat.busy) return;
    inputController.clear();
    workflow.createTask(text);
    workflow.startAutoRun();
    await chat.sendUserText(text, aiConfig);
    await chat.addToolResult(chat.snapshot().asPromptAttachment());
    await chat.finishAssistantTask(aiConfig);
  }

  IconData _icon(AiTaskStepStatus status) {
    switch (status) {
      case AiTaskStepStatus.pending:
        return Icons.radio_button_unchecked;
      case AiTaskStepStatus.running:
        return Icons.autorenew;
      case AiTaskStepStatus.completed:
        return Icons.check_circle;
      case AiTaskStepStatus.failed:
        return Icons.error;
    }
  }

  Color _color(BuildContext context, AiTaskStepStatus status) {
    switch (status) {
      case AiTaskStepStatus.pending:
        return Theme.of(context).colorScheme.outline;
      case AiTaskStepStatus.running:
        return Theme.of(context).colorScheme.primary;
      case AiTaskStepStatus.completed:
        return Colors.green;
      case AiTaskStepStatus.failed:
        return Theme.of(context).colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatConversationState>();
    final aiConfig = context.watch<AiConfigState>();
    final workflow = context.watch<AiWorkflowEngine>();
    final plan = workflow.currentPlan;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        actions: [
          IconButton(tooltip: '显示/隐藏任务规划', onPressed: () => setState(() => showPlan = !showPlan), icon: const Icon(Icons.account_tree_rounded)),
          IconButton(onPressed: chat.rollbackLastMessage, icon: const Icon(Icons.undo_rounded)),
          IconButton(onPressed: workflow.reset, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          if (showPlan && plan != null)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45),
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.auto_awesome_rounded),
                title: Text(plan.goal, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: LinearProgressIndicator(
                  value: plan.steps.isEmpty ? 0 : plan.steps.where((e) => e.status == AiTaskStepStatus.completed).length / plan.steps.length,
                ),
                children: [
                  for (final step in plan.steps)
                    ListTile(
                      dense: true,
                      leading: Icon(_icon(step.status), color: _color(context, step.status)),
                      title: Text(step.title),
                      subtitle: Text('${step.detail}${step.result == null ? '' : '\n${step.result}'}'),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        OutlinedButton.icon(onPressed: workflow.pause, icon: const Icon(Icons.pause_rounded), label: const Text('暂停')),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(onPressed: workflow.resume, icon: const Icon(Icons.play_arrow_rounded), label: const Text('继续执行')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: chat.messages.length,
              itemBuilder: (_, i) {
                final m = chat.messages[i];
                final isUser = m.role == ChatRole.user;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Card(
                      color: isUser ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser)
                              Text(
                                '${m.provider}${m.modelId.isEmpty ? '' : ' · ${m.modelId}'}${m.streaming ? ' · 流式' : ''}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            if (isUser)
                              SelectableText(m.content.isEmpty ? 'AI 正在规划并执行任务...' : m.content)
                            else
                              MarkdownBody(data: m.content.isEmpty ? 'AI 正在规划并执行任务...' : m.content, selectable: true, softLineBreak: true),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: inputController,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(hintText: '输入问题或开发任务，AI 会在聊天中规划并执行', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(onPressed: chat.busy ? null : () => _send(chat, aiConfig, workflow), icon: const Icon(Icons.send_rounded), label: const Text('发送')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}