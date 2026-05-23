import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GithubService {
  final String token;
  static const _base = 'https://api.github.com';

  GithubService({required this.token});

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  Future<dynamic> _request(String method, String path, {Object? body}) async {
    final uri = Uri.parse('$_base$path');
    late http.Response res;
    final encoded = body == null ? null : jsonEncode(body);
    final headers = {..._headers, if (body != null) 'Content-Type': 'application/json'};
    try {
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
          break;
        case 'POST':
          res = await http.post(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 15));
          break;
        case 'PUT':
          res = await http.put(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 15));
          break;
        case 'PATCH':
          res = await http.patch(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 15));
          break;
        default:
          throw UnsupportedError(method);
      }
    } on TimeoutException {
      throw Exception('GitHub API 请求超时：$uri');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    throw Exception('GitHub API ${res.statusCode}: ${res.body}');
  }

  Future<Map<String, dynamic>> getCurrentUser() async => Map<String, dynamic>.from(await _request('GET', '/user'));

  Future<List<Map<String, dynamic>>> listStarredRepositories({int perPage = 100}) async {
    final data = await _request('GET', '/user/starred?per_page=$perPage&sort=updated');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> listFollowers(String user, {int perPage = 30}) async {
    final data = await _request('GET', '/users/$user/followers?per_page=$perPage');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> listFollowing(String user, {int perPage = 30}) async {
    final data = await _request('GET', '/users/$user/following?per_page=$perPage');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> listRepositories() async {
    final data = await _request('GET', '/user/repos?per_page=100&type=owner&sort=updated');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> createRepository({required String name, required bool private, required bool autoInit, String? description, String? licenseTemplate}) async {
    return Map<String, dynamic>.from(await _request('POST', '/user/repos', body: {
      'name': name,
      'private': private,
      'auto_init': autoInit,
      if (description != null && description.isNotEmpty) 'description': description,
      if (licenseTemplate != null && licenseTemplate.isNotEmpty) 'license_template': licenseTemplate,
    }));
  }

  String _contentPath(String path) => path.split('/').map(Uri.encodeComponent).join('/');

  Future<List<Map<String, dynamic>>> getContents(String owner, String repo, {String path = ''}) async {
    final safePath = path.isEmpty ? '' : '/${_contentPath(path)}';
    final data = await _request('GET', '/repos/$owner/$repo/contents$safePath');
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [Map<String, dynamic>.from(data as Map)];
  }

  Future<Map<String, dynamic>> getFile(String owner, String repo, String path) async => Map<String, dynamic>.from(await _request('GET', '/repos/$owner/$repo/contents/${_contentPath(path)}'));

  Future<void> putFile({required String owner, required String repo, required String path, required String message, required String contentBase64, String? sha}) async {
    await _request('PUT', '/repos/$owner/$repo/contents/${_contentPath(path)}', body: {'message': message, 'content': contentBase64, if (sha != null) 'sha': sha});
  }

  Future<void> deleteFile({required String owner, required String repo, required String path, required String message, required String sha}) async {
    await _request('DELETE', '/repos/$owner/$repo/contents/${_contentPath(path)}', body: {'message': message, 'sha': sha});
  }

  Future<void> dispatchWorkflow({required String owner, required String repo, required String workflowFile, String ref = 'main', required Map<String, dynamic> inputs}) async {
    await _request('POST', '/repos/$owner/$repo/actions/workflows/$workflowFile/dispatches', body: {'ref': ref, 'inputs': inputs});
  }

  Future<List<Map<String, dynamic>>> listWorkflows(String owner, String repo) async {
    final data = await _request('GET', '/repos/$owner/$repo/actions/workflows');
    return List<Map<String, dynamic>>.from(data['workflows'] as List);
  }

  Future<String> dispatchBestBuildWorkflow({required String owner, required String repo, String ref = 'main', required Map<String, dynamic> inputs}) async {
    final workflows = await listWorkflows(owner, repo);
    final candidates = ['android-apk.yml', 'build.yml', 'cmake.yml'];
    for (final candidate in candidates) {
      final found = workflows.where((w) => w['path']?.toString().endsWith('/$candidate') == true).toList();
      if (found.isNotEmpty) {
        await dispatchWorkflow(owner: owner, repo: repo, workflowFile: candidate, ref: ref, inputs: candidate == 'cmake.yml' ? {} : inputs);
        return candidate;
      }
    }
    throw Exception('未找到可触发的工作流，请先创建 android-apk.yml、build.yml 或 cmake.yml');
  }

  Future<List<Map<String, dynamic>>> listWorkflowRuns(String owner, String repo) async {
    final data = await _request('GET', '/repos/$owner/$repo/actions/runs?per_page=20');
    return List<Map<String, dynamic>>.from(data['workflow_runs'] as List);
  }

  Future<List<Map<String, dynamic>>> listArtifacts(String owner, String repo, int runId) async {
    final data = await _request('GET', '/repos/$owner/$repo/actions/runs/$runId/artifacts');
    return List<Map<String, dynamic>>.from(data['artifacts'] as List);
  }

  Future<List<Map<String, dynamic>>> listWorkflowJobs(String owner, String repo, int runId) async {
    final data = await _request('GET', '/repos/$owner/$repo/actions/runs/$runId/jobs');
    return List<Map<String, dynamic>>.from(data['jobs'] as List);
  }

  Future<Uint8List> downloadRunLogs(String owner, String repo, int runId) async {
    final res = await http.get(Uri.parse('$_base/repos/$owner/$repo/actions/runs/$runId/logs'), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
    throw Exception('下载日志失败 ${res.statusCode}: ${res.body}');
  }

  Future<Map<String, dynamic>> createRelease({required String owner, required String repo, required String tagName, required String name, required String body, bool prerelease = false}) async {
    return Map<String, dynamic>.from(await _request('POST', '/repos/$owner/$repo/releases', body: {'tag_name': tagName, 'name': name, 'body': body, 'prerelease': prerelease}));
  }

  Future<List<Map<String, dynamic>>> listReleases(String owner, String repo) async {
    final data = await _request('GET', '/repos/$owner/$repo/releases?per_page=30');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> uploadReleaseAsset({required String uploadUrl, required String name, required List<int> bytes}) async {
    final base = uploadUrl.split('{').first;
    final uri = Uri.parse('$base?name=${Uri.encodeQueryComponent(name)}');
    final res = await http.post(uri, headers: {..._headers, 'Content-Type': 'application/octet-stream'}, body: bytes).timeout(const Duration(seconds: 60));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('上传发行文件失败 ${res.statusCode}: ${res.body}');
    }
  }

  /// 通用 GitHub REST API 调用（供 AI 工具使用）
  Future<dynamic> rawRequest(String method, String endpoint, {Map<String, dynamic>? body}) async {
    return _request(method, endpoint, body: body);
  }

  /// 删除仓库（不可逆）
  Future<void> deleteRepository(String owner, String repo) async {
    await _request('DELETE', '/repos/$owner/$repo');
  }

  /// 重命名仓库
  Future<Map<String, dynamic>> renameRepository(
      String owner, String repo, String newName) async {
    return Map<String, dynamic>.from(
        await _request('PATCH', '/repos/$owner/$repo', body: {'name': newName}));
  }
}