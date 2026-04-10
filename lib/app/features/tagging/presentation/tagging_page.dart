import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_screen_view_model.dart';
import 'package:tgsorter/app/features/tagging/application/tagging_coordinator.dart';
import 'package:tgsorter/app/features/tagging/presentation/tag_action_group.dart';
import 'package:tgsorter/app/features/workbench/presentation/message_workbench_view.dart';
import 'package:tgsorter/app/models/tag_config.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_error_panel.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class TaggingPage extends StatelessWidget {
  const TaggingPage({
    super.key,
    required this.controller,
    required this.errors,
  });

  final TaggingCoordinator controller;
  final AppErrorController errors;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      appBar: TaggingCompactAppBar(controller: controller),
      body: TaggingScreen(controller: controller, errors: errors),
    );
  }
}

class TaggingScreen extends StatelessWidget {
  const TaggingScreen({
    super.key,
    required this.controller,
    required this.errors,
  });

  final TaggingCoordinator controller;
  final AppErrorController errors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: AppErrorPanel(controller: errors),
        ),
        Expanded(child: Obx(_buildWorkbench)),
      ],
    );
  }

  Widget _buildWorkbench() {
    final vm = controller.screenVm;
    final enabled = vm.workflow.online && !vm.workflow.processingOverlay;
    return MessageWorkbenchView(
      vm: vm,
      directionText: 'latestFirst',
      actionArea: TagActionGroup(
        tags: _defaultTags(controller.tagGroups),
        enabled: enabled,
        onTagSelected: (tagName) => unawaited(controller.applyTag(tagName)),
      ),
      onNavigatePrevious: controller.showPreviousMessage,
      onNavigateNext: controller.showNextMessage,
      onSkip: controller.skipCurrent,
      onMediaAction: _ignoreMediaAction,
    );
  }

  List<TagConfig> _defaultTags(List<TagGroupConfig> groups) {
    if (groups.isEmpty) {
      return const [];
    }
    return groups.first.tags;
  }

  Future<void> _ignoreMediaAction(MediaAction action) async {}
}

class TaggingCompactAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const TaggingCompactAppBar({
    super.key,
    required this.controller,
    this.leading,
  });

  final TaggingCoordinator controller;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppTokens.colorsOf(context);
    return Material(
      color: colors.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 4)],
              Expanded(
                child: Text(
                  '标签工作台',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
