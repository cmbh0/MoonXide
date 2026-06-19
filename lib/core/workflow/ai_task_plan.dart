import 'ai_task_step.dart';

class AiTaskPlan {
  final String id;
  final String userInstruction;
  final String goal;
  final List<AiTaskStep> steps;
  final bool autoContinue;
  final bool finished;

  const AiTaskPlan({
    required this.id,
    required this.userInstruction,
    required this.goal,
    required this.steps,
    this.autoContinue = true,
    this.finished = false,
  });

  AiTaskPlan copyWith({List<AiTaskStep>? steps, bool? autoContinue, bool? finished}) {
    return AiTaskPlan(
      id: id,
      userInstruction: userInstruction,
      goal: goal,
      steps: steps ?? this.steps,
      autoContinue: autoContinue ?? this.autoContinue,
      finished: finished ?? this.finished,
    );
  }
}