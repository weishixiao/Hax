import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 设备能力桥（iOS 原生 app.device_ops 通道）。
///
/// 所有调用都可能因为「没有越狱 / 没有 entitlements」而失败，
/// 失败时返回结构化错误，UI 负责把它展示成提示。
class DeviceOpsService {
  DeviceOpsService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app.device_ops');

  final MethodChannel _channel;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<Map<String, dynamic>> _invoke(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    final raw = await _channel.invokeMethod<Object?>(method, args);
    if (raw is Map) return raw.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  Future<DeviceOpsProbe> probe() async {
    if (!isSupported) return const DeviceOpsProbe.unsupported();
    try {
      return DeviceOpsProbe.fromMap(await _invoke('probe'));
    } on PlatformException {
      return const DeviceOpsProbe.unsupported();
    } on MissingPluginException {
      return const DeviceOpsProbe.unsupported();
    }
  }

  Future<List<DeviceApp>> listApps() async {
    if (!isSupported) return const <DeviceApp>[];
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('listApps');
      return <DeviceApp>[
        for (final item in raw ?? const <Object?>[])
          if (item is Map) DeviceApp.fromMap(item.cast<String, dynamic>()),
      ];
    } catch (_) {
      return const <DeviceApp>[];
    }
  }

  Future<List<DeviceProcess>> listProcesses() async {
    if (!isSupported) return const <DeviceProcess>[];
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('listProcesses');
      return <DeviceProcess>[
        for (final item in raw ?? const <Object?>[])
          if (item is Map) DeviceProcess.fromMap(item.cast<String, dynamic>()),
      ];
    } catch (_) {
      return const <DeviceProcess>[];
    }
  }

  Future<String?> kill(int pid) async {
    final result = await _invoke('kill', <String, dynamic>{'pid': pid});
    return result['error'] as String?;
  }

  Future<MemorySearchResult> memSearch({
    required int pid,
    required int value,
    int width = 8,
    int limit = 64,
  }) async {
    final result = await _invoke('memSearch', <String, dynamic>{
      'pid': pid,
      'value': value,
      'width': width,
      'limit': limit,
    });
    return MemorySearchResult.fromMap(result);
  }

  Future<String?> memWrite({
    required int pid,
    required int address,
    required int value,
    int width = 8,
  }) async {
    final result = await _invoke('memWrite', <String, dynamic>{
      'pid': pid,
      'address': address,
      'value': value,
      'width': width,
    });
    return result['ok'] == true ? null : (result['error'] as String? ?? '写入失败');
  }

  Future<InjectionResult> inject({
    required String bundlePath,
    required String dylibPath,
  }) async {
    final result = await _invoke('inject', <String, dynamic>{
      'bundlePath': bundlePath,
      'dylibPath': dylibPath,
    });
    return InjectionResult.fromMap(result);
  }

  Future<Map<String, dynamic>> bundleInfo(String path) =>
      _invoke('bundleInfo', <String, dynamic>{'path': path});
}

class DeviceOpsProbe {
  const DeviceOpsProbe({
    required this.supported,
    required this.jailbroken,
    required this.rootless,
    required this.trollstore,
    required this.platformApplication,
    required this.canTaskForPid,
    required this.uid,
    required this.sandbox,
    required this.systemVersion,
    required this.ldid,
  });

  const DeviceOpsProbe.unsupported()
    : supported = false,
      jailbroken = false,
      rootless = false,
      trollstore = false,
      platformApplication = false,
      canTaskForPid = false,
      uid = -1,
      sandbox = '',
      systemVersion = '',
      ldid = '';

  final bool supported;
  final bool jailbroken;
  final bool rootless;
  final bool trollstore;
  final bool platformApplication;
  final bool canTaskForPid;
  final int uid;
  final String sandbox;
  final String systemVersion;
  final String ldid;

  bool get fullAccess => canTaskForPid;

  factory DeviceOpsProbe.fromMap(Map<String, dynamic> map) {
    return DeviceOpsProbe(
      supported: true,
      jailbroken: map['jailbroken'] == true,
      rootless: map['rootless'] == true,
      trollstore: map['trollstore'] == true,
      platformApplication: map['platformApplication'] == true,
      canTaskForPid: map['canTaskForPid'] == true,
      uid: (map['uid'] as num?)?.toInt() ?? -1,
      sandbox: (map['sandbox'] as String?) ?? '',
      systemVersion: (map['systemVersion'] as String?) ?? '',
      ldid: (map['ldid'] as String?) ?? '',
    );
  }
}

class DeviceApp {
  const DeviceApp({
    required this.bundleId,
    required this.name,
    required this.path,
  });

  final String bundleId;
  final String name;
  final String path;

  factory DeviceApp.fromMap(Map<String, dynamic> map) => DeviceApp(
    bundleId: (map['bundleId'] as String?) ?? '',
    name: (map['name'] as String?) ?? '',
    path: (map['path'] as String?) ?? '',
  );
}

class DeviceProcess {
  const DeviceProcess({
    required this.pid,
    required this.name,
    required this.path,
  });

  final int pid;
  final String name;
  final String path;

  factory DeviceProcess.fromMap(Map<String, dynamic> map) => DeviceProcess(
    pid: (map['pid'] as num?)?.toInt() ?? 0,
    name: (map['name'] as String?) ?? '',
    path: (map['path'] as String?) ?? '',
  );
}

class MemoryHit {
  const MemoryHit({required this.address, required this.value});

  final int address;
  final int value;

  factory MemoryHit.fromMap(Map<String, dynamic> map) => MemoryHit(
    address: (map['address'] as num?)?.toInt() ?? 0,
    value: (map['value'] as num?)?.toInt() ?? 0,
  );
}

class MemorySearchResult {
  const MemorySearchResult({required this.hits, required this.error});

  final List<MemoryHit> hits;
  final String? error;

  factory MemorySearchResult.fromMap(Map<String, dynamic> map) {
    final raw = map['hits'];
    return MemorySearchResult(
      hits: <MemoryHit>[
        if (raw is List)
          for (final item in raw)
            if (item is Map) MemoryHit.fromMap(item.cast<String, dynamic>()),
      ],
      error: map['error'] as String?,
    );
  }
}

class InjectionResult {
  const InjectionResult({required this.ok, required this.steps, this.error});

  final bool ok;
  final List<String> steps;
  final String? error;

  factory InjectionResult.fromMap(Map<String, dynamic> map) {
    final raw = map['steps'];
    return InjectionResult(
      ok: map['ok'] == true,
      steps: <String>[
        if (raw is List)
          for (final item in raw) item.toString(),
      ],
      error: map['error'] as String?,
    );
  }
}
