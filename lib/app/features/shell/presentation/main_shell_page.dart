import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/core/routing/app_routes.dart';
import 'package:tgsorter/app/features/download/application/download_workbench_controller.dart';
import 'package:tgsorter/app/features/download/presentation/download_workbench_page.dart';
import 'package:tgsorter/app/features/login_alerts/application/login_alert_workbench_controller.dart';
import 'package:tgsorter/app/features/login_alerts/presentation/login_alert_workbench_page.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/presentation/pipeline_page.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';
import 'package:tgsorter/app/features/settings/application/settings_page_draft_session.dart';
import 'package:tgsorter/app/features/settings/application/settings_save_result.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/features/settings/presentation/logs_screen.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_app_bar.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_screen.dart';
import 'package:tgsorter/app/features/shell/presentation/main_shell_destination.dart';
import 'package:tgsorter/app/features/tagging/application/tagging_coordinator.dart';
import 'package:tgsorter/app/features/tagging/presentation/tagging_page.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({
    required this.pipeline,
    required this.tagging,
    required this.downloads,
    required this.loginAlerts,
    required this.pipelineSettings,
    required this.errors,
    required this.settings,
    this.pipelineLogs,
    super.key,
  });

  final PipelineCoordinator pipeline;
  final TaggingCoordinator tagging;
  final DownloadWorkbenchController downloads;
  final LoginAlertWorkbenchController loginAlerts;
  final PipelineSettingsReader pipelineSettings;
  final AppErrorController errors;
  final SettingsCoordinator settings;
  final PipelineLogsPort? pipelineLogs;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _settingsNavigation = SettingsNavigationController();
  final _settingsDraftSession = SettingsPageDraftSession();
  late MainShellDestination _current;
  Worker? _settingsWorker;

  @override
  void initState() {
    super.initState();
    _current = _resolveInitialDestination();
    _settingsWorker = ever<AppSettings>(widget.settings.savedSettings, (
      settings,
    ) {
      if (_current == MainShellDestination.downloads &&
          !settings.downloadWorkbenchEnabled) {
        setState(() {
          _current = _resolveInitialDestination();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      scaffoldKey: _scaffoldKey,
      drawer: Obx(
        () => _MainShellDrawer(
          current: _current,
          downloadWorkbenchEnabled:
              widget.settings.savedSettings.value.downloadWorkbenchEnabled,
          onSelected: _selectDestination,
        ),
      ),
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _current.index,
        children: [
          PipelineScreen(
            pipeline: widget.pipeline,
            settings: widget.pipelineSettings,
            errors: widget.errors,
          ),
          TaggingScreen(controller: widget.tagging, errors: widget.errors),
          LoginAlertWorkbenchPage(controller: widget.loginAlerts),
          DownloadWorkbenchScreen(controller: widget.downloads),
          SettingsScreen(
            controller: widget.settings,
            navigation: _settingsNavigation,
            draftSession: _settingsDraftSession,
            pipeline: widget.pipelineLogs,
            onLogoutSuccess: _handleLogoutSuccess,
          ),
          LogsScreen(pipeline: widget.pipelineLogs),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final leading = _DrawerMenuButton(onPressed: _openDrawer);
    switch (_current) {
      case MainShellDestination.forwardingWorkbench:
        return PipelineCompactAppBar(
          pipeline: widget.pipeline,
          leading: leading,
        );
      case MainShellDestination.taggingWorkbench:
        return TaggingCompactAppBar(
          controller: widget.tagging,
          leading: leading,
        );
      case MainShellDestination.loginAlerts:
        return SettingsAppBar(
          draftSession: _settingsDraftSession,
          isSaving: widget.settings.isSaving,
          navigation: _settingsNavigation,
          onSave: _saveSettings,
          canPopOverride: false,
          title: '接码',
          leading: leading,
        );
      case MainShellDestination.downloads:
        return SettingsAppBar(
          draftSession: _settingsDraftSession,
          isSaving: widget.settings.isSaving,
          navigation: _settingsNavigation,
          onSave: _saveSettings,
          canPopOverride: false,
          title: '下载工作台',
          leading: leading,
        );
      case MainShellDestination.settings:
        return SettingsAppBar(
          draftSession: _settingsDraftSession,
          isSaving: widget.settings.isSaving,
          navigation: _settingsNavigation,
          onSave: _saveSettings,
          leading: leading,
        );
      case MainShellDestination.logs:
        return SettingsAppBar(
          draftSession: _settingsDraftSession,
          isSaving: widget.settings.isSaving,
          navigation: _settingsNavigation,
          onSave: _saveSettings,
          canPopOverride: false,
          title: '操作日志',
          leading: leading,
        );
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _selectDestination(MainShellDestination destination) {
    if (destination == MainShellDestination.downloads &&
        !widget.settings.savedSettings.value.downloadWorkbenchEnabled) {
      Navigator.of(context).pop();
      return;
    }
    if (_current != destination) {
      setState(() {
        _current = destination;
      });
    }
    Navigator.of(context).pop();
  }

  Future<void> _saveSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    if (widget.settings.isSaving.value) {
      return;
    }
    try {
      final result = await widget.settings.savePageDraft(
        _settingsDraftSession.draftSettings.value,
      );
      _settingsDraftSession.markSaved(widget.settings.savedSettings.value);
      if (!mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(_saveMessage(result))));
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  MainShellDestination _resolveInitialDestination() {
    final defaultWorkbench =
        widget.settings.savedSettings.value.defaultWorkbench;
    if (defaultWorkbench == AppDefaultWorkbench.tagging) {
      return MainShellDestination.taggingWorkbench;
    }
    return MainShellDestination.forwardingWorkbench;
  }

  Future<void> _handleLogoutSuccess() async {
    await widget.pipeline.clearSessionStateForLogout();
    widget.tagging.clearSessionStateForLogout();
    if (!mounted) {
      return;
    }
    Get.offAllNamed(AppRoutes.auth);
  }

  @override
  void dispose() {
    _settingsWorker?.dispose();
    super.dispose();
  }

  String _saveMessage(SettingsSaveResult result) {
    switch (result) {
      case SettingsSaveResult.saved:
      case SettingsSaveResult.savedAndRestarted:
        return '设置已保存';
      case SettingsSaveResult.savedNeedsRestartAttention:
        return '设置已保存，但重启失败，请稍后手动重试。';
    }
  }
}

class _MainShellDrawer extends StatelessWidget {
  const _MainShellDrawer({
    required this.current,
    required this.downloadWorkbenchEnabled,
    required this.onSelected,
  });

  final MainShellDestination current;
  final bool downloadWorkbenchEnabled;
  final ValueChanged<MainShellDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppTokens.colorsOf(context);
    final destinations = _visibleDestinations();
    return Drawer(
      backgroundColor: colors.panelBackground,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'TgSorter',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '主工作区导航',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: AppTokens.spaceLg),
              for (final item in destinations)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
                  child: ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    selected: item == current,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusSmall,
                      ),
                    ),
                    onTap: () => onSelected(item),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<MainShellDestination> _visibleDestinations() {
    return MainShellDestination.values
        .where((item) {
          if (item == MainShellDestination.downloads) {
            return downloadWorkbenchEnabled;
          }
          return true;
        })
        .toList(growable: false);
  }
}

class _DrawerMenuButton extends StatelessWidget {
  const _DrawerMenuButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.menu_rounded),
      tooltip: '打开导航',
    );
  }
}
