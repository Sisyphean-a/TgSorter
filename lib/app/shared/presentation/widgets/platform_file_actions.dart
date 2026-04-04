import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PlatformFileActions {
  const PlatformFileActions();

  bool canOpenFile(String? path) {
    return path != null && path.isNotEmpty;
  }

  bool canRevealInFolder(String? path) {
    return io.Platform.isWindows && canOpenFile(path);
  }

  bool canCopyPath(String? path) {
    return canOpenFile(path);
  }

  bool canOpenUrl(String? url) {
    return url != null && Uri.tryParse(url)?.hasScheme == true;
  }

  Future<void> openFile(BuildContext context, String path) async {
    final uri = Uri.file(path, windows: io.Platform.isWindows);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _showMessage(context, '打开文件失败');
    }
  }

  Future<void> revealInFolder(BuildContext context, String path) async {
    if (!io.Platform.isWindows) {
      if (context.mounted) {
        _showMessage(context, '当前平台暂不支持定位文件');
      }
      return;
    }
    try {
      await io.Process.run('explorer.exe', <String>['/select,', path]);
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, '定位文件失败');
      }
    }
  }

  Future<void> copyPath(BuildContext context, String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (context.mounted) {
      _showMessage(context, '路径已复制');
    }
  }

  Future<void> openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage(context, '链接无效');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _showMessage(context, '打开链接失败');
    }
  }

  Future<void> copyText(
    BuildContext context,
    String text, {
    String successMessage = '内容已复制',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      _showMessage(context, successMessage);
    }
  }

  void _showMessage(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
