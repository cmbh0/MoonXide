import 'package:flutter/foundation.dart';

enum BuildOutcome { idle, running, success, failure }

class BuildCenterState extends ChangeNotifier {
  String status = '未开始';
  String? logText;
  String? artifactLocalPath;
  String? artifactDownloadUrl;
  String? artifactName;
  bool busy = false;
  double progress = 0;
  bool completed = false;
  DateTime? lastPollAt;
  String? latestRunUrl;
  int? currentRunId;
  String? currentStep;
  BuildOutcome outcome = BuildOutcome.idle;

  /// 单次性通知载荷：HomeScreen 监听后弹 SnackBar，再调用 [consumeNotice] 清空。
  String? _pendingNotice;
  bool _noticeIsError = false;
  String? get pendingNotice => _pendingNotice;
  bool get pendingNoticeIsError => _noticeIsError;
  void consumeNotice() {
    _pendingNotice = null;
    _noticeIsError = false;
  }

  void start(String value) {
    status = value;
    busy = true;
    completed = false;
    progress = 0.08;
    outcome = BuildOutcome.running;
    currentStep = null;
    artifactLocalPath = null;
    artifactDownloadUrl = null;
    artifactName = null;
    logText = null;
    _pendingNotice = value;
    _noticeIsError = false;
    notifyListeners();
  }

  void updateProgress({
    required String statusText,
    required double value,
    String? runUrl,
    int? runId,
    String? step,
  }) {
    status = statusText;
    progress = value.clamp(0, 1);
    latestRunUrl = runUrl ?? latestRunUrl;
    currentRunId = runId ?? currentRunId;
    if (step != null) currentStep = step;
    lastPollAt = DateTime.now();
    notifyListeners();
  }

  void finish(String value) {
    status = value;
    busy = false;
    completed = true;
    progress = 1;
    outcome = BuildOutcome.success;
    _pendingNotice = value;
    _noticeIsError = false;
    notifyListeners();
  }

  void fail(String value) {
    status = value;
    busy = false;
    completed = false;
    outcome = BuildOutcome.failure;
    _pendingNotice = value;
    _noticeIsError = true;
    notifyListeners();
  }

  void setStatus(String value) {
    status = value;
    notifyListeners();
  }

  void setLog(String? value) {
    logText = value;
    notifyListeners();
  }

  void setArtifact({String? localPath, String? downloadUrl, String? name}) {
    artifactLocalPath = localPath;
    artifactDownloadUrl = downloadUrl;
    artifactName = name ?? artifactName;
    notifyListeners();
  }
}