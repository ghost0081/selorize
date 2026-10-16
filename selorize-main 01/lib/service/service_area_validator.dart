import '../repository/auth_repository.dart';

class ServiceAreaMatch {
  const ServiceAreaMatch({required this.state, required this.city});

  final String state;
  final String city;
}

class ServiceAreaValidator {
  ServiceAreaValidator(this._repo);

  static const unavailableMessage =
      'Currently, we are not providing services in your area.';

  final AuthRepository _repo;

  Future<ServiceAreaMatch?> match({
    required String state,
    List<String> cityCandidates = const [],
  }) async {
    final detectedState = state.trim();
    if (detectedState.isEmpty) return null;

    final states = await _repo.getData(
      tableName: 'operationalState',
      filter: {},
    );
    final matchedState = _matchConfiguredName(
      states.map((row) => row['name']?.toString() ?? ''),
      [detectedState],
    );
    if (matchedState == null) return null;

    final stateRow = states.cast<Map<String, dynamic>?>().firstWhere(
      (row) =>
          _normalize(row?['name']?.toString() ?? '') ==
          _normalize(matchedState),
      orElse: () => null,
    );
    if (stateRow == null || stateRow['id'] == null) return null;

    final cities = await _repo.getData(
      tableName: 'locations',
      filter: {'stateId': stateRow['id']},
    );
    final matchedCity = _matchConfiguredName(
      cities.map((row) => row['locationName']?.toString() ?? ''),
      cityCandidates,
    );
    if (matchedCity == null) return null;

    return ServiceAreaMatch(state: matchedState, city: matchedCity);
  }

  static String? _matchConfiguredName(
    Iterable<String> configuredNames,
    List<String> detectedNames,
  ) {
    final configured = configuredNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final detected = detectedNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (configured.isEmpty || detected.isEmpty) return null;

    for (final option in configured) {
      for (final candidate in detected) {
        if (_placesMatch(candidate, option)) return option;
      }
    }
    return null;
  }

  static bool _placesMatch(String detected, String configured) {
    final left = _normalize(detected);
    final right = _normalize(configured);
    if (left.isEmpty || right.isEmpty) return false;
    if (left == right) return true;

    final shorter = left.length <= right.length ? left : right;
    final longer = left.length > right.length ? left : right;
    if (shorter.length < 4) return false;
    return RegExp('\\b${RegExp.escape(shorter)}\\b').hasMatch(longer);
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
