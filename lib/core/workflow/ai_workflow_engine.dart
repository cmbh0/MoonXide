import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'ai_task_plan.dart';
import 'ai_task_planner.dart';
import 'ai_task_step.dart';
import 'ai_task_step_status.dart';

/// 真实步骤执行回调类型
/// 由 ChatScreen 注入，每个步骤调用时传入步骤标题和详情，返回执行结果
typedef StepExecutor = Future<String> Function(String title, String detail, String goal);

class AiWorkflowEngine extends ChangeNotifier {
  final AiTaskPlanner planner;
  AiTaskPlan? currentPlan;
  bool running = false;
  bool paused = false;
  String eventLog = '';

  /// 真实执行器，由 ChatScreen 在发送消息时注入
  StepExecutor? _executor;

  AiWorkflowEngine({AiTaskPlanner? planner}) : planner = planner ?? AiTaskPlanner();

  /// 注入真实执行器
  void setExecutor(StepExecutor executor) {
    _executor = executor;
  }

  void createTask(String instruction) {
    // 初始规划表：由大纲占位，提示规划中。我们随后通过 AI 调用进行完全动态的主动规划和填充。
    final id = const Uuid().v4();
    final steps = <AiTaskStep>[
      AiTaskStep(id: const Uuid().v4(), title: '🤔 理解并规划', detail: '深度剖析任务指令："$instruction"，正在设计最优的敏捷实现路径...'),
    ];
    currentPlan = AiTaskPlan(
      id: id,
      userInstruction: instruction,
      goal: instruction.isEmpty ? '完成开发任务' : instruction,
      steps: steps,
    );
    eventLog = '已创建任务：${currentPlan!.goal}';
    running = false;
    paused = false;
    notifyListeners();
  }

  /// 允许外部或 AI 规划后覆盖/更新完整的规划步骤
  void updatePlanSteps(List<AiTaskStep> steps) {
    if (currentPlan == null) return;
    currentPlan = currentPlan!.copyWith(steps: steps, finished: steps.every((e) => e.status == AiTaskStepStatus.completed));
    notifyListeners();
  }

  Future<void> startAutoRun() async {
    if (currentPlan == null || running) return;
    running = true;
    paused = false;
    notifyListeners();
    while (running && !paused && currentPlan != null && !currentPlan!.finished) {
      final index = currentPlan!.steps.indexWhere(
          (e) => e.status == AiTaskStepStatus.pending || e.status == AiTaskStepStatus.failed);
      if (index < 0) {
        currentPlan = currentPlan!.copyWith(finished: true);
        eventLog = '$eventLog\n✅ 全部步骤完成。';
        running = false;
        notifyListeners();
        break;
      }
      await runStep(index);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> runStep(int index) async {
    final plan = currentPlan;
    if (plan == null || index < 0 || index >= plan.steps.length) return;
    final step = plan.steps[index];
    _updateStep(index, step.copyWith(status: AiTaskStepStatus.running));
    eventLog = '$eventLog\n▶ ${step.title}';
    notifyListeners();
    try {
      String result;
      if (_executor != null) {
        // 真实执行：调用注入的 AI + 工具链
        result = await _executor!(step.title, step.detail, plan.goal);
      } else {
        throw StateError('未连接 AI 对话执行器，请先从 AI 对话页发送任务。');
      }
      _updateStep(index, step.copyWith(status: AiTaskStepStatus.completed, result: result));
      eventLog = '$eventLog\n✓ ${step.title}';
    } catch (e) {
      _updateStep(index, step.copyWith(status: AiTaskStepStatus.failed, result: e.toString()));
      eventLog = '$eventLog\n✗ ${step.title}：$e';
      running = false;
    }
    notifyListeners();
  }

  void _updateStep(int index, AiTaskStep next) {
    final steps = [...currentPlan!.steps];
    steps[index] = next;
    final finished = steps.every((e) => e.status == AiTaskStepStatus.completed);
    currentPlan = currentPlan!.copyWith(steps: steps, finished: finished);
  }

  void pause() {
    paused = true;
    running = false;
    eventLog = '$eventLog\n⏸ 任务已暂停。';
    notifyListeners();
  }

  void resume() {
    if (currentPlan == null || currentPlan!.finished) return;
    startAutoRun();
  }

  void reset() {
    currentPlan = null;
    running = false;
    paused = false;
    eventLog = '';
    _executor = null;
    notifyListeners();
  }
}