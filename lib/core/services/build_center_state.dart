import 'package:flutter/foundation.dart';

enum BuildOutcome { idle, running, success, failure }

class BuildCenterState extends ChangeNotifier {
  String status = '未开始';
  String? logText;
  String? logFilePath;
  String? artifactLocalPath;
  String? artifactDownloadUrl;
  String? artifactName;
  bool downloadBusy = false;
  double downloadProgress = 0;
  String? buildOwner;
  String? buildRepo;
  String? workflowFile;
  DateTime? triggerStartedAt;
  bool busy = false;
  double progress = 0;
  bool completed = false;
  DateTime? lastPollAt;
  String? latestRunUrl;
  int? currentRunId;
  String? currentStep;
  BuildOutcome outcome = BuildOutcome.idle;
  
  bool hideToast = false;

  void dismissToast() {
    hideToast = true;
    notifyListeners();
  }

  /// 单次性通知载荷：HomeScreen 监听后弹 SnackBar，再调用 [consumeNotice] 清空。
  String? _pendingNotice;
  bool _noticeIsError = false;
  String? get pendingNotice => _pendingNotice;
  bool get pendingNoticeIsError => _noticeIsError;
  void consumeNotice() {
    _pendingNotice = null;
    _noticeIsError = false;
  }

  void start(String value, {String? owner, String? repo, String? workflow}) {
    status = value;
    busy = true;
    completed = false;
    progress = 0.08;
    outcome = BuildOutcome.running;
    currentStep = null;
    currentRunId = null;
    latestRunUrl = null;
    buildOwner = owner;
    buildRepo = repo;
    workflowFile = workflow;
    triggerStartedAt = DateTime.now();
    artifactLocalPath = null;
    artifactDownloadUrl = null;
    artifactName = null;
    logText = null;
    hideToast = false;
    // 不在这里设置 pendingNotice，统一由右下角的 Toast 展示
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

  void updateDownloadProgress(double value) {
    downloadProgress = value.clamp(0.0, 1.0);
    downloadBusy = downloadProgress > 0 && downloadProgress < 1.0;
    notifyListeners();
  }

  void startDownload() {
    downloadBusy = true;
    downloadProgress = 0;
    notifyListeners();
  }

  void finishDownload({String? localPath}) {
    downloadBusy = false;
    downloadProgress = 1.0;
    if (localPath != null) artifactLocalPath = localPath;
    notifyListeners();
  }

  void failDownload() {
    downloadBusy = false;
    downloadProgress = 0;
    notifyListeners();
  }

  void finish(String value) {
    status = value;
    busy = false;
    completed = true;
    progress = 1;
    outcome = BuildOutcome.success;
    hideToast = false;
    notifyListeners();
  }

  void fail(String value) {
    status = value;
    busy = false;
    completed = false;
    outcome = BuildOutcome.failure;
    hideToast = false;
    notifyListeners();
  }

  void setStatus(String value) {
    status = value;
    notifyListeners();
  }

  void setLog(String? value, {String? filePath}) {
    logText = value;
    logFilePath = filePath;
    notifyListeners();
  }

  void setArtifact({String? localPath, String? downloadUrl, String? name}) {
    artifactLocalPath = localPath;
    artifactDownloadUrl = downloadUrl;
    artifactName = name ?? artifactName;
    notifyListeners();
  }
}