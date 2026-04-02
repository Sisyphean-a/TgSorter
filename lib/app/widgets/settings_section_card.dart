import 'package:flutter/material.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.highlighted = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeader = trailing != null && constraints.maxWidth < 520;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (compactHeader)
                  _CompactHeader(
                    title: title,
                    subtitle: subtitle,
                    trailing: trailing!,
                    highlighted: highlighted,
                  )
                else
                  _InlineHeader(
                    title: title,
                    subtitle: subtitle,
                    trailing: trailing,
                    highlighted: highlighted,
                  ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InlineHeader extends StatelessWidget {
  const _InlineHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.highlighted,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SectionTitle(title: title, subtitle: subtitle)),
        if (highlighted)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: _DirtyBadge(),
          ),
        ..._buildTrailingWidgets(),
      ],
    );
  }

  List<Widget> _buildTrailingWidgets() {
    if (trailing == null) {
      return const [];
    }
    return [trailing!];
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.highlighted,
  });

  final String title;
  final String? subtitle;
  final Widget trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _SectionTitle(title: title, subtitle: subtitle)),
            if (highlighted) const _DirtyBadge(),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: trailing,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16)),
        if (subtitle case String text)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _DirtyBadge extends StatelessWidget {
  const _DirtyBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '已修改',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}
