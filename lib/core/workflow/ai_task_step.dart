import 'ai_task_step_status.dart';

class AiTaskStep {
  final String id;
  final String title;
  final String detail;
  final AiTaskStepStatus status;
  final String? result;

  const AiTaskStep({
    required this.id,
    required this.title,
    required this.detail,
    this.status = AiTaskStepStatus.pending,
    this.result,
  });

  AiTaskStep copyWith({AiTaskStepStatus? status, String? result}) {
    return AiTaskStep(
      id: id,
      title: title,
      detail: detail,
      status: status ?? this.status,
      result: result ?? this.result,
    );
  }
}