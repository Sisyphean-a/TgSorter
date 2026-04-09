import 'dart:io' as io;

import 'package:flutter/services.dart';
import 'package:tgsorter/app/services/platform_resource_service.dart';
import 'package:url_launcher/url_launcher.dart';

typedef UriLauncher = Future<bool> Function(Uri uri);
typedef ClipboardWriter = Future<void> Function(String text);
typedef FileRevealer = Future<void> Function(String path);

class DefaultPlatformResourceService implements PlatformResourceService {
  DefaultPlatformResourceService({
    UriLauncher? launchUri,
    ClipboardWriter? copyText,
    FileRevealer? revealFile,
    bool? isWindows,
  }) : _launchUri = launchUri ?? _launchExternalUri,
       _copyText = copyText ?? _writeClipboardText,
       _revealFile = revealFile ?? _revealFileInShell,
       _isWindows = isWindows ?? io.Platform.isWindows;

  final UriLauncher _launchUri;
  final ClipboardWriter _copyText;
  final FileRevealer _revealFile;
  final bool _isWindows;

  @override
  Future<ActionResult> openResource(LocalResource resource) async {
    if (!resource.hasPath) {
      return const ActionResult(success: false, message: '文件路径无效');
    }
    try {
      final uri = Uri.file(resource.path, windows: _isWindows);
      final ok = await _launchUri(uri);
      return ok
          ? const ActionResult(success: true)
          : const ActionResult(success: false, message: '打开文件失败');
    } catch (_) {
      return const ActionResult(success: false, message: '打开文件失败');
    }
  }

  @override
  Future<ActionResult> revealResource(LocalResource resource) async {
    if (!resource.hasPath) {
      return const ActionResult(success: false, message: '文件路径无效');
    }
    if (!_isWindows) {
      return const ActionResult(success: false, message: '当前平台暂不支持定位文件');
    }
    try {
      await _revealFile(resource.path);
      return const ActionResult(success: true);
    } catch (_) {
      return const ActionResult(success: false, message: '定位文件失败');
    }
  }

  @override
  Future<ActionResult> copyPath(LocalResource resource) async {
    if (!resource.hasPath) {
      return const ActionResult(success: false, message: '文件路径无效');
    }
    try {
      await _copyText(resource.path);
      return const ActionResult(success: true, message: '路径已复制');
    } catch (_) {
      return const ActionResult(success: false, message: '复制路径失败');
    }
  }

  @override
  Future<ActionResult> openUrl(Uri url) async {
    if (!url.hasScheme) {
      return const ActionResult(success: false, message: '链接无效');
    }
    try {
      final ok = await _launchUri(url);
      return ok
          ? const ActionResult(success: true)
          : const ActionResult(success: false, message: '打开链接失败');
    } catch (_) {
      return const ActionResult(success: false, message: '打开链接失败');
    }
  }
}

Future<bool> _launchExternalUri(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _writeClipboardText(String text) {
  return Clipboard.setData(ClipboardData(text: text));
}

Future<void> _revealFileInShell(String path) async {
  await io.Process.run('explorer.exe', <String>['/select,', path]);
}
