import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

import '../constants/app_assets.dart';
import '../models/school.dart';

/// Utah school directory loaded from bundled USBE CSV. Other states coming later.
class SchoolSearchService {
  SchoolSearchService._();
  static final SchoolSearchService instance = SchoolSearchService._();

  static const String _utahCsvAsset = AppAssets.utahSchoolsCsv;

  static const List<String> stateAbbreviations = [
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'DC',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY',
  ];

  static const Map<String, String> stateNames = {
    'AL': 'Alabama',
    'AK': 'Alaska',
    'AZ': 'Arizona',
    'AR': 'Arkansas',
    'CA': 'California',
    'CO': 'Colorado',
    'CT': 'Connecticut',
    'DE': 'Delaware',
    'DC': 'District of Columbia',
    'FL': 'Florida',
    'GA': 'Georgia',
    'HI': 'Hawaii',
    'ID': 'Idaho',
    'IL': 'Illinois',
    'IN': 'Indiana',
    'IA': 'Iowa',
    'KS': 'Kansas',
    'KY': 'Kentucky',
    'LA': 'Louisiana',
    'ME': 'Maine',
    'MD': 'Maryland',
    'MA': 'Massachusetts',
    'MI': 'Michigan',
    'MN': 'Minnesota',
    'MS': 'Mississippi',
    'MO': 'Missouri',
    'MT': 'Montana',
    'NE': 'Nebraska',
    'NV': 'Nevada',
    'NH': 'New Hampshire',
    'NJ': 'New Jersey',
    'NM': 'New Mexico',
    'NY': 'New York',
    'NC': 'North Carolina',
    'ND': 'North Dakota',
    'OH': 'Ohio',
    'OK': 'Oklahoma',
    'OR': 'Oregon',
    'PA': 'Pennsylvania',
    'RI': 'Rhode Island',
    'SC': 'South Carolina',
    'SD': 'South Dakota',
    'TN': 'Tennessee',
    'TX': 'Texas',
    'UT': 'Utah',
    'VT': 'Vermont',
    'VA': 'Virginia',
    'WA': 'Washington',
    'WV': 'West Virginia',
    'WI': 'Wisconsin',
    'WY': 'Wyoming',
  };

  static String stateLabel(String stateAbbr) {
    final abbr = stateAbbr.trim().toUpperCase();
    final name = stateNames[abbr] ?? abbr;
    return '$name ($abbr)';
  }

  List<School>? _utahSchools;
  Future<void>? _loadingUtah;

  bool isStateSupported(String stateAbbr) =>
      stateAbbr.trim().toUpperCase() == 'UT';

  bool isStateLoaded(String stateAbbr) =>
      isStateSupported(stateAbbr) && _utahSchools != null;

  bool isStateLoading(String stateAbbr) =>
      isStateSupported(stateAbbr) && _loadingUtah != null;

  Future<void> prefetchState(String stateAbbr) async {
    if (!isStateSupported(stateAbbr)) return;
    await _ensureUtahLoaded();
  }

  Future<List<School>> search({
    required String stateAbbr,
    required String query,
    int limit = 20,
  }) async {
    final normalizedState = stateAbbr.trim().toUpperCase();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    if (!isStateSupported(normalizedState)) {
      throw SchoolSearchException(
        'School search is only available for Utah right now. '
        'Select Utah (UT) or check back when more states are added.',
      );
    }

    await _ensureUtahLoaded();
    final schools = _utahSchools;
    if (schools == null || schools.isEmpty) {
      throw const SchoolSearchException(
        'Utah school directory could not be loaded. Please restart the app.',
      );
    }

    return _filterSchools(schools, q, limit);
  }

  List<School> _filterSchools(List<School> schools, String query, int limit) {
    final matches = <School>[];
    for (final school in schools) {
      final haystack =
          '${school.name} ${school.city} ${school.district}'.toLowerCase();
      if (haystack.contains(query)) {
        matches.add(school);
        if (matches.length >= limit) break;
      }
    }
    return matches;
  }

  Future<void> _ensureUtahLoaded() async {
    if (_utahSchools != null) return;
    if (_loadingUtah != null) {
      await _loadingUtah;
      return;
    }

    final future = _loadUtahSchools();
    _loadingUtah = future;
    try {
      await future;
    } finally {
      _loadingUtah = null;
    }
  }

  Future<void> _loadUtahSchools() async {
    try {
      final raw = await rootBundle.loadString(_utahCsvAsset);
      final rows = const CsvToListConverter().convert(raw);
      if (rows.isEmpty) {
        _utahSchools = const [];
        return;
      }

      final schools = <School>[];
      final seenIds = <String>{};

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 11) continue;

        final district = _cell(row, 0);
        final districtNum = _cell(row, 1);
        final name = _cell(row, 2);
        final schoolNum = _cell(row, 3);
        final city = _titleCase(_cell(row, 10));

        if (name.isEmpty) continue;

        final id = '$districtNum-$schoolNum';
        if (!seenIds.add(id)) continue;

        schools.add(
          School(
            id: id,
            name: name,
            city: city,
            state: 'UT',
            district: district,
          ),
        );
      }

      schools.sort((a, b) => a.name.compareTo(b.name));
      _utahSchools = schools;
    } catch (error) {
      throw SchoolSearchException(
        'Could not load Utah school directory. ($error)',
      );
    }
  }

  String _cell(List<dynamic> row, int index) {
    if (index >= row.length) return '';
    return row[index]
            ?.toString()
            .replaceAll('\r', '')
            .trim() ??
        '';
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }
}
