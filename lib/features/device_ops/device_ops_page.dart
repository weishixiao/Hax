import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/device_ops_service.dart';
import '../../shared/widgets/section_card.dart';
import '../../theme/app_font_weights.dart';

/// 设备能力页：越狱环境探测、应用/进程选择、内存修改、dylib 注入。
class DeviceOpsPage extends StatefulWidget {
  const DeviceOpsPage({super.key});

  @override
  State<DeviceOpsPage> createState() => _DeviceOpsPageState();
}

class _DeviceOpsPageState extends State<DeviceOpsPage> {
  final DeviceOpsService _service = DeviceOpsService();
  final TextEditingController _pidController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _bundleController = TextEditingController();
  final TextEditingController _dylibController = TextEditingController();

  DeviceOpsProbe? _probe;
  DeviceProcess? _selectedProcess;
  DeviceApp? _selectedApp;
  List<MemoryHit> _hits = const <MemoryHit>[];
  String? _memoryError;
  String? _injectError;
  List<String> _injectSteps = const <String>[];
  int _width = 8;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshProbe();
  }

  @override
  void dispose() {
    _pidController.dispose();
    _valueController.dispose();
    _bundleController.dispose();
    _dylibController.dispose();
    super.dispose();
  }

  Future<void> _refreshProbe() async {
    final probe = await _service.probe();
    if (!mounted) return;
    setState(() => _probe = probe);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickProcess() async {
    final processes = await _service.listProcesses();
    final apps = await _service.listApps();
    if (!mounted) return;
    final picked = await showModalBottomSheet<DeviceProcess>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProcessPickerSheet(processes: processes, apps: apps),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedProcess = picked;
      _pidController.text = picked.pid.toString();
    });
  }

  Future<void> _pickApp() async {
    final apps = await _service.listApps();
    if (!mounted) return;
    final picked = await showModalBottomSheet<DeviceApp>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AppPickerSheet(apps: apps),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedApp = picked;
      _bundleController.text = picked.path;
    });
  }

  Future<void> _searchMemory() async {
    final pid = int.tryParse(_pidController.text.trim());
    final value = int.tryParse(_valueController.text.trim());
    if (pid == null || value == null) {
      _toast('先填 pid 和数值');
      return;
    }
    setState(() => _busy = true);
    final result = await _service.memSearch(
      pid: pid,
      value: value,
      width: _width,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _hits = result.hits;
      _memoryError = result.error;
    });
  }

  Future<void> _writeMemory(MemoryHit hit) async {
    final pid = int.tryParse(_pidController.text.trim());
    final value = int.tryParse(_valueController.text.trim());
    if (pid == null || value == null) return;
    setState(() => _busy = true);
    final error = await _service.memWrite(
      pid: pid,
      address: hit.address,
      value: value,
      width: _width,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(error ?? '已写入');
    await _searchMemory();
  }

  Future<void> _inject() async {
    final bundlePath = _bundleController.text.trim();
    final dylibPath = _dylibController.text.trim();
    if (bundlePath.isEmpty || dylibPath.isEmpty) {
      _toast('需要 App 路径和 dylib 路径');
      return;
    }
    setState(() {
      _busy = true;
      _injectSteps = const <String>[];
      _injectError = null;
    });
    final result = await _service.inject(
      bundlePath: bundlePath,
      dylibPath: dylibPath,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _injectSteps = result.steps;
      _injectError = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final probe = _probe;

    Widget statusRow(String label, String value, {bool good = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFontWeights.medium,
                color: good ? Colors.green : cs.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('设备能力 · 越狱环境')),
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
                    '运行环境',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (probe == null)
                    const Text('检测中…')
                  else ...<Widget>[
                    statusRow(
                      '越狱环境',
                      probe.jailbroken ? '已检测到' : '未检测到',
                      good: probe.jailbroken,
                    ),
                    statusRow(
                      'Rootless (/var/jb)',
                      probe.rootless ? '是' : '否',
                      good: probe.rootless,
                    ),
                    statusRow(
                      'TrollStore',
                      probe.trollstore ? '是' : '否',
                      good: probe.trollstore,
                    ),
                    statusRow(
                      'platform-application',
                      probe.platformApplication ? '有' : '无',
                      good: probe.platformApplication,
                    ),
                    statusRow(
                      'task_for_pid（跨进程内存）',
                      probe.canTaskForPid ? '可用' : '不可用',
                      good: probe.canTaskForPid,
                    ),
                    statusRow('uid', '${probe.uid}'),
                    statusRow('系统', probe.systemVersion),
                    statusRow('ldid', probe.ldid.isEmpty ? '未找到' : probe.ldid),
                    const SizedBox(height: 8),
                    Text(
                      probe.fullAccess
                          ? '当前已具备跨进程内存访问能力。'
                          : '没有 task_for_pid 权限：内存修改不可用。'
                                '需要设备越狱，或用 TrollStore 签名时加入 '
                                'task_for_pid-allow / platform-application 权限。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
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
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.apps),
                title: const Text('选择应用 / 进程'),
                subtitle: Text(
                  _selectedProcess == null
                      ? '列出已安装 App 与运行中的进程'
                      : '${_selectedProcess!.name} · pid ${_selectedProcess!.pid}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickProcess,
              ),
              ListTile(
                leading: const Icon(Icons.memory),
                title: const Text('内存搜索 / 修改'),
                subtitle: Text(
                  _hits.isEmpty
                      ? '按 pid + 数值搜索，命中后可直接改写'
                      : '命中 ${_hits.length} 处',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showMemorySheet(context),
              ),
              ListTile(
                leading: const Icon(Icons.extension),
                title: const Text('构建与注入'),
                subtitle: const Text('把 dylib 注入 App，写入 LC_LOAD_DYLIB 并重签'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showInjectSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showMemorySheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '内存修改',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _pidController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'pid'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _valueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '数值'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    const Text('宽度'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _width,
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem<int>(value: 2, child: Text('2 字节')),
                        DropdownMenuItem<int>(value: 4, child: Text('4 字节')),
                        DropdownMenuItem<int>(value: 8, child: Text('8 字节')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _width = value);
                        setSheetState(() {});
                      },
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await _searchMemory();
                              setSheetState(() {});
                            },
                      child: const Text('搜索'),
                    ),
                  ],
                ),
                if (_memoryError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _memoryError!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (_hits.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 220,
                    child: ListView.builder(
                      itemCount: _hits.length,
                      itemBuilder: (_, index) {
                        final hit = _hits[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            '0x${hit.address.toRadixString(16)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    await _writeMemory(hit);
                                    setSheetState(() {});
                                  },
                            child: const Text('改为当前值'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showInjectSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '构建与注入',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedApp != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '已选：${_selectedApp!.name}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                TextField(
                  controller: _bundleController,
                  decoration: InputDecoration(
                    labelText: 'App 路径',
                    hintText: '/var/containers/Bundle/Application/.../X.app',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.apps),
                      onPressed: () async {
                        await _pickApp();
                        setSheetState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _dylibController,
                  decoration: const InputDecoration(
                    labelText: 'dylib 路径',
                    hintText: '/var/jb/usr/lib/TweakInject/xxx.dylib',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await _inject();
                            setSheetState(() {});
                          },
                    child: const Text('执行注入'),
                  ),
                ),
                if (_injectError != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    _injectError!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                for (final step in _injectSteps)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '• $step',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 应用 / 进程选择弹窗（对话框选择应用进程）。
class _ProcessPickerSheet extends StatefulWidget {
  const _ProcessPickerSheet({required this.processes, required this.apps});

  final List<DeviceProcess> processes;
  final List<DeviceApp> apps;

  @override
  State<_ProcessPickerSheet> createState() => _ProcessPickerSheetState();
}

class _ProcessPickerSheetState extends State<_ProcessPickerSheet> {
  final TextEditingController _filter = TextEditingController();
  bool _showApps = false;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _filter.text.trim().toLowerCase();
    final processes = widget.processes
        .where((item) {
          if (keyword.isEmpty) return true;
          return item.name.toLowerCase().contains(keyword) ||
              item.path.toLowerCase().contains(keyword);
        })
        .toList(growable: false);
    final apps = widget.apps
        .where((item) {
          if (keyword.isEmpty) return true;
          return item.name.toLowerCase().contains(keyword) ||
              item.bundleId.toLowerCase().contains(keyword);
        })
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '选择应用 / 进程',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _showApps = !_showApps),
                  child: Text(_showApps ? '看进程' : '看应用'),
                ),
              ],
            ),
            TextField(
              controller: _filter,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: '搜索名称 / bundle id / 路径',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _showApps
                  ? ListView.builder(
                      itemCount: apps.length,
                      itemBuilder: (_, index) {
                        final app = apps[index];
                        return ListTile(
                          dense: true,
                          title: Text(app.name),
                          subtitle: Text(app.bundleId),
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: app.path),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制 App 路径')),
                            );
                          },
                        );
                      },
                    )
                  : ListView.builder(
                      itemCount: processes.length,
                      itemBuilder: (_, index) {
                        final process = processes[index];
                        return ListTile(
                          dense: true,
                          leading: Text('${process.pid}'),
                          title: Text(process.name),
                          subtitle: Text(
                            process.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(process),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppPickerSheet extends StatefulWidget {
  const _AppPickerSheet({required this.apps});

  final List<DeviceApp> apps;

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  final TextEditingController _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _filter.text.trim().toLowerCase();
    final apps = widget.apps
        .where((item) {
          if (keyword.isEmpty) return true;
          return item.name.toLowerCase().contains(keyword) ||
              item.bundleId.toLowerCase().contains(keyword);
        })
        .toList(growable: false);
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _filter,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: '搜索 App',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: apps.length,
                itemBuilder: (_, index) {
                  final app = apps[index];
                  return ListTile(
                    dense: true,
                    title: Text(app.name),
                    subtitle: Text(
                      '${app.bundleId}\n${app.path}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    onTap: () => Navigator.of(context).pop(app),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
