import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// GitHub「让 AI 替我改仓库」通道。
///
/// 本机不跑 agent，只负责把任务派给仓库里的
/// `.github/workflows/agent-fix.yml`（CI agent），再回读运行状态/PR。
class GitHubAgentService {
  const GitHubAgentService._();

  static const String _tokenKey = 'github_agent_token_v1';
  static const String _repoKey = 'github_agent_repo_v1';
  static const String _workflowKey = 'github_agent_workflow_v1';
  static const String defaultWorkflow = 'agent-fix.yml';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static Future<String> token() async =>
      (await _prefs).getString(_tokenKey) ?? '';

  static Future<void> setToken(String value) async {
    final prefs = await _prefs;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, trimmed);
    }
  }

  static Future<String> repo() async {
    final value = (await _prefs).getString(_repoKey);
    if (value != null && value.trim().isNotEmpty) return value.trim();
    return 'weishixiao/Hax';
  }

  static Future<void> setRepo(String value) async {
    final prefs = await _prefs;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_repoKey);
    } else {
      await prefs.setString(_repoKey, trimmed);
    }
  }

  static Future<String> workflow() async {
    final value = (await _prefs).getString(_workflowKey);
    if (value != null && value.trim().isNotEmpty) return value.trim();
    return defaultWorkflow;
  }

  static Future<void> setWorkflow(String value) async {
    final prefs = await _prefs;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_workflowKey);
    } else {
      await prefs.setString(_workflowKey, trimmed);
    }
  }

  static Future<Map<String, String>> _headers(String token) async => {
    'Accept': 'application/vnd.github+json',
    'Authorization': 'Bearer $token',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json',
  };

  static Future<http.Response> _call(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await token();
    if (token.isEmpty) {
      throw StateError('还没有配置 GitHub token');
    }
    final uri = Uri.parse('https://api.github.com$path');
    final headers = await _headers(token);
    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      case 'PUT':
        return http.put(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      default:
        throw ArgumentError('unsupported method $method');
    }
  }

  /// 校验 token 并返回账号信息。
  static Future<Map<String, dynamic>> verify() async {
    final response = await _call('GET', '/user');
    if (response.statusCode != 200) {
      throw StateError('token 无效：HTTP ${response.statusCode}');
    }
    return _decode(response);
  }

  /// 当前 token 对目标仓库的权限（无法读取时返回空 map）。
  static Future<Map<String, dynamic>> repoInfo({String? repository}) async {
    final target = repository ?? await repo();
    final response = await _call('GET', '/repos/$target');
    if (response.statusCode != 200) return <String, dynamic>{};
    return _decode(response);
  }

  /// 派发 CI agent 任务。
  static Future<void> dispatchTask({
    required String task,
    String? repository,
    String? ref,
    Map<String, String>? extraInputs,
  }) async {
    final target = repository ?? await repo();
    final workflowFile = await workflow();
    final branch = ref ?? 'master';
    final response = await _call(
      'POST',
      '/repos/$target/actions/workflows/$workflowFile/dispatches',
      body: {
        'ref': branch,
        'inputs': {'task': task, ...?extraInputs},
      },
    );
    if (response.statusCode != 204) {
      throw StateError('派发失败：HTTP ${response.statusCode} ${response.body}');
    }
  }

  /// 最近一次 agent 运行。
  static Future<Map<String, dynamic>?> latestRun({String? repository}) async {
    final target = repository ?? await repo();
    final workflowFile = await workflow();
    final response = await _call(
      'GET',
      '/repos/$target/actions/workflows/$workflowFile/runs?per_page=1',
    );
    if (response.statusCode != 200) return null;
    final data = _decode(response);
    final runs = data['workflow_runs'];
    if (runs is List && runs.isNotEmpty) {
      return Map<String, dynamic>.from(runs.first as Map);
    }
    return null;
  }

  /// 读取一次运行的 job 列表。
  static Future<List<Map<String, dynamic>>> runJobs({
    required int runId,
    String? repository,
  }) async {
    final target = repository ?? await repo();
    final response = await _call(
      'GET',
      '/repos/$target/actions/runs/$runId/jobs',
    );
    if (response.statusCode != 200) return const <Map<String, dynamic>>[];
    final data = _decode(response);
    final jobs = data['jobs'];
    if (jobs is! List) return const <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[
      for (final job in jobs)
        if (job is Map) Map<String, dynamic>.from(job),
    ];
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }
}
