import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const double _wideThreshold = 1.2;
const double _narrowThreshold = 0.8;
const double _complexRatioThreshold = 2.0;
const double _wideAverageMultiplier = 1.4;
const double _topAndOtherHeightFactor = 0.66;
const double _leftColumnWidthFactor = 0.6;
const double _topRowWidthFactor = 0.4;
const double _middleRowWidthFactor = 0.33;
const double _minCroppedRatio = 0.6667;
const double _maxCroppedRatio = 2.75;
const double _complexAverageRatioSplit = 1.1;
const double _portraitAverageRatioSplit = 0.85;
const double _smallLinePenalty = 1.5;
const int _maxItemsPerRow = 3;
const int _maxItemsPerMiddlePortraitRow = 4;

class TelegramMediaGroupLayoutItem {
  const TelegramMediaGroupLayoutItem({
    required this.geometry,
    required this.isTop,
    required this.isRight,
    required this.isBottom,
    required this.isLeft,
  });

  final Rect geometry;
  final bool isTop;
  final bool isRight;
  final bool isBottom;
  final bool isLeft;
}

class TelegramMediaGroupLayout {
  const TelegramMediaGroupLayout({
    required this.items,
    required this.height,
    required this.rowCounts,
  });

  final List<TelegramMediaGroupLayoutItem> items;
  final double height;
  final List<int> rowCounts;
}

TelegramMediaGroupLayout computeTelegramMediaGroupLayout({
  required List<double> aspectRatios,
  required double maxWidth,
  required double minWidth,
  required double spacing,
}) {
  if (aspectRatios.isEmpty) {
    return const TelegramMediaGroupLayout(
      items: <TelegramMediaGroupLayoutItem>[],
      height: 0,
      rowCounts: <int>[],
    );
  }
  final layouter = _TelegramMediaGroupLayouter(
    ratios: aspectRatios,
    maxWidth: maxWidth,
    minWidth: minWidth,
    spacing: spacing,
  );
  return layouter.layout();
}

class _TelegramMediaGroupLayouter {
  const _TelegramMediaGroupLayouter({
    required this.ratios,
    required this.maxWidth,
    required this.minWidth,
    required this.spacing,
  });

  final List<double> ratios;
  final double maxWidth;
  final double minWidth;
  final double spacing;

  TelegramMediaGroupLayout layout() {
    if (ratios.length == 1) {
      return _single();
    }
    if (_useComplexLayout()) {
      return _complex();
    }
    if (ratios.length == 2) {
      return _layoutTwo();
    }
    if (ratios.length == 3) {
      return _layoutThree();
    }
    return _layoutFour();
  }

  double get averageRatio =>
      ratios.reduce((sum, value) => sum + value) / ratios.length;

  bool _useComplexLayout() {
    return ratios.length >= 5 ||
        ratios.any((ratio) => ratio > _complexRatioThreshold);
  }

  String _proportions() {
    return ratios.map((ratio) {
      if (ratio > _wideThreshold) {
        return 'w';
      }
      if (ratio < _narrowThreshold) {
        return 'n';
      }
      return 'q';
    }).join();
  }

  TelegramMediaGroupLayout _single() {
    final height = maxWidth / ratios.first;
    return TelegramMediaGroupLayout(
      items: <TelegramMediaGroupLayoutItem>[
        TelegramMediaGroupLayoutItem(
          geometry: Rect.fromLTWH(0, 0, maxWidth, height),
          isTop: true,
          isRight: true,
          isBottom: true,
          isLeft: true,
        ),
      ],
      height: height,
      rowCounts: const <int>[1],
    );
  }

  TelegramMediaGroupLayout _layoutTwo() {
    final proportions = _proportions();
    final maxSizeRatio = 1.0;
    if (proportions == 'ww' &&
        averageRatio > _wideAverageMultiplier * maxSizeRatio &&
        (ratios[1] - ratios[0]).abs() < 0.2) {
      return _buildRows(const [1, 1], _twoTopBottomHeights());
    }
    if (proportions == 'ww' || proportions == 'qq') {
      return _buildRows(const [2], _twoEqualHeights());
    }
    return _buildRows(const [2], _twoMixedHeights());
  }

  TelegramMediaGroupLayout _layoutThree() {
    return _proportions().startsWith('n')
        ? _threeLeftAndOther()
        : _threeTopAndOther();
  }

  TelegramMediaGroupLayout _layoutFour() {
    return _proportions().startsWith('w')
        ? _fourTopAndOther()
        : _fourLeftAndOther();
  }

  List<double> _twoTopBottomHeights() {
    final height = math.min(
      maxWidth / ratios[0],
      math.min(maxWidth / ratios[1], (maxWidth - spacing) / 2),
    );
    return <double>[height, height];
  }

  List<double> _twoEqualHeights() {
    final width = (maxWidth - spacing) / 2;
    final height = math.min(
      width / ratios[0],
      math.min(width / ratios[1], maxWidth),
    );
    return <double>[height];
  }

  List<double> _twoMixedHeights() {
    final minimalWidth = minWidth * 1.5;
    final secondWidth = math.min(
      math.max(
        0.4 * (maxWidth - spacing),
        (maxWidth - spacing) /
            ratios[0] /
            ((1 / ratios[0]) + (1 / ratios[1])),
      ),
      maxWidth - spacing - minimalWidth,
    );
    final firstWidth = maxWidth - secondWidth - spacing;
    final height = math.min(
      maxWidth,
      math.min(firstWidth / ratios[0], secondWidth / ratios[1]),
    );
    return <double>[height];
  }

  TelegramMediaGroupLayout _threeLeftAndOther() {
    final thirdHeight = math.min(
      (maxWidth - spacing) / 2,
      ratios[1] * (maxWidth - spacing) / (ratios[2] + ratios[1]),
    );
    final secondHeight = maxWidth - thirdHeight - spacing;
    final rightWidth = math.max(
      minWidth,
      math.min(
        (maxWidth - spacing) / 2,
        math.min(thirdHeight * ratios[2], secondHeight * ratios[1]),
      ),
    );
    final leftWidth = math.min(
      maxWidth * ratios[0],
      maxWidth - spacing - rightWidth,
    );
    return _manualLayout(
      <Rect>[
        Rect.fromLTWH(0, 0, leftWidth, maxWidth),
        Rect.fromLTWH(leftWidth + spacing, 0, rightWidth, secondHeight),
        Rect.fromLTWH(
          leftWidth + spacing,
          secondHeight + spacing,
          rightWidth,
          thirdHeight,
        ),
      ],
      const [1, 1, 1],
    );
  }

  TelegramMediaGroupLayout _threeTopAndOther() {
    final firstHeight = math.min(
      maxWidth / ratios[0],
      (maxWidth - spacing) * _topAndOtherHeightFactor,
    );
    final secondWidth = (maxWidth - spacing) / 2;
    final secondHeight = math.min(
      maxWidth - firstHeight - spacing,
      math.min(secondWidth / ratios[1], secondWidth / ratios[2]),
    );
    final thirdWidth = maxWidth - secondWidth - spacing;
    return _manualLayout(
      <Rect>[
        Rect.fromLTWH(0, 0, maxWidth, firstHeight),
        Rect.fromLTWH(0, firstHeight + spacing, secondWidth, secondHeight),
        Rect.fromLTWH(
          secondWidth + spacing,
          firstHeight + spacing,
          thirdWidth,
          secondHeight,
        ),
      ],
      const [1, 2],
    );
  }

  TelegramMediaGroupLayout _fourTopAndOther() {
    final topHeight = math.min(
      maxWidth / ratios[0],
      (maxWidth - spacing) * _topAndOtherHeightFactor,
    );
    final rowHeight =
        (maxWidth - 2 * spacing) / (ratios[1] + ratios[2] + ratios[3]);
    final firstWidth = math.max(
      minWidth,
      math.min(
        (maxWidth - 2 * spacing) * _topRowWidthFactor,
        rowHeight * ratios[1],
      ),
    );
    final thirdWidth = math.max(
      math.max(minWidth, (maxWidth - 2 * spacing) * _middleRowWidthFactor),
      rowHeight * ratios[3],
    );
    final middleWidth = maxWidth - firstWidth - thirdWidth - (2 * spacing);
    final contentHeight = math.min(maxWidth - topHeight - spacing, rowHeight);
    return _manualLayout(
      <Rect>[
        Rect.fromLTWH(0, 0, maxWidth, topHeight),
        Rect.fromLTWH(0, topHeight + spacing, firstWidth, contentHeight),
        Rect.fromLTWH(
          firstWidth + spacing,
          topHeight + spacing,
          middleWidth,
          contentHeight,
        ),
        Rect.fromLTWH(
          firstWidth + middleWidth + (2 * spacing),
          topHeight + spacing,
          thirdWidth,
          contentHeight,
        ),
      ],
      const [1, 3],
    );
  }

  TelegramMediaGroupLayout _fourLeftAndOther() {
    final leftWidth = math.min(
      maxWidth * ratios[0],
      (maxWidth - spacing) * _leftColumnWidthFactor,
    );
    final rightWidth =
        (maxWidth - (2 * spacing)) /
        ((1 / ratios[1]) + (1 / ratios[2]) + (1 / ratios[3]));
    final topHeight = rightWidth / ratios[1];
    final middleHeight = rightWidth / ratios[2];
    final bottomHeight = maxWidth - topHeight - middleHeight - (2 * spacing);
    final contentWidth = math.max(
      minWidth,
      math.min(maxWidth - leftWidth - spacing, rightWidth),
    );
    return _manualLayout(
      <Rect>[
        Rect.fromLTWH(0, 0, leftWidth, maxWidth),
        Rect.fromLTWH(leftWidth + spacing, 0, contentWidth, topHeight),
        Rect.fromLTWH(
          leftWidth + spacing,
          topHeight + spacing,
          contentWidth,
          middleHeight,
        ),
        Rect.fromLTWH(
          leftWidth + spacing,
          topHeight + middleHeight + (2 * spacing),
          contentWidth,
          bottomHeight,
        ),
      ],
      const [1, 1, 1, 1],
    );
  }

  TelegramMediaGroupLayout _complex() {
    final builder = _ComplexTelegramMediaGroupLayouter(
      ratios: ratios,
      averageRatio: averageRatio,
      maxWidth: maxWidth,
      minWidth: minWidth,
      spacing: spacing,
    );
    return builder.layout();
  }

  TelegramMediaGroupLayout _buildRows(
    List<int> rowCounts,
    List<double> heights,
  ) {
    final rects = <Rect>[];
    var top = 0.0;
    for (var row = 0; row < rowCounts.length; row++) {
      final count = rowCounts[row];
      final rowHeight = heights[row];
      var left = 0.0;
      for (var column = 0; column < count; column++) {
        final width = column == count - 1
            ? maxWidth - left
            : ((maxWidth - ((count - 1) * spacing)) / count);
        rects.add(Rect.fromLTWH(left, top, width, rowHeight));
        left += width + spacing;
      }
      top += rowHeight + spacing;
    }
    return _manualLayout(rects, rowCounts);
  }

  TelegramMediaGroupLayout _manualLayout(
    List<Rect> rects,
    List<int> rowCounts,
  ) {
    final items = <TelegramMediaGroupLayoutItem>[];
    var rowStart = 0;
    for (var row = 0; row < rowCounts.length; row++) {
      final count = rowCounts[row];
      for (var column = 0; column < count; column++) {
        items.add(
          TelegramMediaGroupLayoutItem(
            geometry: rects[rowStart + column],
            isTop: row == 0,
            isRight: column == count - 1,
            isBottom: row == rowCounts.length - 1,
            isLeft: column == 0,
          ),
        );
      }
      rowStart += count;
    }
    final height = rects.fold<double>(
      0,
      (value, item) => math.max(value, item.bottom),
    );
    return TelegramMediaGroupLayout(
      items: items,
      height: height,
      rowCounts: rowCounts,
    );
  }
}

class _ComplexTelegramMediaGroupLayouter {
  const _ComplexTelegramMediaGroupLayouter({
    required this.ratios,
    required this.averageRatio,
    required this.maxWidth,
    required this.minWidth,
    required this.spacing,
  });

  final List<double> ratios;
  final double averageRatio;
  final double maxWidth;
  final double minWidth;
  final double spacing;

  TelegramMediaGroupLayout layout() {
    final cropped = _cropRatios();
    final attempts = _buildAttempts(cropped);
    final optimal = attempts.reduce(
      (best, next) => next.score < best.score ? next : best,
    );
    return _layoutFromAttempt(cropped, optimal);
  }

  List<double> _cropRatios() {
    return ratios
        .map((ratio) {
          if (averageRatio > _complexAverageRatioSplit) {
            return ratio.clamp(1.0, _maxCroppedRatio);
          }
          return ratio.clamp(_minCroppedRatio, 1.0);
        })
        .toList(growable: false);
  }

  List<_LayoutAttempt> _buildAttempts(List<double> cropped) {
    final attempts = <_LayoutAttempt>[];
    for (final rowCounts in _rowCountCandidates(cropped.length)) {
      final heights = _rowHeights(cropped, rowCounts);
      attempts.add(
        _LayoutAttempt(
          rowCounts: rowCounts,
          heights: heights,
          score: _attemptScore(rowCounts, heights),
        ),
      );
    }
    return attempts;
  }

  Iterable<List<int>> _rowCountCandidates(int count) sync* {
    for (var rows = 2; rows <= 4; rows++) {
      yield* _rowCountCandidatesForRows(count, rows);
    }
  }

  Iterable<List<int>> _rowCountCandidatesForRows(int total, int rows) sync* {
    final results = <List<int>>[];
    void collect(List<int> rowCounts) => results.add(rowCounts);
    void walk(List<int> prefix, int remaining, int row) {
      final maxPerRow = row == 1 && averageRatio < _portraitAverageRatioSplit
          ? _maxItemsPerMiddlePortraitRow
          : _maxItemsPerRow;
      if (row == rows - 1) {
        if (remaining >= 1 && remaining <= _maxItemsPerRow) {
          collect(<int>[...prefix, remaining]);
        }
        return;
      }
      final limit = math.min(maxPerRow, remaining - (rows - row - 1));
      for (var current = 1; current <= limit; current++) {
        walk(<int>[...prefix, current], remaining - current, row + 1);
      }
    }

    walk(<int>[], total, 0);
    yield* results;
  }

  List<double> _rowHeights(List<double> cropped, List<int> rowCounts) {
    final heights = <double>[];
    var offset = 0;
    for (final count in rowCounts) {
      final row = cropped.sublist(offset, offset + count);
      final sum = row.reduce((left, right) => left + right);
      heights.add((maxWidth - ((count - 1) * spacing)) / sum);
      offset += count;
    }
    return heights;
  }

  double _attemptScore(List<int> rowCounts, List<double> heights) {
    final targetHeight = maxWidth * 4 / 3;
    final totalHeight =
        heights.reduce((sum, value) => sum + value) +
        ((rowCounts.length - 1) * spacing);
    final smallPenalty =
        heights.any((height) => height < minWidth) ? _smallLinePenalty : 1.0;
    final descendingPenalty =
        _hasDescendingRows(rowCounts) ? _smallLinePenalty : 1.0;
    return (totalHeight - targetHeight).abs() *
        smallPenalty *
        descendingPenalty;
  }

  bool _hasDescendingRows(List<int> rowCounts) {
    for (var index = 1; index < rowCounts.length; index++) {
      if (rowCounts[index - 1] > rowCounts[index]) {
        return true;
      }
    }
    return false;
  }

  TelegramMediaGroupLayout _layoutFromAttempt(
    List<double> cropped,
    _LayoutAttempt attempt,
  ) {
    final items = <TelegramMediaGroupLayoutItem>[];
    var ratioIndex = 0;
    var top = 0.0;
    for (var row = 0; row < attempt.rowCounts.length; row++) {
      final count = attempt.rowCounts[row];
      final lineHeight = attempt.heights[row];
      var left = 0.0;
      for (var column = 0; column < count; column++) {
        final width = column == count - 1
            ? maxWidth - left
            : cropped[ratioIndex] * lineHeight;
        items.add(
          TelegramMediaGroupLayoutItem(
            geometry: Rect.fromLTWH(left, top, width, lineHeight),
            isTop: row == 0,
            isRight: column == count - 1,
            isBottom: row == attempt.rowCounts.length - 1,
            isLeft: column == 0,
          ),
        );
        left += width + spacing;
        ratioIndex++;
      }
      top += lineHeight + spacing;
    }
    return TelegramMediaGroupLayout(
      items: items,
      height: top - spacing,
      rowCounts: attempt.rowCounts,
    );
  }
}

class _LayoutAttempt {
  const _LayoutAttempt({
    required this.rowCounts,
    required this.heights,
    required this.score,
  });

  final List<int> rowCounts;
  final List<double> heights;
  final double score;
}
