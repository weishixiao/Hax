import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// TrollStore 集成：把本地 IPA 用本机 HTTP 服务暴露出来，
/// 再交给 TrollStore 的 `apple-magnifier://install` 安装。
///
/// 不需要签名：TrollStore 走 CoreTrust 永久签名，安装后由它接管。
class TrollStoreService {
  const TrollStoreService._();

  static const String installScheme = 'apple-magnifier';

  static bool get supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// TrollStore 是否安装（能响应安装 URL scheme）。
  static Future<bool> isAvailable() async {
    if (!supportedPlatform) return false;
    try {
      return await canLaunchUrl(Uri.parse('$installScheme://'));
    } catch (_) {
      return false;
    }
  }

  /// 安装一个本地 IPA。返回本次使用的局域网地址，便于排查。
  static Future<TrollStoreInstallSession> installFile(
    String ipaPath, {
    Duration keepAlive = const Duration(minutes: 3),
  }) async {
    final file = File(ipaPath);
    if (!await file.exists()) {
      throw const FileSystemException('IPA 不存在', '');
    }
    final name = ipaPath.split(Platform.pathSeparator).last;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final url = 'http://127.0.0.1:${server.port}/${Uri.encodeComponent(name)}';

    final session = TrollStoreInstallSession(
      url: url,
      server: server,
      file: file,
      fileName: name,
    );
    session.start();

    final installUri = Uri.parse(
      '$installScheme://install?url=${Uri.encodeComponent(url)}',
    );
    final launched = await launchUrl(
      installUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      await session.stop();
      throw StateError('无法唤起 TrollStore，请确认已安装 TrollStore');
    }
    Timer(keepAlive, session.stop);
    return session;
  }
}

class TrollStoreInstallSession {
  TrollStoreInstallSession({
    required this.url,
    required this.server,
    required this.file,
    required this.fileName,
  });

  final String url;
  final HttpServer server;
  final File file;
  final String fileName;

  bool _served = false;
  bool _closed = false;

  /// 记录 TrollStore 是否真的来下载过（下载过基本等于安装流程已开始）。
  bool get served => _served;

  void start() {
    server.listen(
      (request) async {
        try {
          final response = request.response;
          final length = await file.length();
          response.headers
            ..set(HttpHeaders.contentTypeHeader, 'application/octet-stream')
            ..set(HttpHeaders.contentLengthHeader, '$length')
            ..set(
              HttpHeaders.contentDispositionHeader,
              'attachment; filename="$fileName"',
            );
          await response.addStream(file.openRead());
          await response.close();
          _served = true;
        } catch (_) {
          try {
            await request.response.close();
          } catch (_) {}
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    if (_closed) return;
    _closed = true;
    try {
      await server.close(force: true);
    } catch (_) {}
  }
}
