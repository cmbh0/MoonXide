enum AiTaskStepStatus {
  pending,
  running,
  completed,
  failed,
}

extension AiTaskStepStatusText on AiTaskStepStatus {
  String get zhName {
    switch (this) {
      case AiTaskStepStatus.pending:
        return '待完成';
      case AiTaskStepStatus.running:
        return '进行中';
      case AiTaskStepStatus.completed:
        return '已完成';
      case AiTaskStepStatus.failed:
        return '失败';
    }
  }
}