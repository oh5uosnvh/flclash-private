import 'package:fl_clash/views/profiles/profiles_locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Geometry of one card in the fake list.
class _Tile {
  const _Tile(this.top, this.height);

  final double top;
  final double height;
}

/// Models the part of a scrollable that the locator depends on: where the
/// content is, how tall the viewport is, and which region is currently built.
///
/// The real grid builds a card only when it falls inside the viewport plus the
/// cache extent, so a card outside that window has no context to scroll to —
/// which is the situation the locator exists to resolve.
class _FakeGrid {
  _FakeGrid({required this.tiles, required this.viewport});

  final List<_Tile> tiles;
  final double viewport;
  static const cache = 250.0;

  double offset = 0;

  double get contentExtent => tiles.last.top + tiles.last.height;

  double get maxScrollExtent =>
      (contentExtent - viewport).clamp(0, double.infinity);

  double get viewportDimension => viewport;

  bool isBuilt(int index) {
    final tile = tiles[index];
    final low = offset - cache;
    final high = offset + viewport + cache;
    return tile.top < high && tile.top + tile.height > low;
  }
}

/// Mirrors ProfilesLocator's search: seed from [fraction], then step toward the
/// target until it is built, correcting direction each attempt.
///
/// Kept as a plain function so the strategy can be exercised without a widget
/// tree; the widget class itself only adds the scroll/animation plumbing.
int _settleAttempts(_FakeGrid grid, int index, double fraction, int max) {
  if (grid.isBuilt(index)) return 0;
  const minExtent = 0.0;
  final maxExtent = grid.maxScrollExtent;
  var offset = (minExtent + (maxExtent - minExtent) * fraction).clamp(
    minExtent,
    maxExtent,
  );
  for (var attempt = 0; attempt < max; attempt++) {
    grid.offset = offset;
    if (grid.isBuilt(index)) return attempt;
    final step = grid.viewportDimension * 0.75;
    final progress = maxExtent <= minExtent
        ? 0.0
        : (offset - minExtent) / (maxExtent - minExtent);
    final next = (progress < fraction ? offset + step : offset - step).clamp(
      minExtent,
      maxExtent,
    );
    if (next == offset) return -1;
    offset = next;
  }
  return -1;
}

/// Card heights spread wide on purpose: the shipped first attempt assumed a
/// single 190px column, so a list whose rows vary this much is what exposes a
/// locator that cannot correct a bad estimate.
const _heights = [
  420.0,
  120.0,
  380.0,
  120.0,
  120.0,
  400.0,
  120.0,
  120.0,
  360.0,
  120.0,
  120.0,
  390.0,
  120.0,
  120.0,
  120.0,
  120.0,
  340.0,
  120.0,
  120.0,
  450.0,
];

_FakeGrid _gridFor(int columns, {double viewport = 800}) {
  final rows = (_heights.length / columns).ceil();
  final tiles = <_Tile>[];
  var top = 0.0;
  for (var row = 0; row < rows; row++) {
    final slice = _heights.skip(row * columns).take(columns);
    final tallest = slice.fold<double>(0, (a, b) => a > b ? a : b);
    tiles.add(_Tile(top, tallest));
    top += tallest + 14;
  }
  return _FakeGrid(tiles: tiles, viewport: viewport);
}

void main() {
  group('ProfilesLocator', () {
    test('constructing it does not touch the controller', () {
      // The locator is created before the grid has clients, so its constructor
      // must not read controller.position.
      final controller = _ThrowingController();
      expect(() => ProfilesLocator(controller), returnsNormally);
      expect(controller.positionReads, 0);
    });

    test('every card is reachable from the bottom', () {
      for (final columns in [1, 2, 3]) {
        final grid = _gridFor(columns);
        grid.offset = grid.maxScrollExtent;
        for (var index = 0; index < _heights.length; index++) {
          final probe = _gridFor(columns)..offset = grid.maxScrollExtent;
          final fraction = index / (_heights.length - 1);
          final attempts = _settleAttempts(
            probe,
            index ~/ columns,
            fraction,
            10,
          );
          expect(
            attempts,
            isNonNegative,
            reason: 'card $index unreachable from the bottom at $columns cols',
          );
        }
      }
    });

    test('every card is reachable from the top', () {
      for (final columns in [1, 2, 3]) {
        for (var index = 0; index < _heights.length; index++) {
          final probe = _gridFor(columns);
          final fraction = index / (_heights.length - 1);
          final attempts = _settleAttempts(
            probe,
            index ~/ columns,
            fraction,
            10,
          );
          expect(
            attempts,
            isNonNegative,
            reason: 'card $index unreachable from the top at $columns cols',
          );
        }
      }
    });

    test('a card already on screen needs no scrolling', () {
      final grid = _gridFor(1);
      expect(_settleAttempts(grid, 0, 0, 10), 0);
    });

    test('a list shorter than the viewport cannot scroll', () {
      final grid = _FakeGrid(
        tiles: const [_Tile(0, 120), _Tile(134, 120)],
        viewport: 800,
      );
      expect(grid.maxScrollExtent, 0);
      expect(_settleAttempts(grid, 1, 1, 10), 0);
    });
  });
}

/// A controller that fails loudly if the locator reads its position during
/// construction.
class _ThrowingController extends ScrollController {
  int positionReads = 0;

  @override
  ScrollPosition get position {
    positionReads++;
    throw StateError('no clients');
  }

  @override
  bool get hasClients => false;
}
