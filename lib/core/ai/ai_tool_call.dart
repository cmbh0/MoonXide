// AI 工具调用记录
class AiToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> args;
  AiToolCallStatus status;
  String? result;
  String? error;

  AiToolCall({
    required this.id,
    required this.name,
    required this.args,
    this.status = AiToolCallStatus.pending,
    this.result,
    this.error,
  });

  AiToolCall copyWith({AiToolCallStatus? status, String? result, String? error}) => AiToolCall(
    id: id, name: name, args: args,
    status: status ?? this.status,
    result: result ?? this.result,
    error: error ?? this.error,
  );
}

enum AiToolCallStatus { pending, running, approved, denied, completed, failed }
