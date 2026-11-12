import 'dart:math' as math;
import 'dart:ui';

/// Estimates how much of a surface has been scratched, without reading pixels.
///
/// The surface is divided into a [gridSize] × [gridSize] grid. A cell counts as
/// scratched once a brush circle of [brushRadius] covers its centre.
/// [progress] is the share of scratched cells, from 0.0 to 1.0.
class ScratchProgressTracker {
  /// Creates a tracker for a surface of [size].
  ScratchProgressTracker({
    required this.size,
    required this.brushRadius,
    this.gridSize = 30,
  })  : assert(gridSize > 0),
        assert(brushRadius > 0),
        _cells = List<bool>.filled(gridSize * gridSize, false);

  /// Size of the scratchable surface.
  final Size size;

  /// Radius of the brush (half the stroke width).
  final double brushRadius;

  /// Number of cells along each axis.
  final int gridSize;

  final List<bool> _cells;
  int _scratched = 0;

  /// Number of cells marked as scratched.
  int get scratchedCells => _scratched;

  /// Total number of cells.
  int get totalCells => _cells.length;

  /// Share of scratched cells, from 0.0 to 1.0.
  double get progress => _cells.isEmpty ? 0 : _scratched / _cells.length;

  /// Marks every cell whose centre lies within the brush circle at [point].
  void addPoint(Offset point) {
    if (size.isEmpty) return;
    final cw = size.width / gridSize;
    final ch = size.height / gridSize;
    final r2 = brushRadius * brushRadius;
    final minCol = math.max(0, ((point.dx - brushRadius) / cw).floor());
    final maxCol =
        math.min(gridSize - 1, ((point.dx + brushRadius) / cw).floor());
    final minRow = math.max(0, ((point.dy - brushRadius) / ch).floor());
    final maxRow =
        math.min(gridSize - 1, ((point.dy + brushRadius) / ch).floor());
    for (var row = minRow; row <= maxRow; row++) {
      final cy = (row + 0.5) * ch;
      final dy = cy - point.dy;
      for (var col = minCol; col <= maxCol; col++) {
        final index = row * gridSize + col;
        if (_cells[index]) continue;
        final dx = (col + 0.5) * cw - point.dx;
        if (dx * dx + dy * dy <= r2) {
          _cells[index] = true;
          _scratched++;
        }
      }
    }
  }

  /// Marks cells along the straight segment from [from] to [to], so fast
  /// swipes with far-apart pointer events still count fully.
  void addSegment(Offset from, Offset to) {
    final distance = (to - from).distance;
    final step = math.max(1.0, brushRadius / 2);
    final steps = (distance / step).ceil();
    if (steps == 0) {
      addPoint(to);
      return;
    }
    for (var i = 1; i <= steps; i++) {
      addPoint(Offset.lerp(from, to, i / steps)!);
    }
  }

  /// Clears all scratched cells.
  void reset() {
    _cells.fillRange(0, _cells.length, false);
    _scratched = 0;
  }
}
