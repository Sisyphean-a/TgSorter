import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_content.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_helpers.dart';

class MessageViewerCard extends StatelessWidget {
  const MessageViewerCard({
    super.key,
    required this.message,
    required this.processing,
    required this.videoPreparing,
    required this.onRequestMediaPlayback,
    this.videoControllerInitializer,
    this.isMediaPreparing = _defaultIsMediaPreparing,
  });

  final PipelineMessage? message;
  final bool processing;
  final bool videoPreparing;
  final Future<void> Function([int? messageId]) onRequestMediaPlayback;
  final VideoControllerInitializer? videoControllerInitializer;
  final bool Function(int? messageId) isMediaPreparing;

  static bool _defaultIsMediaPreparing(int? messageId) => false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppTokens.quick,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppTokens.surfaceBase,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(
          color: processing ? AppTokens.brandAccent : AppTokens.borderSubtle,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.spaceLg),
              child: MessagePreviewContent(
                message: message,
                videoPreparing: videoPreparing,
                onRequestMediaPlayback: onRequestMediaPlayback,
                videoControllerInitializer: videoControllerInitializer,
                isMediaPreparing: isMediaPreparing,
              ),
            ),
          ),
          if (processing)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
