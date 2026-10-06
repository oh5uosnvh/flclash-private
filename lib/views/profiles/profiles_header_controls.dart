import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// The page title with, optionally, the joined filter/sort control beside it.
///
/// The two are deliberately separate gesture regions. The title text is its own
/// hit target — tap scrolls to the selected profile, long press jumps to the
/// bottom — while [controls] sits beside that target, so a tap aimed at the
/// pill can never be read as a tap on the title. Sharing one region made the
/// pill's inert half fall through to the title's recogniser, and the locate
/// action ran when the user only meant to touch 排序.
class ProfilesTitle extends StatelessWidget {
  const ProfilesTitle({
    super.key,
    required this.title,
    this.controls,
    this.onTap,
    this.onLongPress,
    this.longPressDuration = const Duration(milliseconds: 500),
  });

  final String title;
  final Widget? controls;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Duration longPressDuration;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _TitleGestureRegion(
              onTap: onTap,
              onLongPress: onLongPress,
              longPressDuration: longPressDuration,
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          ?controls,
        ],
      ),
    );
  }
}

/// The title text's own tap/long-press target.
///
/// Neither InkWell nor GestureDetector exposes the long-press delay, so the
/// recogniser is built directly to honour [longPressDuration].
class _TitleGestureRegion extends StatelessWidget {
  const _TitleGestureRegion({
    required this.child,
    required this.onTap,
    required this.onLongPress,
    required this.longPressDuration,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Duration longPressDuration;

  @override
  Widget build(BuildContext context) {
    const trailingPadding = EdgeInsets.symmetric(horizontal: 4, vertical: 6);
    if (onTap == null && onLongPress == null) {
      return Padding(padding: trailingPadding, child: child);
    }
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (recognizer) {
                recognizer.onTap = onTap;
              },
            ),
        if (onLongPress != null)
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(duration: longPressDuration),
                (recognizer) {
                  recognizer.onLongPress = onLongPress;
                },
              ),
      },
      child: Padding(padding: trailingPadding, child: child),
    );
  }
}

/// The joined `[ filter | sort ]` control that sits next to the profiles title.
///
/// Both halves share a single rounded shape: the filter half opens the
/// 默认 / 订阅 / 本地 list and the sort half flips the date ordering that the
/// 订阅 and 本地 filters use. The sort half stays visible in 默认 mode but is
/// inert there, because 默认 keeps the user's manual order.
class ProfilesHeaderControls extends StatelessWidget {
  const ProfilesHeaderControls({
    super.key,
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final ProfilesFilterType filter;
  final ProfilesSortType sort;
  final ValueChanged<ProfilesFilterType> onFilterChanged;
  final ValueChanged<ProfilesSortType> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final isSortEnabled = filter != ProfilesFilterType.all;
    final foreground = isSortEnabled
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSecondaryContainer.opacity38;

    return Padding(
      // The app bar title is laid out from the left edge; this keeps the pill
      // off the title text without widening the whole title slot.
      padding: const EdgeInsets.only(left: 10),
      child: Center(
        widthFactor: 1,
        child: Material(
          color: colorScheme.secondaryContainer,
          shape: AppShape.lg,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 34,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommonPopupBox(
                  backgroundColor: colorScheme.secondaryContainer,
                  popupBuilder: (_) => CommonPopupMenu(
                    items: [
                      for (final item in ProfilesFilterType.values)
                        CommonPopupMenuItem(
                          label: _filterLabelFor(appLocalizations, item),
                          glyph: _filterGlyphFor(item),
                          checked: item == filter,
                          onPressed: () {
                            onFilterChanged(item);
                          },
                        ),
                    ],
                  ),
                  targetBuilder: (openFilter) {
                    return _JoinedSegment(
                      label: _filterLabelFor(appLocalizations, filter),
                      foreground: foreground,
                      onPressed: openFilter,
                    );
                  },
                ),
                // The divider is what makes the two taps read as one pill.
                SizedBox(
                  width: 1,
                  height: 16,
                  child: ColoredBox(
                    color: colorScheme.onSecondaryContainer.withValues(
                      alpha: 0.24,
                    ),
                  ),
                ),
                CommonPopupBox(
                  backgroundColor: colorScheme.secondaryContainer,
                  popupBuilder: (_) => CommonPopupMenu(
                    items: [
                      for (final item in ProfilesSortType.values)
                        CommonPopupMenuItem(
                          label: _sortLabelFor(appLocalizations, item),
                          glyph: _sortGlyphFor(item),
                          checked: item == sort,
                          onPressed: () {
                            onSortChanged(item);
                          },
                        ),
                    ],
                  ),
                  targetBuilder: (openSort) {
                    return _JoinedSegment(
                      label: isSortEnabled && sort != ProfilesSortType.none
                          ? _sortLabelFor(appLocalizations, sort)
                          : appLocalizations.sort,
                      foreground: foreground,
                      onPressed: isSortEnabled ? openSort : null,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _filterLabelFor(
    AppLocalizations appLocalizations,
    ProfilesFilterType item,
  ) {
    return switch (item) {
      ProfilesFilterType.all => appLocalizations.profilesFilterAll,
      ProfilesFilterType.url => appLocalizations.profilesFilterUrl,
      ProfilesFilterType.file => appLocalizations.profilesFilterFile,
    };
  }

  Glyph _filterGlyphFor(ProfilesFilterType item) {
    return switch (item) {
      ProfilesFilterType.all => AppGlyphs.appsList,
      ProfilesFilterType.url => AppGlyphs.cloudDownload,
      ProfilesFilterType.file => AppGlyphs.importFile,
    };
  }

  String _sortLabelFor(
    AppLocalizations appLocalizations,
    ProfilesSortType item,
  ) {
    return switch (item) {
      ProfilesSortType.none => appLocalizations.profilesFilterAll,
      ProfilesSortType.ascending => appLocalizations.sortAscending,
      ProfilesSortType.descending => appLocalizations.sortDescending,
    };
  }

  Glyph _sortGlyphFor(ProfilesSortType item) {
    return switch (item) {
      ProfilesSortType.none => AppGlyphs.sort,
      ProfilesSortType.ascending => AppGlyphs.arrowUp,
      ProfilesSortType.descending => AppGlyphs.arrowDown,
    };
  }
}

class _JoinedSegment extends StatelessWidget {
  const _JoinedSegment({
    required this.label,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      // Tight horizontal padding so the two halves read as one pill rather
      // than two separate buttons, and enough vertical room to sit inside the
      // 34px bar without clipping the label's descenders.
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.labelLarge?.copyWith(color: foreground),
      ),
    );
    final onPressed = this.onPressed;
    if (onPressed != null) {
      return InkWell(onTap: onPressed, child: content);
    }
    // A half that is inert still has to swallow its own taps. Without an opaque
    // target here the pointer falls through to whatever gesture region happens
    // to sit behind the pill, which is how tapping 排序 in 默认 mode ended up
    // running the title's locate action.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: content,
    );
  }
}
