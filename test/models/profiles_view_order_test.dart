import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _url(int id, {required int expire, String? label}) {
  return Profile(
    id: id,
    label: label ?? 'url-$id',
    url: 'https://example.com/$id',
    autoUpdateDuration: Duration.zero,
    subscriptionInfo: SubscriptionInfo(expire: expire),
  );
}

Profile _file(int id, {required DateTime? added, String? label}) {
  return Profile(
    id: id,
    label: label ?? 'file-$id',
    autoUpdateDuration: Duration.zero,
    lastUpdateDate: added,
  );
}

List<int> _ids(List<Profile> profiles) =>
    profiles.map((profile) => profile.id).toList();

void main() {
  group('ProfilesFilterType', () {
    final profiles = [
      _url(1, expire: 300),
      _file(2, added: DateTime(2026, 1, 2)),
      _url(3, expire: 100),
      _file(4, added: DateTime(2026, 1, 1)),
    ];

    test('all keeps every profile in the manual order', () {
      final result = profiles.applyFilterAndSort(
        ProfilesFilterType.all,
        ProfilesSortType.ascending,
      );
      expect(_ids(result), [1, 2, 3, 4]);
    });

    test('all ignores the sort direction and preserves manual order', () {
      final ascending = profiles.applyFilterAndSort(
        ProfilesFilterType.all,
        ProfilesSortType.ascending,
      );
      final descending = profiles.applyFilterAndSort(
        ProfilesFilterType.all,
        ProfilesSortType.descending,
      );
      final none = profiles.applyFilterAndSort(
        ProfilesFilterType.all,
        ProfilesSortType.none,
      );
      expect(_ids(ascending), [1, 2, 3, 4]);
      expect(_ids(descending), [1, 2, 3, 4]);
      expect(_ids(none), [1, 2, 3, 4]);
    });

    test('url keeps only subscription profiles', () {
      final result = profiles.applyFilterAndSort(
        ProfilesFilterType.url,
        ProfilesSortType.ascending,
      );
      expect(_ids(result), [3, 1]);
      expect(result.every((p) => p.type == ProfileType.url), isTrue);
    });

    test('url filter with sort none preserves original manual order', () {
      final result = profiles.applyFilterAndSort(
        ProfilesFilterType.url,
        ProfilesSortType.none,
      );
      expect(_ids(result), [1, 3]);
      expect(result.every((p) => p.type == ProfileType.url), isTrue);
    });

    test('file filter with sort none preserves original manual order', () {
      final result = profiles.applyFilterAndSort(
        ProfilesFilterType.file,
        ProfilesSortType.none,
      );
      expect(_ids(result), [2, 4]);
      expect(result.every((p) => p.type == ProfileType.file), isTrue);
    });

    test('file keeps only local profiles', () {
      final result = profiles.applyFilterAndSort(
        ProfilesFilterType.file,
        ProfilesSortType.ascending,
      );
      expect(_ids(result), [4, 2]);
      expect(result.every((p) => p.type == ProfileType.file), isTrue);
    });
  });

  group('url filter ordering', () {
    final profiles = [
      _url(1, expire: 300, label: 'mid'),
      _url(2, expire: 100, label: 'soon'),
      _url(3, expire: 900, label: 'late'),
    ];

    test('ascending puts the soonest expiry first', () {
      final result = profiles.applyFilterAndSort(
        ProfilesFilterType.url,
        ProfilesSortType.ascending,
      );
      expect(_ids(result), [2, 1, 3]);
    });

    test('descending puts the latest expiry first', () {
      final result = profiles.applyFilterAndSort(
        ProfilesFilterType.url,
        ProfilesSortType.descending,
      );
      expect(_ids(result), [3, 1, 2]);
    });

    test('never-expiring subscriptions sort last either way', () {
      final withForever = [
        _url(1, expire: 0, label: '长期有效'),
        _url(2, expire: 500),
        _url(3, expire: 200),
      ];
      expect(
        _ids(
          withForever.applyFilterAndSort(
            ProfilesFilterType.url,
            ProfilesSortType.ascending,
          ),
        ),
        [3, 2, 1],
      );
      expect(
        _ids(
          withForever.applyFilterAndSort(
            ProfilesFilterType.url,
            ProfilesSortType.descending,
          ),
        ),
        [2, 3, 1],
      );
    });

    test('a url profile without subscription info sorts last', () {
      final profiles = [
        _url(1, expire: 400),
        const Profile(
          id: 2,
          url: 'https://example.com/none',
          autoUpdateDuration: Duration.zero,
        ),
        _url(3, expire: 100),
      ];
      expect(
        _ids(
          profiles.applyFilterAndSort(
            ProfilesFilterType.url,
            ProfilesSortType.ascending,
          ),
        ),
        [3, 1, 2],
      );
    });
  });

  group('file filter ordering', () {
    final profiles = [
      _file(1, added: DateTime(2026, 6, 1), label: 'newest'),
      _file(2, added: DateTime(2026, 1, 1), label: 'oldest'),
      _file(3, added: DateTime(2026, 3, 1), label: 'middle'),
    ];

    test('ascending puts the earliest added first', () {
      final result = profiles.applyFilterAndSort(
        ProfilesFilterType.file,
        ProfilesSortType.ascending,
      );
      expect(_ids(result), [2, 3, 1]);
    });

    test('descending puts the most recently added first', () {
      final result = profiles.applyFilterAndSort(
        ProfilesFilterType.file,
        ProfilesSortType.descending,
      );
      expect(_ids(result), [1, 3, 2]);
    });

    test('a local profile with no date sorts last either way', () {
      final withUndated = [
        _file(1, added: null),
        _file(2, added: DateTime(2026, 5, 1)),
        _file(3, added: DateTime(2026, 2, 1)),
      ];
      expect(
        _ids(
          withUndated.applyFilterAndSort(
            ProfilesFilterType.file,
            ProfilesSortType.ascending,
          ),
        ),
        [3, 2, 1],
      );
      expect(
        _ids(
          withUndated.applyFilterAndSort(
            ProfilesFilterType.file,
            ProfilesSortType.descending,
          ),
        ),
        [2, 3, 1],
      );
    });
  });

  group('shape', () {
    test('filtering an empty list stays empty', () {
      for (final filter in ProfilesFilterType.values) {
        expect(
          <Profile>[].applyFilterAndSort(filter, ProfilesSortType.ascending),
          isEmpty,
        );
      }
    });

    test('filtering returns a new list and leaves the source untouched', () {
      final source = [_url(1, expire: 100), _file(2, added: DateTime(2026))];
      final snapshot = _ids(source);
      source.applyFilterAndSort(
        ProfilesFilterType.url,
        ProfilesSortType.descending,
      );
      expect(_ids(source), snapshot);
    });
  });
}
