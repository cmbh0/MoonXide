import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../app/mx_widgets.dart';
import '../../core/ai/ai_api_client.dart';
import '../../core/ai/ai_config_state.dart';
import '../../core/chat/chat_conversation_state.dart';
import '../../core/chat/chat_message_record.dart';
import '../../core/chat/chat_role.dart';
import '../../core/workflow/ai_workflow_engine.dart';
import '../../core/workflow/ai_task_step_status.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showPlan    = true;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(
    ChatConversationState chat,
    AiConfigState aiConfig,
    AiWorkflowEngine workflow,
  ) async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || chat.busy) return;
    _inputCtrl.clear();
    workflow.createTask(text);
    workflow.startAutoRun();
    await chat.sendUserText(text, aiConfig);
    _scrollToBottom();

    // 真实 AI 调用
    try {
      final cfg = aiConfig.config;
      if (cfg.baseUrl.trim().isEmpty || cfg.apiKey.trim().isEmpty) {
        chat.appendAssistantDelta('⚠️ 请先在设置中配置 AI 接口地址和 API Key。');
      } else {
        final history = chat.messages
            .where((m) => !m.taskOpen)
            .map((m) => {'role': m.role == ChatRole.user ? 'user' : 'assistant', 'content': m.content})
            .toList();
        final rawBody = await AiApiClient().sendWithHistory(cfg, history, text);
        // 解析响应
        String reply = '';
        if (cfg.stream) {
          // SSE 流式：逐行解析 data: {...}
          for (final line in rawBody.split('\n')) {
            final l = line.trim();
            if (!l.startsWith('data:')) continue;
            final data = l.substring(5).trim();
            if (data == '[DONE]') break;
            try {
              final j = jsonDecode(data) as Map;
              final delta = (j['choices'] as List?)?.first['delta']?['content'] as String? ?? '';
              if (delta.isNotEmpty) {
                reply += delta;
                chat.appendAssistantDelta(delta);
                _scrollToBottom();
              }
            } catch (_) {}
          }
        } else {
          // 非流式：一次性解析
          final j = jsonDecode(rawBody) as Map;
          reply = (j['choices'] as List?)?.first['message']?['content'] as String?
              ?? (j['content'] as List?)?.first['text'] as String?
              ?? rawBody;
          chat.appendAssistantDelta(reply);
        }
      }
    } catch (e) {
      chat.appendAssistantDelta('\n\n❌ 请求失败：$e');
    }

    await chat.finishAssistantTask(aiConfig);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ── 长按 AI 气泡菜单 ────────────────────────────────────────────────────────
  void _onLongPressAi(
      BuildContext context, ChatMessageRecord msg, ChatConversationState chat) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A1C2C) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.70)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF3B8FC7).withOpacity(0.16),
                blurRadius: 28,
                offset: const Offset(0, -6))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 把手
            Center(
              child: Container(
                width: 34, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: scheme.onSurface.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // 消息预览
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                msg.content.length > 120
                    ? '${msg.content.substring(0, 120)}…'
                    : msg.content,
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.65)),
              ),
            ),
            const SizedBox(height: 16),
            // 回滚到此节点
            _SheetAction(
              icon: Icons.history_rounded,
              label: '回滚到此对话节点',
              sub: '删除此消息之后的所有内容',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _confirmRollback(context, msg, chat);
              },
            ),
            const SizedBox(height: 8),
            // 复制
            _SheetAction(
              icon: Icons.copy_rounded,
              label: '复制消息',
              color: scheme.primary,
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: msg.content));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRollback(
      BuildContext context, ChatMessageRecord msg, ChatConversationState chat) {
    MxDialog.show(context,
      title: '确认回滚',
      content: '将删除此消息之后的所有对话记录，此操作不可撤销。',
      confirmLabel: '确认回滚',
      cancelLabel: '取消',
      confirmColor: Colors.orange,
    ).then((ok) { if (ok) chat.rollbackToMessage(msg.id); });
  }

  Future<void> _showHistory(ChatConversationState chat) async {
    final files = await chat.store.listFiles();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.72,
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF0A1C2C) : Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('对话历史 / 记忆文件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Expanded(
            child: files.isEmpty
                ? const MxEmpty(icon: Icons.history_rounded, label: '暂无历史对话')
                : ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (_, i) {
                      final f = File(files[i].path);
                      final id = f.uri.pathSegments.last.replaceAll('.txt', '');
                      final stat = f.statSync();
                      return MxCard(
                        child: Row(children: [
                          const Icon(Icons.description_rounded, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(id, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('${stat.modified}', style: const TextStyle(fontSize: 11)),
                          ])),
                          MxIconBtn(icon: Icons.open_in_new_rounded, size: 32, onPressed: () { Navigator.pop(ctx); chat.loadHistoryAsContext(id); }),
                          MxIconBtn(icon: Icons.delete_rounded, size: 32, onPressed: () async { await chat.deleteHistory(id); if (ctx.mounted) Navigator.pop(ctx); }),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  IconData _stepIcon(AiTaskStepStatus s) {
    switch (s) {
      case AiTaskStepStatus.pending:   return Icons.radio_button_unchecked;
      case AiTaskStepStatus.running:   return Icons.autorenew_rounded;
      case AiTaskStepStatus.completed: return Icons.check_circle_rounded;
      case AiTaskStepStatus.failed:    return Icons.error_rounded;
    }
  }

  Color _stepColor(BuildContext ctx, AiTaskStepStatus s) {
    final scheme = Theme.of(ctx).colorScheme;
    switch (s) {
      case AiTaskStepStatus.pending:   return scheme.outline;
      case AiTaskStepStatus.running:   return scheme.primary;
      case AiTaskStepStatus.completed: return Colors.green;
      case AiTaskStepStatus.failed:    return scheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat     = context.watch<ChatConversationState>();
    final aiConfig = context.watch<AiConfigState>();
    final workflow = context.watch<AiWorkflowEngine>();
    final plan     = workflow.currentPlan;
    final scheme   = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── 工具栏 ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 10, 4),
          child: Row(
            children: [
              MxIconBtn(
                icon: _showPlan
                    ? Icons.account_tree_rounded
                    : Icons.account_tree_outlined,
                onPressed: () => setState(() => _showPlan = !_showPlan),
                tooltip: '任务规划',
                active: _showPlan && plan != null,
                size: 34,
              ),
              const Spacer(),
              MxIconBtn(
                  icon: Icons.add_comment_rounded,
                  onPressed: chat.newConversation,
                  tooltip: '新对话',
                  size: 34),
              const SizedBox(width: 3),
              MxIconBtn(
                  icon: Icons.manage_search_rounded,
                  onPressed: () => _showHistory(chat),
                  tooltip: '历史/搜索',
                  size: 34),
              const SizedBox(width: 3),
              MxIconBtn(
                  icon: Icons.undo_rounded,
                  onPressed: chat.rollbackLastMessage,
                  tooltip: '撤回上一条',
                  size: 34),
              const SizedBox(width: 3),
              MxIconBtn(
                  icon: Icons.refresh_rounded,
                  onPressed: workflow.reset,
                  tooltip: '重置任务',
                  size: 34),
            ],
          ),
        ),

        // ── 任务规划面板 ──────────────────────────────────────────────────
        if (_showPlan && plan != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: MxCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 15, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(plan.goal,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                    MxBadge(
                      plan.finished
                          ? '已完成'
                          : (workflow.running ? '执行中' : '已暂停'),
                      color: plan.finished
                          ? Colors.green
                          : (workflow.running ? scheme.primary : Colors.orange),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: plan.steps.isEmpty
                          ? 0
                          : plan.steps
                                  .where((e) =>
                                      e.status == AiTaskStepStatus.completed)
                                  .length /
                              plan.steps.length,
                      minHeight: 3,
                      backgroundColor: scheme.primary.withOpacity(0.10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...plan.steps.map((step) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Icon(_stepIcon(step.status),
                              size: 13,
                              color: _stepColor(context, step.status)),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(step.title,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        scheme.onSurface.withOpacity(0.72))),
                          ),
                        ]),
                      )),
                  const SizedBox(height: 8),
                  Row(children: [
                    MxButton(
                        label: '暂停',
                        icon: Icons.pause_rounded,
                        onPressed: workflow.pause,
                        filled: false,
                        small: true),
                    const SizedBox(width: 8),
                    MxButton(
                        label: '继续',
                        icon: Icons.play_arrow_rounded,
                        onPressed: workflow.resume,
                        filled: false,
                        small: true),
                  ]),
                ],
              ),
            ),
          ),

        // ── 消息列表 ──────────────────────────────────────────────────────
        Expanded(
          child: chat.messages.isEmpty
              ? const MxEmpty(
                  icon: Icons.auto_awesome_rounded,
                  label: '开始对话',
                  hint: '输入问题或开发任务')
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  itemCount: chat.messages.length,
                  itemBuilder: (_, i) {
                    final m      = chat.messages[i];
                    final isUser = m.role == ChatRole.user;
                    final bubble = _Bubble(
                      message: m,
                      isUser: isUser,
                      isDark: isDark,
                      scheme: scheme,
                      onLongPress: isUser
                          ? null
                          : () => _onLongPressAi(context, m, chat),
                    );
                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.84),
                        child: bubble,
                      ),
                    );
                  },
                ),
        ),

        // ── 输入栏 ────────────────────────────────────────────────────────
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: MxTextField(
                    controller: _inputCtrl,
                    hint: '输入问题或开发任务…',
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                const SizedBox(width: 7),
                MxIconBtn(
                  icon: chat.busy
                      ? Icons.hourglass_top_rounded
                      : Icons.send_rounded,
                  onPressed: chat.busy
                      ? null
                      : () => _send(chat, aiConfig, workflow),
                  active: true,
                  size: 42,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 消息气泡（带入场动画） ───────────────────────────────────────────────────
class _Bubble extends StatefulWidget {
  const _Bubble({
    required this.message,
    required this.isUser,
    required this.isDark,
    required this.scheme,
    this.onLongPress,
  });

  final ChatMessageRecord message;
  final bool isUser;
  final bool isDark;
  final ColorScheme scheme;
  final VoidCallback? onLongPress;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(widget.isUser ? 0.12 : -0.12, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: GestureDetector(
            onLongPress: widget.onLongPress,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: widget.isUser
                    ? widget.scheme.primary.withOpacity(0.90)
                    : (widget.isDark ? const Color(0xFF0F2230) : Colors.white)
                        .withOpacity(widget.isDark ? 0.88 : 0.92),
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(widget.isUser ? 16 : 4),
                  bottomRight: Radius.circular(widget.isUser ? 4 : 16),
                ),
                border: widget.isUser
                    ? null
                    : Border.all(
                        color: widget.isDark
                            ? Colors.white.withOpacity(0.07)
                            : Colors.black.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isUser && widget.message.provider.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${widget.message.provider}'
                        '${widget.message.modelId.isEmpty ? '' : ' · ${widget.message.modelId}'}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: widget.scheme.primary.withOpacity(0.65)),
                      ),
                    ),
                  if (widget.isUser)
                    SelectableText(
                      widget.message.content.isEmpty ? '…' : widget.message.content,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    )
                  else
                    MarkdownBody(
                      data: widget.message.content.isEmpty ? '…' : widget.message.content,
                      selectable: true,
                      softLineBreak: true,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 底部弹窗操作行 ───────────────────────────────────────────────────────────
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (sub != null)
                    Text(sub!,
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.45))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}