import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/services/github_agent_service.dart';
import '../../../core/services/trollstore_service.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';

/// 开发工具：GitHub CI agent（替你改仓库）+ TrollStore 安装。
class DevToolsPage extends StatefulWidget {
  const DevToolsPage({super.key});

  @override
  State<DevToolsPage> createState() => _DevToolsPageState();
}

class _DevToolsPageState extends State<DevToolsPage> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _repoController = TextEditingController();
  final TextEditingController _taskController = TextEditingController();

  bool _obscureToken = true;
  bool _busy = false;
  String? _account;
  String? _status;
  bool? _trollStoreAvailable;
  String? _lastInstalled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _repoController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = await GitHubAgentService.token();
    final repo = await GitHubAgentService.repo();
    final available = await TrollStoreService.isAvailable();
    if (!mounted) return;
    setState(() {
      if (token.isNotEmpty) _tokenController.text = token;
      _repoController.text = repo;
      _trollStoreAvailable = available;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveToken() async {
    setState(() => _busy = true);
    try {
      await GitHubAgentService.setToken(_tokenController.text);
      await GitHubAgentService.setRepo(_repoController.text);
      final me = await GitHubAgentService.verify();
      if (!mounted) return;
      setState(() {
        _account = (me['login'] as String?) ?? '';
        _status = '已连接：$_account';
      });
      _toast('已保存');
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '$error');
      _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dispatch() async {
    final task = _taskController.text.trim();
    if (task.isEmpty) {
      _toast('先写任务');
      return;
    }
    setState(() {
      _busy = true;
      _status = '派发中…';
    });
    try {
      await GitHubAgentService.dispatchTask(task: task);
      await Future<void>.delayed(const Duration(seconds: 5));
      final run = await GitHubAgentService.latestRun();
      if (!mounted) return;
      setState(() {
        _status = run == null
            ? '已派发，但没读到运行记录'
            : '已派发：${run['status']} · ${run['html_url']}';
      });
      _toast('已派给 CI agent');
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '$error');
      _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshRun() async {
    setState(() => _busy = true);
    try {
      final run = await GitHubAgentService.latestRun();
      if (!mounted) return;
      setState(() {
        _status = run == null
            ? '暂无运行记录'
            : '${run['status']} / ${run['conclusion'] ?? '-'} · ${run['html_url']}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _installIpa() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.any,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final session = await TrollStoreService.installFile(path);
      if (!mounted) return;
      setState(() => _lastInstalled = '已交给 TrollStore：${session.fileName}');
      _toast('已唤起 TrollStore 安装');
    } catch (error) {
      if (!mounted) return;
      setState(() => _lastInstalled = '$error');
      _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('开发工具')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '让 AI 替你改仓库',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '本机只负责派发任务，真正的改动由仓库里的 '
                    '.github/workflows/agent-fix.yml 在 CI 上完成：'
                    '它只会推分支、开 PR，不会直接动 master。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tokenController,
                    obscureText: _obscureToken,
                    decoration: InputDecoration(
                      labelText: 'GitHub token（细粒度 PAT）',
                      hintText: 'github_pat_...',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureToken
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureToken = !_obscureToken),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _repoController,
                    decoration: const InputDecoration(
                      labelText: '仓库',
                      hintText: 'owner/repo',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      FilledButton.tonal(
                        onPressed: _busy ? null : _saveToken,
                        child: const Text('保存并验证'),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _account == null ? '未连接' : '已连接 $_account',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '任务',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _taskController,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: '例如：修复 iOS 构建里的 Swift 编译错误，并说明原因',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      FilledButton(
                        onPressed: _busy ? null : _dispatch,
                        child: const Text('派给 CI agent'),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: _busy ? null : _refreshRun,
                        child: const Text('刷新状态'),
                      ),
                    ],
                  ),
                  if (_status != null) ...<Widget>[
                    const SizedBox(height: 8),
                    SelectableText(
                      _status!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'TrollStore 安装',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _trollStoreAvailable == null
                        ? '检测中…'
                        : _trollStoreAvailable!
                        ? '已检测到 TrollStore，可直接安装未签名 IPA。'
                        : '未检测到 TrollStore（需要先装 TrollStore）。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: _busy || _trollStoreAvailable != true
                          ? null
                          : _installIpa,
                      child: const Text('选择 IPA 并安装'),
                    ),
                  ),
                  if (_lastInstalled != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _lastInstalled!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
