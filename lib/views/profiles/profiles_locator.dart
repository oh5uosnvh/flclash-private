import 'package:material_ui/material_ui.dart';

/// Scrolling for the profiles grid, which builds its cards on demand.
///
/// [Scrollable.ensureVisible] needs the target to exist already, and a
/// lazy grid has no context for anything outside its cache extent. Revealing a
/// card is therefore two phases: move to roughly the right place so the grid
/// builds it, then animate precisely onto it.
///
/// The rough phase can miss, because card heights vary and the estimate is
/// crude. Rather than trusting a single guess, the second phase is retried
/// across a few frames while nudging further along, which converges quickly and
/// is bounded so a card that never appears cannot spin forever.
class ProfilesLocator {
  ProfilesLocator(this.controller, {this.leadingInsetOf});

  final ScrollController controller;

  /// Where a revealed card's top edge should land, measured from the
  /// viewport's top edge. The viewport starts under the app bar, so the body
  /// hands in its own content inset — the gap the first card gets at rest —
  /// instead of the locator guessing a fraction of the viewport.
  final double Function()? leadingInsetOf;

  static const _settleDuration = Duration(milliseconds: 300);
  static const _maxAttempts = 10;

  /// Vertical pull applied when nudging toward a card that has not been built.
  static const _nudgeFraction = 0.75;

  bool get _canScroll => controller.hasClients;

  double get _minExtent => _canScroll ? controller.position.minScrollExtent : 0;

  double get _maxExtent => _canScroll ? controller.position.maxScrollExtent : 0;

  /// Scrolls the card behind [key] into view.
  ///
  /// [fraction] is where the target is believed to sit in the list (0 at the
  /// top, 1 at the bottom); it only seeds the first guess and is corrected as
  /// soon as the card exists.
  void reveal(GlobalKey key, {required double fraction}) {
    if (!_canScroll) return;
    if (_settle(key)) return;
    controller.jumpTo(
      (_minExtent + (_maxExtent - _minExtent) * fraction).clamp(
        _minExtent,
        _maxExtent,
      ),
    );
    _settleLater(key, fraction: fraction, attempt: 0);
  }

  void _settleLater(
    GlobalKey key, {
    required double fraction,
    required int attempt,
  }) {
    if (attempt >= _maxAttempts) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canScroll) return;
      if (_settle(key)) return;
      // The card is still not built. Step in the direction the estimate says it
      // lies; stepping only one way would strand a target that the first guess
      // overshot, which is what made the bottom of a long list unreachable.
      final viewport = controller.position.viewportDimension;
      final step = viewport * _nudgeFraction;
      final current = controller.offset;
      final progress = _maxExtent <= _minExtent
          ? 0.0
          : (current - _minExtent) / (_maxExtent - _minExtent);
      final next = (progress < fraction ? current + step : current - step)
          .clamp(_minExtent, _maxExtent);
      if (next == current) return;
      controller.jumpTo(next);
      _settleLater(key, fraction: fraction, attempt: attempt + 1);
    });
  }

  /// Animates onto the card so its top edge lands on the body's content
  /// inset, just clear of the app bar. Returns whether the card exists.
  bool _settle(GlobalKey key) {
    if (!_canScroll) return false;
    final itemContext = key.currentContext;
    if (itemContext == null || !itemContext.mounted) return false;
    final renderObject = itemContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final scrollContext = controller.position.context;
    final viewportBox = scrollContext.storageContext.findRenderObject();
    if (viewportBox is! RenderBox || !viewportBox.hasSize) return false;
    // The viewport runs under the app bar, so a card parked behind the bar is
    // still inside it as far as ensureVisible is concerned, which is how a
    // revealed card could end up half hidden by the bar. Measure by hand
    // instead and move the card's leading edge onto the content inset.
    final cardTop = renderObject
        .localToGlobal(Offset.zero, ancestor: viewportBox)
        .dy;
    final targetTop = leadingInsetOf?.call() ?? 0.0;
    final delta = cardTop - targetTop;
    if (delta.abs() < 0.5) return true;
    final target = (controller.offset + delta).clamp(_minExtent, _maxExtent);
    if ((target - controller.offset).abs() < 0.5) return true;
    controller.animateTo(
      target,
      duration: _settleDuration,
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  void toTop() {
    if (!_canScroll) return;
    controller.animateTo(
      _minExtent,
      duration: _settleDuration,
      curve: Curves.easeOutCubic,
    );
  }

  /// Whether the grid is resting at (or within half a pixel of) the top. The
  /// title tap uses this to decide between "go to top" and "explain why
  /// locating is unavailable" — the explanation only fires once the user is
  /// already at the top.
  bool isAtTop() {
    if (!_canScroll) return true;
    return controller.offset <= _minExtent + 0.5;
  }

  void toBottom() {
    if (!_canScroll) return;
    controller.animateTo(
      _maxExtent,
      duration: _settleDuration,
      curve: Curves.easeOutCubic,
    );
  }
}
