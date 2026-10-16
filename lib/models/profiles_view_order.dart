import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';

/// Narrowing and ordering for the profiles list.
///
/// Kept out of the widget so the rules can be exercised directly: the two
/// filters sort on different fields, and the tie-break for entries that carry
/// no date has to behave the same in both directions.
extension ProfilesViewOrder on List<Profile> {
  List<Profile> applyFilterAndSort(
    ProfilesFilterType filter,
    ProfilesSortType sort,
  ) {
    final filtered = switch (filter) {
      ProfilesFilterType.all => this,
      ProfilesFilterType.url => where(
        (profile) => profile.type == ProfileType.url,
      ).toList(),
      ProfilesFilterType.file => where(
        (profile) => profile.type == ProfileType.file,
      ).toList(),
    };
    if (filter == ProfilesFilterType.all || sort == ProfilesSortType.none) {
      // Manual order is the user's own arrangement; leave it alone.
      return List<Profile>.from(filtered);
    }
    final isAscending = sort == ProfilesSortType.ascending;
    final sorted = List<Profile>.from(filtered);
    sorted.sort((a, b) {
      // Entries without a date are pinned last in both directions, so flipping
      // the order never drags the data-less ones to the top.
      final aMissing = _lacksDate(a, filter);
      final bMissing = _lacksDate(b, filter);
      if (aMissing || bMissing) {
        if (aMissing && bMissing) return 0;
        return aMissing ? 1 : -1;
      }
      final comparison = _compare(a, b, filter);
      return isAscending ? comparison : -comparison;
    });
    return sorted;
  }

  static bool _lacksDate(Profile profile, ProfilesFilterType filter) {
    return switch (filter) {
      ProfilesFilterType.all => false,
      ProfilesFilterType.url => (profile.subscriptionInfo?.expire ?? 0) <= 0,
      ProfilesFilterType.file => profile.lastUpdateDate == null,
    };
  }

  /// [ProfilesFilterType.url] orders by subscription expiry, so the account
  /// that runs out first floats to the top. [ProfilesFilterType.file] has no
  /// expiry and orders by when the file was added, which is what
  /// [Profile.lastUpdateDate] records for a local profile.
  static int _compare(Profile a, Profile b, ProfilesFilterType filter) {
    return switch (filter) {
      ProfilesFilterType.all => 0,
      ProfilesFilterType.url => (a.subscriptionInfo?.expire ?? 0).compareTo(
        b.subscriptionInfo?.expire ?? 0,
      ),
      ProfilesFilterType.file =>
        (a.lastUpdateDate?.microsecondsSinceEpoch ?? 0).compareTo(
          b.lastUpdateDate?.microsecondsSinceEpoch ?? 0,
        ),
    };
  }
}
