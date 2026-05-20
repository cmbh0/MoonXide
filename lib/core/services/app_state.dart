import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/build_profile.dart';
import 'github_service.dart';
import 'token_store.dart';

class AppState extends ChangeNotifier {
  final TokenStore tokenStore;
  GithubService? github;

  String? token;
  String? login;
  String? selectedOwner;
  String? selectedRepo;
  String? avatarUrl;
  Map<String, dynamic>? currentUser;
  String? customBackgroundPath;
  bool loading = false;
  bool tokenValidated = false;
  String? tokenStatus;
  String? error;
  BuildProfile buildProfile = BuildProfile.debug;

  AppState({required this.tokenStore});

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    customBackgroundPath = prefs.getString('custom_background_path');
    token = await tokenStore.readToken();
    if (token == null || token!.isEmpty) return;
    github = GithubService(token: token!);
    tokenValidated = false;
    tokenStatus = '已加载本地 Token，正在后台验证 GitHub 连接...';
    notifyListeners();
    unawaited(refreshTokenValidation());
  }

  Future<bool> refreshTokenValidation() async {
    if (token == null || token!.isEmpty || github == null) return false;
    try {
      final user = await github!.getCurrentUser();
      login = user['login'] as String?;
      avatarUrl = user['avatar_url'] as String?;
      currentUser = Map<String, dynamic>.from(user);
      selectedOwner = login;
      tokenValidated = true;
      tokenStatus = login == null ? 'Token 验证成功' : 'Token 验证成功：$login';
      error = null;
      notifyListeners();
      return true;
    } on SocketException catch (e) {
      tokenValidated = false;
      tokenStatus = '无法连接 GitHub：${_friendlySocketMessage(e)}';
      notifyListeners();
      return false;
    } catch (e) {
      tokenValidated = false;
      tokenStatus = null;
      error = _formatTokenError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptToken(String value) async {
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      error = '请先填写 GitHub Token';
      notifyListeners();
      return false;
    }

    loading = true;
    error = null;
    tokenStatus = '正在验证 Token...';
    notifyListeners();

    final service = GithubService(token: cleaned);
    token = cleaned;
    github = service;
    await tokenStore.saveToken(cleaned);

    try {
      final user = await service.getCurrentUser();
      login = user['login'] as String?;
      avatarUrl = user['avatar_url'] as String?;
      currentUser = Map<String, dynamic>.from(user);
      selectedOwner = login;
      tokenValidated = true;
      tokenStatus = login == null ? 'Token 验证成功' : 'Token 验证成功：$login';
      loading = false;
      notifyListeners();
      return true;
    } on SocketException catch (e) {
      tokenValidated = false;
      tokenStatus = '已保存 Token，但当前无法连接 GitHub：${_friendlySocketMessage(e)}';
      loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      tokenValidated = false;
      tokenStatus = null;
      error = _formatTokenError(e);
      loading = false;
      notifyListeners();
      return false;
    }
  }

  bool _isDnsFailure(SocketException e) {
    final message = e.message.toLowerCase();
    return e.osError?.errorCode == 7 || message.contains('failed host lookup') || message.contains('主机查找失败') || message.contains('no address associated');
  }

  String _friendlySocketMessage(SocketException e) {
    if (_isDnsFailure(e)) return '无法解析 api.github.com，请检查网络、DNS、代理或系统网络权限';
    return e.message;
  }

  String _formatTokenError(Object e) {
    final message = e.toString();
    if (message.contains('GitHub API 401')) return 'Token 无效或已过期，请重新生成 Token';
    if (message.contains('GitHub API 403')) return 'Token 权限不足或请求被 GitHub 拒绝，请确认包含 repo、workflow、read:user 权限';
    return 'Token 验证失败：$message';
  }

  Future<void> logout() async {
    await tokenStore.clearToken();
    token = null;
    github = null;
    login = null;
    avatarUrl = null;
    currentUser = null;
    selectedOwner = null;
    selectedRepo = null;
    tokenStatus = null;
    error = null;
    tokenValidated = false;
    notifyListeners();
  }

  void selectRepository(String owner, String repo) {
    selectedOwner = owner;
    selectedRepo = repo;
    notifyListeners();
  }

  void clearRepositorySelection() {
    selectedOwner = null;
    selectedRepo = null;
    notifyListeners();
  }

  Future<void> setCustomBackground(String? path) async {
    customBackgroundPath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove('custom_background_path');
    } else {
      await prefs.setString('custom_background_path', path);
    }
    notifyListeners();
  }

  void setBuildProfile(BuildProfile value) {
    buildProfile = value;
    notifyListeners();
  }
}