import 'package:flutter/foundation.dart';

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

  void start(String value) {
    status = value;
    busy = true;
    completed = false;
    progress = 0.08;
    notifyListeners();
  }

  void updateProgress({required String statusText, required double value, String? runUrl}) {
    status = statusText;
    progress = value.clamp(0, 1);
    latestRunUrl = runUrl ?? latestRunUrl;
    lastPollAt = DateTime.now();
    notifyListeners();
  }

  void finish(String value) {
    status = value;
    busy = false;
    completed = true;
    progress = 1;
    notifyListeners();
  }

  void fail(String value) {
    status = value;
    busy = false;
    completed = false;
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