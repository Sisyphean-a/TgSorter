import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

class MessageViewerCard extends StatelessWidget {
  const MessageViewerCard({
    super.key,
    required this.message,
    required this.processing,
  });

  final PipelineMessage? message;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildContent(),
            ),
          ),
          if (processing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final data = message;
    if (data == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 100),
          Icon(Icons.check_circle, color: Colors.green, size: 96),
          SizedBox(height: 16),
          Text('收藏夹已清空，干得漂亮！', style: TextStyle(fontSize: 18)),
        ],
      );
    }

    final preview = data.preview;
    if (preview.kind == MessagePreviewKind.photo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhoto(preview.localImagePath),
          const SizedBox(height: 12),
          Text(preview.title, style: const TextStyle(fontSize: 16)),
        ],
      );
    }

    return Text(preview.title, style: const TextStyle(fontSize: 18, height: 1.4));
  }

  Widget _buildPhoto(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return Container(
        width: double.infinity,
        height: 240,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Text('图片已识别（本地文件未就绪）'),
      );
    }

    return Image.file(
      io.File(imagePath),
      width: double.infinity,
      height: 240,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: 240,
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Text('图片加载失败'),
        );
      },
    );
  }
}
