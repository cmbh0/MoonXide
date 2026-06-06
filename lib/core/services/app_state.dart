import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
  String? selectedRepoFullName;
  String? avatarUrl;
  Map<String, dynamic>? currentUser;
  String? customBackgroundPath;
  double bgOpacity = 0.72;
  bool loading = false;
  bool tokenValidated = false;
  String? tokenStatus;
  String? error;
  BuildProfile buildProfile = BuildProfile.debug;
  ThemeMode themeMode = ThemeMode.system;
  String? customWorkflowFile;
  String workflowRef = 'main';
  String themeVariant = 'arctic';

  // 支持切换账号与管理多账号
  List<Map<String, String>> accounts = []; // [{"login": "...", "token": "...", "avatarUrl": "..."}]

  AppState({required this.tokenStore});

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    customBackgroundPath = prefs.getString('custom_background_path');
    bgOpacity = prefs.getDouble('bg_opacity') ?? 0.72;
    themeMode = _themeModeFromName(prefs.getString('theme_mode'));
    themeVariant = prefs.getString('theme_variant') ?? 'arctic';
    customWorkflowFile = prefs.getString('custom_workflow_file');
    workflowRef = prefs.getString('workflow_ref') ?? 'main';
    final lastFullName = prefs.getString('selected_repo_full_name');
    if (lastFullName != null && lastFullName.contains('/')) {
      final parts = lastFullName.split('/');
      selectedOwner = parts.first;
      selectedRepo = parts.sublist(1).join('/');
      selectedRepoFullName = lastFullName;
    }
    
    // 加载多账号
    final savedAccounts = prefs.getStringList('github_accounts') ?? [];
    accounts = savedAccounts
        .map((item) {
          final parts = item.split('|');
          if (parts.length < 2 || parts[0].trim().isEmpty || parts[1].trim().isEmpty) {
            return null;
          }
          return {
            'login': parts[0],
            'token': parts[1],
            'avatarUrl': parts.length > 2 ? parts.sublist(2).join('|') : '',
          };
        })
        .whereType<Map<String, String>>()
        .toList();

    token = await tokenStore.readToken();
    if (token == null || token!.isEmpty) return;
    github = GithubService(token: token!);
    tokenValidated = false;
    tokenStatus = '已加载本地 Token，正在后台验证 GitHub 连接...';
    notifyListeners();
    unawaited(refreshTokenValidation());
  }

  Future<void> switchAccount(String loginName) async {
    final acc = accounts.firstWhere((element) => element['login'] == loginName, orElse: () => {});
    if (acc.isEmpty) return;
    final nextToken = acc['token']!;
    
    loading = true;
    error = null;
    tokenStatus = '正在切换并验证 Token...';
    notifyListeners();

    final service = GithubService(token: nextToken);
    token = nextToken;
    github = service;
    await tokenStore.saveToken(nextToken);

    try {
      final user = await service.getCurrentUser();
      login = user['login'] as String?;
      avatarUrl = user['avatar_url'] as String?;
      currentUser = Map<String, dynamic>.from(user);
      selectedOwner = login;
      tokenValidated = true;
      tokenStatus = login == null ? 'Token 验证成功' : 'Token 验证成功：$login';
      loading = false;
      
      // 更新该账号最新头像
      acc['avatarUrl'] = avatarUrl ?? '';
      await _saveAccountsToPrefs();
      
      notifyListeners();
    } catch (e) {
      tokenValidated = false;
      tokenStatus = null;
      error = _formatTokenError(e);
      loading = false;
      notifyListeners();
    }
  }

  Future<void> removeAccount(String loginName) async {
    accounts.removeWhere((element) => element['login'] == loginName);
    await _saveAccountsToPrefs();
    if (login == loginName) {
      if (accounts.isNotEmpty) {
        await switchAccount(accounts.first['login']!);
      } else {
        await logout();
      }
    } else {
      notifyListeners();
    }
  }

  Future<void> _saveAccountsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = accounts.map((e) => '${e['login']}|${e['token']}|${e['avatarUrl']}').toList();
    await prefs.setStringList('github_accounts', list);
  }

  Future<bool> refreshTokenValidation() async {
    if (token == null || token!.isEmpty || github == null) return false;
    try {
      final user = await github!.getCurrentUser();
      final userLogin = user['login'] as String?;
      login = userLogin;
      avatarUrl = user['avatar_url'] as String?;
      currentUser = Map<String, dynamic>.from(user);
      selectedOwner ??= userLogin;
      tokenValidated = true;
      tokenStatus = userLogin == null ? 'Token 验证成功' : 'Token 验证成功：$userLogin';
      error = null;
      
      if (userLogin != null && token != null) {
        _addOrUpdateAccount(userLogin, token!, avatarUrl ?? '');
      }
      
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

  void _addOrUpdateAccount(String loginName, String tokenVal, String avatar) {
    accounts.removeWhere((element) => element['login'] == loginName);
    accounts.add({
      'login': loginName,
      'token': tokenVal,
      'avatarUrl': avatar,
    });
    unawaited(_saveAccountsToPrefs());
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
      final userLogin = user['login'] as String?;
      login = userLogin;
      avatarUrl = user['avatar_url'] as String?;
      currentUser = Map<String, dynamic>.from(user);
      selectedOwner = userLogin;
      tokenValidated = true;
      tokenStatus = userLogin == null ? 'Token 验证成功' : 'Token 验证成功：$userLogin';
      loading = false;

      if (userLogin != null) {
        _addOrUpdateAccount(userLogin, cleaned, avatarUrl ?? '');
      }

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
    selectedRepoFullName = '$owner/$repo';
    unawaited(SharedPreferences.getInstance().then((prefs) => prefs.setString('selected_repo_full_name', selectedRepoFullName!)));
    notifyListeners();
  }

  void clearRepositorySelection() {
    selectedOwner = null;
    selectedRepo = null;
    selectedRepoFullName = null;
    unawaited(SharedPreferences.getInstance().then((prefs) => prefs.remove('selected_repo_full_name')));
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

  Future<void> setBgOpacity(double value) async {
    bgOpacity = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bg_opacity', bgOpacity);
    notifyListeners();
  }

  void setBuildProfile(BuildProfile value) {
    buildProfile = value;
    notifyListeners();
  }

  Future<void> setCustomWorkflowFile(String? value) async {
    final cleaned = value?.trim();
    customWorkflowFile = cleaned == null || cleaned.isEmpty ? null : cleaned;
    final prefs = await SharedPreferences.getInstance();
    if (customWorkflowFile == null) {
      await prefs.remove('custom_workflow_file');
    } else {
      await prefs.setString('custom_workflow_file', customWorkflowFile!);
    }
    notifyListeners();
  }

  Future<void> setWorkflowRef(String value) async {
    workflowRef = value.trim().isEmpty ? 'main' : value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('workflow_ref', workflowRef);
    notifyListeners();
  }

  Future<void> setThemeVariant(String value) async {
    themeVariant = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_variant', value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', value.name);
    notifyListeners();
  }

  ThemeMode _themeModeFromName(String? name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}