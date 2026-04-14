import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_app_exit_coordinator.dart';

class TdlibExitGuard extends StatefulWidget {
  const TdlibExitGuard({super.key, required this.child});

  final Widget child;

  @override
  State<TdlibExitGuard> createState() => _TdlibExitGuardState();
}

class _TdlibExitGuardState extends State<TdlibExitGuard> {
  TdlibAppExitCoordinator? _coordinator;
  AppLifecycleListener? _listener;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TdlibAdapter>()) {
      return;
    }
    final adapter = Get.find<TdlibAdapter>();
    _coordinator = TdlibAppExitCoordinator(close: adapter.close);
    _listener = AppLifecycleListener(
      onExitRequested: _coordinator!.requestExit,
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
