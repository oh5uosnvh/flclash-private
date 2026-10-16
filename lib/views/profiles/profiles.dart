import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/overwrite/overwrite.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add.dart';
import 'edit.dart';
import 'preview.dart';
import 'profiles_locator.dart';
import 'profiles_header_controls.dart';

class ProfilesView extends ConsumerStatefulWidget {
  const ProfilesView({super.key});

  @override
  ConsumerState<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends ConsumerState<ProfilesView> {
  Function? applyConfigDebounce;
  bool _isUpdating = false;

  ProfilesFilterType _filter = ProfilesFilterType.all;
  ProfilesSortType _sort = ProfilesSortType.ascending;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _updateProfiles(List<Profile> profiles) async {
    if (_isUpdating == true) {
      return;
    }
    _isUpdating = true;
    final appLocalizations = context.appLocalizations;
    final profilesAction = ref.read(profilesActionProvider.notifier);
    final List<UpdatingMessage> messages = [];
    final updateProfiles = profiles.map<Future>((profile) async {
      if (profile.type == ProfileType.file) return;
      try {
        await profilesAction.updateProfile(profile, showLoading: true);
      } catch (e) {
        messages.add(
          UpdatingMessage(
            label: profile.realLabel,
            message: userFacingErrorMessage(e, appLocalizations),
          ),
        );
      }
    });
    await Future.wait(updateProfiles);
    if (messages.isNotEmpty) {
      unawaited(dialogs.showAllUpdatingMessagesDialog(messages));
    }
    _isUpdating = false;
  }

  List<IconButtonData> _buildActions(List<Profile> profiles) {
    return profiles.isNotEmpty
        ? [
            IconButtonData(
              glyph: AppGlyphs.sync,
              onPressed: () {
                _updateProfiles(profiles);
              },
              tooltip: context.appLocalizations.update,
            ),
            IconButtonData(
              glyph: AppGlyphs.sort,
              onPressed: () {
                showSheet(
                  context: context,
                  builder: (_) {
                    return ReorderableProfilesSheet(profiles: profiles);
                  },
                );
              },
              tooltip: context.appLocalizations.profilesSort,
            ),
          ]
        : [];
  }

  /// Tap: 回顶部永远优先——选中卡在屏上时回到顶部；选中卡在当前筛选列表里
  /// 但不在屏上时定位到它；选中卡被筛选隐藏/未选择时，第一次点击仍先回顶部，
  /// 只有已经在顶部时才提示定位不可用的原因。长按：直接跳到列表底部。
  void _handleTitleTap() {
    if (_isSelectedVisible) {
      _locator?.toTop();
      return;
    }
    final currentProfileId = ref.read(
      profilesStateProvider.select((state) => state.currentProfileId),
    );
    final hasSelection = currentProfileId != null;
    if (hasSelection) {
      final profiles = ref.read(profilesStateProvider).profiles;
      final filtered = profiles.applyFilterAndSort(_filter, _sort);
      if (filtered.any((profile) => profile.id == currentProfileId)) {
        if (_revealSelected?.call() ?? false) return;
      }
    }
    if (!(_locator?.isAtTop() ?? true)) {
      _locator?.toTop();
      return;
    }
    context.showNotifier(
      hasSelection
          ? context.appLocalizations.profilesLocateHidden
          : context.appLocalizations.profilesLocateNone,
      level: MessageLevel.info,
    );
  }

  void _handleTitleLongPress() {
    _locator?.toBottom();
  }

  /// Provided by the body, which owns the grid's item keys.
  bool Function()? _revealSelected;

  List<Profile> _visibleProfiles(List<Profile> profiles) {
    return profiles.applyFilterAndSort(_filter, _sort);
  }

  /// The filter/sort pair only earns its place once there is something to
  /// narrow down; a single profile needs neither.
  bool _showHeaderControls(List<Profile> profiles) {
    return profiles.length > 1;
  }

  /// Scroll control for the grid, which lives in the body.
  ///
  /// The title and the body are sibling subtrees of [Scaffold], so the body
  /// hands its locator up here instead of publishing it as an inherited widget
  /// that the app bar could not reach.
  ProfilesLocator? _locator;

  /// Whether the selected card is on screen, so a second tap can go to the top
  /// rather than repeating a scroll that would do nothing.
  bool _isSelectedVisible = false;

  Widget _buildTitle(List<Profile> all) {
    return ProfilesTitle(
      title: context.appLocalizations.profiles,
      onTap: all.isEmpty ? null : _handleTitleTap,
      onLongPress: all.isEmpty ? null : _handleTitleLongPress,
      controls: _showHeaderControls(all)
          ? ProfilesHeaderControls(
              filter: _filter,
              sort: _sort,
              onFilterChanged: (value) {
                setState(() => _filter = value);
              },
              onSortChanged: (value) {
                setState(() => _sort = value);
              },
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        final appLocalizations = context.appLocalizations;
        final isLoading = ref.watch(loadingProvider(LoadingTag.profiles));
        final state = ref.watch(profilesStateProvider);
        final spacing = cardSpacing;
        final profiles = _visibleProfiles(state.profiles);
        return CommonScaffold(
          isLoading: isLoading,
          titleWidget: _buildTitle(state.profiles),
          primaryAction: state.profiles.isEmpty
              ? null
              : IconButtonData(
                  glyph: AppGlyphs.add,
                  onPressed: showAddProfilePage,
                  tooltip: appLocalizations.addProfile,
                ),
          iconActions: _buildActions(state.profiles),
          foldPrimaryAction: true,
          body: _ProfilesBody(
            profiles: profiles,
            allProfiles: state.profiles,
            currentProfileId: state.currentProfileId,
            spacing: spacing,
            onRevealUnavailable: () {
              if (!mounted) return;
              context.showNotifier(
                appLocalizations.profilesLocateHidden,
                level: MessageLevel.info,
              );
            },
            onLocatorReady: (locator, reveal) {
              _locator = locator;
              _revealSelected = reveal;
            },
            onSelectedVisibilityChanged: (isVisible) {
              if (_isSelectedVisible == isVisible) return;
              setState(() => _isSelectedVisible = isVisible);
            },
          ),
        );
      },
    );
  }
}

class _ProfilesBody extends ConsumerStatefulWidget {
  const _ProfilesBody({
    required this.profiles,
    required this.allProfiles,
    required this.currentProfileId,
    required this.spacing,
    required this.onRevealUnavailable,
    required this.onLocatorReady,
    required this.onSelectedVisibilityChanged,
  });

  final List<Profile> profiles;
  final List<Profile> allProfiles;
  final int? currentProfileId;
  final double spacing;
  final VoidCallback onRevealUnavailable;

  /// Hands the locator and the reveal callback up to the page state, which
  /// owns the app bar title. See [_ProfilesViewState._locator].
  final void Function(ProfilesLocator locator, bool Function() reveal)
  onLocatorReady;

  /// Reports whether the selected card is currently on screen, so the title
  /// knows whether a tap means "scroll to it" or "go back to the top".
  final ValueChanged<bool> onSelectedVisibilityChanged;

  @override
  ConsumerState<_ProfilesBody> createState() => _ProfilesBodyState();
}

class _ProfilesBodyState extends ConsumerState<_ProfilesBody> {
  final _scrollController = ScrollController();
  late final ProfilesLocator _locator = ProfilesLocator(
    _scrollController,
    leadingInsetOf: () => context.contentTopPadding,
  );

  /// One key per profile id so the selected card's context can be reached even
  /// though the masonry layout gives every card a different height.
  final _itemKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    widget.onLocatorReady(_locator, _revealSelected);
    _scrollController.addListener(_reportSelectedVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportSelectedVisibility();
    });
  }

  /// Runs on every scroll frame; the callback compares it against the last
  /// value it saw and only rebuilds when it actually flips.
  void _reportSelectedVisibility() {
    widget.onSelectedVisibilityChanged(_isSelectedVisible);
  }

  @override
  void didUpdateWidget(covariant _ProfilesBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousIds = oldWidget.allProfiles.map((p) => p.id).toSet();
    final added = widget.allProfiles.any((p) => !previousIds.contains(p.id));
    if (added) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_locator.toBottom());
      });
    }
    if (widget.onLocatorReady != oldWidget.onLocatorReady) {
      widget.onLocatorReady(_locator, _revealSelected);
    }
    // A filter or sort change rebuilds the list without moving the scroll
    // offset, so whether the selected card is on screen has to be re-measured
    // once the new layout has been laid out.
    if (widget.profiles != oldWidget.profiles ||
        widget.currentProfileId != oldWidget.currentProfileId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _reportSelectedVisibility();
      });
    }
  }

  @override
  void dispose() {
    _locator.cancel();
    _scrollController.removeListener(_reportSelectedVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int profileId) {
    return _itemKeys.putIfAbsent(profileId, () => GlobalKey());
  }

  /// Scrolls to the selected card. Returns false when there is no selection or
  /// the active filter hides it, so the caller can explain why nothing moved.
  bool _revealSelected() {
    final currentProfileId = widget.currentProfileId;
    if (currentProfileId == null) {
      return false;
    }
    final index = widget.profiles.indexWhere(
      (profile) => profile.id == currentProfileId,
    );
    if (index == -1) {
      // The selection exists but the active filter hides it.
      widget.onRevealUnavailable();
      return false;
    }
    // Seeding the guess with the card's relative position is all this needs:
    // everything past the first jump is corrected once the card exists.
    final fraction = widget.profiles.length <= 1
        ? 0.0
        : index / (widget.profiles.length - 1);
    _locator.reveal(_keyFor(currentProfileId), fraction: fraction);
    return true;
  }

  /// Whether the selected card is already on screen, which is what decides
  /// between "scroll to it" and "go back to the top".
  bool get _isSelectedVisible {
    final currentProfileId = widget.currentProfileId;
    if (currentProfileId == null) return false;
    final itemContext = _keyFor(currentProfileId).currentContext;
    if (itemContext == null || !itemContext.mounted) return false;
    final renderObject = itemContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final viewport = _scrollController.position;
    final viewportBox = _scrollController.position.context.storageContext
        .findRenderObject();
    if (viewportBox is! RenderBox || !viewportBox.hasSize) return false;
    // Compare in the viewport's own coordinate space; mixing a screen-space dy
    // with a viewport height would compare unrelated numbers.
    final cardTop = renderObject
        .localToGlobal(Offset.zero, ancestor: viewportBox)
        .dy;
    final cardBottom = cardTop + renderObject.size.height;
    final viewportHeight = viewport.viewportDimension;
    // A card counts as visible once a worthwhile slice of it is on screen, so
    // being clipped at the very edge still reads as "not there yet".
    final edge = viewportHeight * 0.15;
    return cardBottom > edge && cardTop < viewportHeight - edge;
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isEmpty = widget.allProfiles.isEmpty;
    return NullStatusSwitcher(
      isEmpty: widget.profiles.isEmpty,
      nullStatus: NullStatus(
        label: isEmpty
            ? appLocalizations.nullTip(appLocalizations.profiles)
            : appLocalizations.profilesFilterEmpty,
        description: isEmpty ? appLocalizations.nullProfileDesc : null,
        illustration: NullStatusIllustration.profile,
        action: isEmpty
            ? ElasticButton(
                child: FilledButton.tonalIcon(
                  onPressed: showAddProfilePage,
                  icon: const GlyphIcon(AppGlyphs.add, fill: 1),
                  label: Text(appLocalizations.addProfile),
                ),
              )
            : null,
      ),
      child: _ProfilesGrid(
        profiles: widget.profiles,
        currentProfileId: widget.currentProfileId,
        spacing: widget.spacing,
        controller: _scrollController,
        keyFor: _keyFor,
      ),
    );
  }
}

class _ProfilesGrid extends ConsumerWidget {
  const _ProfilesGrid({
    required this.profiles,
    required this.currentProfileId,
    required this.spacing,
    required this.controller,
    required this.keyFor,
  });

  static const _horizontalPadding = 16.0;

  final List<Profile> profiles;
  final int? currentProfileId;
  final double spacing;
  final ScrollController controller;
  final GlobalKey Function(int profileId) keyFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final columns = getProfilesColumns(
          constraints.maxWidth - _horizontalPadding * 2,
          spacing: spacing,
          minItemWidth: profileItemMinWidth.ap,
        );
        Widget buildItem(BuildContext context, int index) {
          final profile = profiles[index];
          return ProfileItem(
            key: keyFor(profile.id),
            profile: profile,
            groupValue: currentProfileId,
            onChanged: (profileId) {
              ref.read(currentProfileIdProvider.notifier).value = profileId;
            },
          );
        }

        final padding = EdgeInsets.only(
          left: _horizontalPadding,
          right: _horizontalPadding,
          top: context.contentTopPadding,
          bottom: 16 + BottomInsetScope.of(context),
        );
        if (columns == 1) {
          return ListView.separated(
            key: profilesStoreKey,
            controller: controller,
            padding: padding,
            itemCount: profiles.length,
            itemBuilder: buildItem,
            separatorBuilder: (_, _) => SizedBox(height: spacing),
          );
        }
        return MasonryGridView.count(
          key: profilesStoreKey,
          controller: controller,
          padding: EdgeInsets.only(
            left: _horizontalPadding,
            right: _horizontalPadding,
            top: context.contentTopPadding,
            bottom: 16 + BottomInsetScope.of(context),
          ),
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          itemCount: profiles.length,
          itemBuilder: buildItem,
        );
      },
    );
  }
}

class ProfileItem extends ConsumerWidget {
  final Profile profile;
  final int? groupValue;
  final void Function(int? value) onChanged;

  const ProfileItem({
    super.key,
    required this.profile,
    required this.groupValue,
    required this.onChanged,
  });

  Future<void> _handleDeleteProfile(BuildContext context, WidgetRef ref) async {
    final profilesAction = ref.read(profilesActionProvider.notifier);
    final appLocalizations = context.appLocalizations;
    final users = await profilesAction.providerUsers(profile);
    if (users.isNotEmpty) {
      await dialogs.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(
          text: appLocalizations.providerInUse(
            profile.realLabel,
            users.map((item) => item.realLabel).join(', '),
          ),
        ),
        cancelable: false,
      );
      return;
    }
    final res = await dialogs.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.profile),
      ),
    );
    if (res != true) {
      return;
    }
    await profilesAction.deleteProfile(profile.id);
  }

  Future<void> _handlePreview(BuildContext context) async {
    unawaited(
      BaseNavigator.push<String>(context, PreviewProfileView(profile: profile)),
    );
  }

  void _handleShowSubscriptionInfo(BuildContext context) {
    unawaited(
      dialogs.showCommonDialog<void>(
        context: context,
        child: Builder(
          builder: (context) {
            return CommonDialog(
              backgroundColor: context.colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: context.appLocalizations.subscriptionInfo,
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(context.appLocalizations.confirm),
                ),
              ],
              child: SubscriptionInfoDetailView(
                subscriptionInfo: profile.subscriptionInfo!,
              ),
            );
          },
        ),
      ),
    );
  }

  Future updateProfile(WidgetRef ref) async {
    if (profile.type == ProfileType.file) return;
    await globalState.loadingRun(() async {
      await ref
          .read(profilesActionProvider.notifier)
          .updateProfile(profile, showLoading: true);
    }, tag: LoadingTag.profiles);
  }

  void _handleShowEditExtendPage(BuildContext context) {
    showExtend(
      context,
      builder: (context) => EditProfileView(profile: profile, context: context),
    );
  }

  List<Widget> _buildUrlProfileInfo(BuildContext context) {
    final subscriptionInfo = profile.subscriptionInfo;
    return [
      if (subscriptionInfo != null && subscriptionInfo.total > 0) ...[
        SubscriptionInfoView(subscriptionInfo: subscriptionInfo),
        const SizedBox(height: 6),
      ],
      LastUpdateTimeText(
        lastUpdateDate: profile.lastUpdateDate,
        style: context.textTheme.bodySmall?.toLighter,
      ),
    ];
  }

  List<Widget> _buildFileProfileInfo(BuildContext context) {
    return [
      LastUpdateTimeText(
        lastUpdateDate: profile.lastUpdateDate,
        style: context.textTheme.bodySmall?.toLighter,
      ),
    ];
  }

  Future<void> _handleCopyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: profile.url));
    if (context.mounted) {
      context.showNotifier(
        context.appLocalizations.copySuccess,
        level: MessageLevel.success,
      );
    }
  }

  Future<void> _handleExportFile(BuildContext context) async {
    final appLocalizations = context.appLocalizations;
    final res = await globalState.safeRun<bool>(() async {
      final mFile = await profile.file;
      final value = await picker.saveFile(
        profile.realLabel,
        mFile.readAsBytesSync(),
      );
      if (value == null) return false;
      return true;
    }, title: appLocalizations.tip);
    if (res == true && context.mounted) {
      context.showNotifier(
        appLocalizations.exportSuccess,
        level: MessageLevel.success,
      );
    }
  }

  void _handlePushGenProfilePage(BuildContext context, int id) {
    BaseNavigator.push(context, OverwriteView(profileId: id));
  }

  List<CommonPopupMenuItem> _menuItems(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final isUrl = profile.type == ProfileType.url;
    final subscriptionInfo = profile.subscriptionInfo;
    final hasSubscriptionInfo =
        isUrl && subscriptionInfo != null && subscriptionInfo.total > 0;
    return [
      CommonPopupMenuItem(
        glyph: AppGlyphs.edit,
        label: appLocalizations.edit,
        onPressed: () {
          _handleShowEditExtendPage(context);
        },
      ),
      CommonPopupMenuItem(
        glyph: AppGlyphs.eye,
        label: appLocalizations.preview,
        onPressed: () {
          _handlePreview(context);
        },
      ),
      if (isUrl)
        CommonPopupMenuItem(
          glyph: AppGlyphs.sync,
          label: appLocalizations.sync,
          onPressed: () {
            updateProfile(ref);
          },
        ),
      CommonPopupMenuItem(
        glyph: AppGlyphs.moreCircle,
        label: appLocalizations.more,
        subItems: [
          CommonPopupMenuItem(
            glyph: AppGlyphs.puzzle,
            label: appLocalizations.override,
            onPressed: () {
              _handlePushGenProfilePage(context, profile.id);
            },
          ),
          if (hasSubscriptionInfo)
            CommonPopupMenuItem(
              glyph: AppGlyphs.dataUsage,
              label: appLocalizations.subscriptionInfo,
              onPressed: () {
                _handleShowSubscriptionInfo(context);
              },
            ),
          if (isUrl)
            CommonPopupMenuItem(
              glyph: AppGlyphs.copy,
              label: appLocalizations.copyLink,
              onPressed: () {
                _handleCopyLink(context);
              },
            ),
          CommonPopupMenuItem(
            glyph: AppGlyphs.export,
            label: appLocalizations.exportFile,
            onPressed: () {
              _handleExportFile(context);
            },
          ),
        ],
      ),
      CommonPopupMenuItem(
        danger: true,
        glyph: AppGlyphs.delete,
        label: appLocalizations.delete,
        onPressed: () {
          _handleDeleteProfile(context, ref);
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonCard(
      enterActionsOnRight: true,
      radius: AppCorner.xl,
      isSelected: profile.id == groupValue,
      onPressed: () {
        onChanged(profile.id);
      },
      child: ListItem(
        key: Key(profile.id.toString()),
        horizontalTitleGap: 8,
        minVerticalPadding: 12,
        padding: const EdgeInsets.only(left: 16, right: 6),
        trailing: SizedBox(
          height: 40,
          width: 40,
          child: Consumer(
            builder: (context, ref, _) {
              final isUpdating = ref.watch(
                isUpdatingProvider(profile.updatingKey),
              );
              return FadeThroughBox(
                alignment: Alignment.center,
                child: isUpdating
                    ? const Padding(
                        key: ValueKey('loading'),
                        padding: EdgeInsets.all(8),
                        child: CommonCircleLoading(),
                      )
                    : CommonPopupBox(
                        key: const ValueKey('menu'),
                        popupBuilder: (_) =>
                            CommonPopupMenu(items: _menuItems(context, ref)),
                        targetBuilder: (open) {
                          return IconButton(
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.standard,
                            ),
                            tooltip: context.appLocalizations.more,
                            onPressed: () {
                              open();
                            },
                            icon: const GlyphIcon(AppGlyphs.more),
                          );
                        },
                      ),
              );
            },
          ),
        ),
        title: _ProfileCardTitle(
          profile: profile,
          info: switch (profile.type) {
            ProfileType.file => _buildFileProfileInfo(context),
            ProfileType.url => _buildUrlProfileInfo(context),
          },
        ),
        tileTitleAlignment: ListTileTitleAlignment.top,
      ),
    );
  }
}

class _ProfileCardTitle extends StatelessWidget {
  const _ProfileCardTitle({required this.profile, required this.info});

  final Profile profile;
  final List<Widget> info;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.realLabel,
          style: context.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        ...info,
      ],
    );
  }
}

class ReorderableProfilesSheet extends ConsumerStatefulWidget {
  final List<Profile> profiles;

  const ReorderableProfilesSheet({super.key, required this.profiles});

  @override
  ConsumerState<ReorderableProfilesSheet> createState() =>
      _ReorderableProfilesSheetState();
}

class _ReorderableProfilesSheetState
    extends ConsumerState<ReorderableProfilesSheet> {
  late List<Profile> profiles;

  @override
  void initState() {
    super.initState();
    profiles = List.from(widget.profiles);
  }

  Widget _buildItem(int index) {
    final position = ItemPosition.get(index, profiles.length);
    final profile = profiles[index];
    return ItemPositionProvider(
      key: Key(profile.id.toString()),
      position: position,
      child: ReorderableDelayedDragStartListener(
        index: index,
        child: DecorationListItem(
          trailing: const GlyphIcon(AppGlyphs.dragHandle),
          title: Text(profile.realLabel),
        ),
      ),
    );
  }

  void _handleSave() {
    Navigator.of(context).pop();
    ref.read(profilesProvider.notifier).reorder(profiles);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      actions: [
        AppBarActionButton(
          data: IconButtonData(
            glyph: AppGlyphs.check,
            onPressed: _handleSave,
            tooltip: context.appLocalizations.save,
          ),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(top: context.contentTopPadding),
          proxyDecorator: (child, index, animation) {
            return commonProxyDecorator(_buildItem(index), index, animation);
          },
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              profiles = profiles.copyAndReorder(oldIndex, newIndex);
            });
          },
          itemBuilder: (_, index) {
            return _buildItem(index);
          },
          itemCount: profiles.length,
        ),
      ),
      title: appLocalizations.profilesSort,
    );
  }
}
