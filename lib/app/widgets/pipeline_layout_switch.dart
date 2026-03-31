import 'package:flutter/widgets.dart';

class PipelineLayoutSwitch extends StatelessWidget {
  const PipelineLayoutSwitch({
    super.key,
    required this.mobile,
    required this.desktop,
  });

  static const double desktopMinWidth = 1000;

  final Widget mobile;
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= desktopMinWidth) {
          return desktop;
        }
        return mobile;
      },
    );
  }
}
