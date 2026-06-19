import 'package:uuid/uuid.dart';
import 'ai_task_plan.dart';
import 'ai_task_step.dart';

class AiTaskPlanner {
  AiTaskPlan createPlan(String instruction) {
    final id = const Uuid().v4();
    final normalized = instruction.trim();
    // 默认回退规划，真正开发由 AI 实时生成
    final steps = <AiTaskStep>[
      AiTaskStep(id: const Uuid().v4(), title: '🤔 理解需求', detail: '解析指令目标与限制。'),
      AiTaskStep(id: const Uuid().v4(), title: '🔍 检查工作区', detail: '读取工作区与文件树状态。'),
      AiTaskStep(id: const Uuid().v4(), title: '🛠️ 执行任务', detail: '使用特定工具完成开发行为。'),
      AiTaskStep(id: const Uuid().v4(), title: '✅ 校验与收尾', detail: '验证编译状态并提示用户。'),
    ];
    return AiTaskPlan(id: id, userInstruction: normalized, goal: normalized.isEmpty ? '完成用户指定的软件开发任务' : normalized, steps: steps);
  }
}