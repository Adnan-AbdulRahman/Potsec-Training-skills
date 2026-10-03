// admin.dart
//
// Potsec Skills Training — Admin Dashboard (performance-optimized)
// ---------------------------------------------------------
// Dependencies required in pubspec.yaml:
//   cloud_firestore: ^5.0.0
//   excel: ^4.0.3
//   file_saver: ^0.2.14
//   intl: ^0.19.0
//
// Reads live from the "registrations" Firestore collection created by
// the registration Homepage screen.
//
// WHAT CHANGED (to remove the lag):
//  1. Firestore stream is listened to ONCE (initState) and data is parsed ONCE
//     per snapshot, not on every rebuild.
//  2. Stats, region counts and dropdown options are cached, not recomputed
//     on every keystroke/rebuild.
//  3. Filtering + sorting only runs when the search/filter/sort changes.
//  4. DataTable (builds every row at once) replaced by a lazy ListView-based
//     table with fixed-height rows.
//  5. Rows load in pages of 30 as you scroll down (plus a "load more" button
//     fallback), so thousands of records never build at once.
//  6. AnimatedSwitcher/KeyedSubtree (rebuilt the whole table on every change)
//     removed. Per-card animations removed.
//  7. DateFormat objects are created once. Search text is pre-computed once.
//  8. RepaintBoundary around the pulsing "Live" dot and the header block.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:potsecskillstraining/admin/register.dart';

// Adjust this path if register_now.dart lives in a different folder.

class RegistrationModel {
  final String id;
  final bool consentGiven;
  final String name;
  final String gender;
  final String populationSegment;
  final bool hasDisability;
  final String disabilityType;
  final DateTime? dateOfBirth;
  final String contact;
  final String guardianContact;
  final String employmentStatus;
  final String settlement;
  final String community;
  final String district;
  final String region;
  final String institutionName;
  final String weekOneCourse;
  final String weekTwoCourse;
  final String weekThreeCourse;
  final String weekFourCourse;
  final String trainingCenter;
  final String preferredTime;
  final String registeredBy;
  final DateTime? createdAt;

  RegistrationModel({
    required this.id,
    required this.consentGiven,
    required this.name,
    required this.gender,
    required this.populationSegment,
    required this.hasDisability,
    required this.disabilityType,
    required this.dateOfBirth,
    required this.contact,
    required this.guardianContact,
    required this.employmentStatus,
    required this.settlement,
    required this.community,
    required this.district,
    required this.region,
    required this.institutionName,
    required this.weekOneCourse,
    required this.weekTwoCourse,
    required this.weekThreeCourse,
    required this.weekFourCourse,
    required this.trainingCenter,
    required this.preferredTime,
    required this.registeredBy,
    required this.createdAt,
  });

  // Pre-computed once (lazily) so searching does not lowercase 9 strings
  // for every record on every search.
  late final String searchText = [
    name,
    contact,
    guardianContact,
    settlement,
    community,
    district,
    region,
    registeredBy,
  ].join('|').toLowerCase();

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int a = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      a--;
    }
    return a;
  }

  factory RegistrationModel.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    DateTime? parseTs(dynamic v) => v is Timestamp ? v.toDate() : null;

    return RegistrationModel(
      id: doc.id,
      consentGiven: data['consentGiven'] == true,
      name: (data['name'] ?? '').toString(),
      gender: (data['gender'] ?? '').toString(),
      populationSegment: (data['populationSegment'] ?? '').toString(),
      hasDisability: data['hasDisability'] == true,
      disabilityType: (data['disabilityType'] ?? '').toString(),
      dateOfBirth: parseTs(data['dateOfBirth']),
      contact: (data['contact'] ?? '').toString(),
      guardianContact: (data['guardianContact'] ?? '').toString(),
      employmentStatus: (data['employmentStatus'] ?? '').toString(),
      settlement: (data['settlement'] ?? '').toString(),
      community: (data['community'] ?? '').toString(),
      district: (data['district'] ?? '').toString(),
      region: (data['region'] ?? '').toString(),
      institutionName: (data['institutionName'] ?? '').toString(),
      weekOneCourse: (data['weekOneCourse'] ?? '').toString(),
      weekTwoCourse: (data['weekTwoCourse'] ?? '').toString(),
      weekThreeCourse: (data['weekThreeCourse'] ?? '').toString(),
      weekFourCourse: (data['weekFourCourse'] ?? '').toString(),
      trainingCenter: (data['trainingCenter'] ?? '').toString(),
      preferredTime: (data['preferredTime'] ?? '').toString(),
      registeredBy: (data['registeredBy'] ?? '').toString(),
      createdAt: parseTs(data['createdAt']),
    );
  }
}

/// Table column definition. The position in [_AdminState._cols] is the
/// column index used for sorting.
class _Col {
  final String label;
  final double width;
  final bool sortable;
  const _Col(this.label, this.width, {this.sortable = false});
}

class Admin extends StatefulWidget {
  const Admin({super.key});

  @override
  State<Admin> createState() => _AdminState();
}

class _AdminState extends State<Admin> with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF2E7D32);

  static const List<String> _registeredByAssignOptions = ['Self Registered', 'SMFL'];

  // How many rows are shown at first, and how many more are added each time
  // the user scrolls near the bottom.
  static const int _pageSize = 30;
  static const double _rowHeight = 56;

  // Created once (creating DateFormat for every cell is slow).
  static final DateFormat _fullDateFmt = DateFormat('MMM d, yyyy - h:mm a');
  static final DateFormat _shortDateFmt = DateFormat('MMM d, yyyy');

  // Column index -> definition. Index numbers match the sort switch below.
  static const List<_Col> _cols = [
    _Col('Name', 180, sortable: true), // 0
    _Col('Gender', 100, sortable: true), // 1
    _Col('Population Segment', 170, sortable: true), // 2
    _Col('Date of Birth', 130, sortable: true), // 3
    _Col('Disability', 150), // 4
    _Col('Contact', 130), // 5
    _Col('Guardian Contact', 140), // 6
    _Col('Employment Status', 150, sortable: true), // 7
    _Col('Settlement', 140, sortable: true), // 8
    _Col('Community', 140), // 9
    _Col('District', 140), // 10
    _Col('Region', 140, sortable: true), // 11
    _Col('Registered By', 150, sortable: true), // 12
    _Col('Preferred Time', 130, sortable: true), // 13
    _Col('Registered', 190, sortable: true), // 14
    _Col('Actions', 110), // 15
  ];

  static final double _tableWidth = _cols.fold<double>(0, (s, c) => s + c.width);

  // Label -> column index, used by the explicit "Sort by" dropdown (so sorting
  // also works from the mobile card list, which has no table header to tap).
  static const List<MapEntry<String, int>> _sortOptions = [
    MapEntry('Name', 0),
    MapEntry('Gender', 1),
    MapEntry('Population Segment', 2),
    MapEntry('Date of Birth', 3),
    MapEntry('Employment Status', 7),
    MapEntry('Settlement', 8),
    MapEntry('Region', 11),
    MapEntry('Registered By', 12),
    MapEntry('Preferred Time', 13),
    MapEntry('Date Registered', 14),
  ];

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Scroll controllers (one per layout so they are never attached twice).
  final ScrollController _tableScroll = ScrollController();
  final ScrollController _cardScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  // ---- Data (cached) ----
  List<RegistrationModel> _all = [];
  List<RegistrationModel> _filtered = [];
  bool _loading = true;
  Object? _error;

  int _visibleCount = _pageSize;

  // Cached summary values
  int _total = 0;
  int _male = 0;
  int _female = 0;
  int _withDisability = 0;
  int _selfRegistered = 0;
  List<MapEntry<String, int>> _regionCounts = [];
  List<String> _regionOptions = [];
  List<String> _registeredByOptions = [];

  // ---- UI state ----
  String _searchQuery = '';
  String? _regionFilter;
  String? _registeredByFilter;

  int _sortColumnIndex = 14;
  bool _sortAscending = false;
  bool _isExporting = false;
  bool _showStats = true;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _tableScroll.addListener(() => _onScroll(_tableScroll));
    _cardScroll.addListener(() => _onScroll(_cardScroll));

    _listenToData();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    _tableScroll.dispose();
    _cardScroll.dispose();
    _hScroll.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  /// Listens to Firestore ONCE. Parsing + summary + filtering happen here,
  /// only when the data actually changes — not on every rebuild.
  void _listenToData() {
    _sub = FirebaseFirestore.instance
        .collection('registrations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
        _all = snap.docs.map((d) => RegistrationModel.fromDoc(d)).toList();
        _recomputeSummary();
        _applyFilters(resetPaging: false);
        if (mounted) {
          setState(() {
            _loading = false;
            _error = null;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _error = e;
            _loading = false;
          });
        }
      },
    );
  }

  void _recomputeSummary() {
    _total = _all.length;
    _male = 0;
    _female = 0;
    _withDisability = 0;
    _selfRegistered = 0;

    final regionMap = <String, int>{};
    final regionSet = <String>{};
    final regBySet = <String>{};

    for (final r in _all) {
      if (r.gender == 'Male') _male++;
      if (r.gender == 'Female') _female++;
      if (r.hasDisability) _withDisability++;
      if (r.registeredBy == 'Self Registered') _selfRegistered++;

      final region = r.region.trim();
      if (region.isNotEmpty) {
        regionMap[region] = (regionMap[region] ?? 0) + 1;
        regionSet.add(region);
      }
      final by = r.registeredBy.trim();
      if (by.isNotEmpty) regBySet.add(by);
    }

    _regionCounts = regionMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    _regionOptions = regionSet.toList()..sort();
    _registeredByOptions = regBySet.toList()..sort();

    // A dropdown crashes if its selected value is no longer in its items.
    if (_regionFilter != null && !_regionOptions.contains(_regionFilter)) {
      _regionFilter = null;
    }
    if (_registeredByFilter != null && !_registeredByOptions.contains(_registeredByFilter)) {
      _registeredByFilter = null;
    }
  }

  /// Filters + sorts [_all] into [_filtered]. Call inside setState when the UI
  /// must refresh. Only runs when search/filter/sort/data changes.
  void _applyFilters({bool resetPaging = true}) {
    final q = _searchQuery;

    final list = _all.where((r) {
      final matchesQuery = q.isEmpty || r.searchText.contains(q);
      final matchesRegion = _regionFilter == null || r.region == _regionFilter;
      final matchesRegisteredBy =
          _registeredByFilter == null || r.registeredBy == _registeredByFilter;
      return matchesQuery && matchesRegion && matchesRegisteredBy;
    }).toList();

    // Column order: Name(0) Gender(1) PopSegment(2) DOB(3) Disability(4) Contact(5)
    // GuardianContact(6) Employment(7) Settlement(8) Community(9) District(10)
    // Region(11) RegisteredBy(12) PreferredTime(13) Registered/createdAt(14) Actions(15)
    final fallbackDate = DateTime(2000);
    list.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 1:
          cmp = a.gender.compareTo(b.gender);
          break;
        case 2:
          cmp = a.populationSegment.compareTo(b.populationSegment);
          break;
        case 3:
          cmp = (a.dateOfBirth ?? fallbackDate).compareTo(b.dateOfBirth ?? fallbackDate);
          break;
        case 7:
          cmp = a.employmentStatus.compareTo(b.employmentStatus);
          break;
        case 8:
          cmp = a.settlement.toLowerCase().compareTo(b.settlement.toLowerCase());
          break;
        case 11:
          cmp = a.region.toLowerCase().compareTo(b.region.toLowerCase());
          break;
        case 12:
          cmp = a.registeredBy.toLowerCase().compareTo(b.registeredBy.toLowerCase());
          break;
        case 13:
          cmp = a.preferredTime.compareTo(b.preferredTime);
          break;
        case 14:
        default:
          cmp = (a.createdAt ?? fallbackDate).compareTo(b.createdAt ?? fallbackDate);
      }
      return _sortAscending ? cmp : -cmp;
    });

    _filtered = list;

    if (resetPaging) {
      _visibleCount = _pageSize;
      if (_tableScroll.hasClients) _tableScroll.jumpTo(0);
      if (_cardScroll.hasClients) _cardScroll.jumpTo(0);
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll-to-load
  // ---------------------------------------------------------------------------

  void _onScroll(ScrollController c) {
    if (!c.hasClients) return;
    final pos = c.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_visibleCount < _filtered.length) {
      setState(() {
        _visibleCount = min(_visibleCount + _pageSize, _filtered.length);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Search / sort handlers
  // ---------------------------------------------------------------------------

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.trim().toLowerCase();
        _applyFilters();
      });
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applyFilters();
    });
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return _fullDateFmt.format(dt);
  }

  String _formatShortDate(DateTime? dt) {
    if (dt == null) return '-';
    return _shortDateFmt.format(dt);
  }

  // ---------------------------------------------------------------------------
  // Delete / snack / dialogs
  // ---------------------------------------------------------------------------

  Future<bool?> _confirmDelete(RegistrationModel r) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Registration'),
        content: Text('Remove ${r.name}\'s registration? This cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteTap(RegistrationModel r) async {
    final confirmed = await _confirmDelete(r);
    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('registrations').doc(r.id).delete();
      if (mounted) _showSnack('${r.name} was removed.');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showDetailDialog(RegistrationModel r) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 660),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _primary.withOpacity(0.1),
                      child: Icon(Icons.person, color: _primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(r.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow('Gender', r.gender),
                        _detailRow('Population Segment', r.populationSegment),
                        _detailRow(
                            'Date of Birth',
                            r.dateOfBirth == null
                                ? '-'
                                : '${_formatShortDate(r.dateOfBirth)} (${r.age} yrs)'),
                        _detailRow('Disability',
                            r.hasDisability ? 'Yes - ${r.disabilityType}' : 'No'),
                        _detailRow('Contact', r.contact),
                        _detailRow('Guardian Contact', r.guardianContact),
                        _detailRow('Employment Status', r.employmentStatus),
                        _detailRow('Settlement', r.settlement),
                        _detailRow('Community', r.community),
                        _detailRow('District', r.district),
                        _detailRow('Region', r.region),
                        // Registered By appears right after Region
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 140,
                                child: Text('Registered By',
                                    style: TextStyle(color: Colors.black54, fontSize: 13)),
                              ),
                              Expanded(child: _registeredByField(r)),
                            ],
                          ),
                        ),
                        _detailRow('Preferred Time', r.preferredTime),
                        _detailRow('Consent', r.consentGiven ? 'Given' : 'Not given'),
                        _detailRow('Registered', _formatDate(r.createdAt)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleDeleteTap(r);
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: _primary),
                      child: const Text('Close', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _genderBadge(String gender) {
    final isFemale = gender.toLowerCase() == 'female';
    final color = isFemale ? Colors.pink : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        gender.isEmpty ? '-' : gender,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color.shade700, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _disabilityBadge(RegistrationModel r) {
    final color = r.hasDisability ? Colors.deepOrange : Colors.grey;
    final text = r.hasDisability
        ? (r.disabilityType.isEmpty ? 'Yes' : 'Yes: ${r.disabilityType}')
        : 'No';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color.shade700, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _assignRegisteredBy(RegistrationModel r, String value) async {
    await FirebaseFirestore.instance
        .collection('registrations')
        .doc(r.id)
        .update({'registeredBy': value});
    if (mounted) {
      _showSnack('Assigned "$value" to ${r.name.isEmpty ? 'this record' : r.name}.');
    }
  }

  Widget _registeredByField(RegistrationModel r) {
    if (r.registeredBy.trim().isNotEmpty) {
      return Text(r.registeredBy,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13));
    }
    return DropdownButton<String>(
      isDense: true,
      underline: const SizedBox.shrink(),
      hint: const Text('Assign', style: TextStyle(fontSize: 12, color: Colors.black45)),
      items: _registeredByAssignOptions
          .map((o) => DropdownMenuItem(
          value: o, child: Text(o, style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: (v) {
        if (v != null) _assignRegisteredBy(r, v);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _exportToExcel(List<RegistrationModel> data, {required String label}) async {
    if (data.isEmpty) {
      _showSnack('There is nothing to export.', isError: true);
      return;
    }

    setState(() => _isExporting = true);
    // Give the spinner a moment to paint before the heavy work starts.
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final workbook = excel_lib.Excel.createExcel();
      final sheet = workbook['Registrations'];
      workbook.setDefaultSheet('Registrations');

      sheet.appendRow([
        excel_lib.TextCellValue('Name'),
        excel_lib.TextCellValue('Gender'),
        excel_lib.TextCellValue('Population Segment'),
        excel_lib.TextCellValue('Date of Birth'),
        excel_lib.TextCellValue('Age'),
        excel_lib.TextCellValue('Has Disability'),
        excel_lib.TextCellValue('Disability Type'),
        excel_lib.TextCellValue('Contact'),
        excel_lib.TextCellValue('Guardian Contact'),
        excel_lib.TextCellValue('Employment Status'),
        excel_lib.TextCellValue('Settlement'),
        excel_lib.TextCellValue('Community'),
        excel_lib.TextCellValue('District'),
        excel_lib.TextCellValue('Region'),
        excel_lib.TextCellValue('Registered By'),
        excel_lib.TextCellValue('Institution'),
        excel_lib.TextCellValue('Week One Course'),
        excel_lib.TextCellValue('Week Two Course'),
        excel_lib.TextCellValue('Week Three Course'),
        excel_lib.TextCellValue('Week Four Course'),
        excel_lib.TextCellValue('Training Center'),
        excel_lib.TextCellValue('Preferred Time'),
        excel_lib.TextCellValue('Consent Given'),
        excel_lib.TextCellValue('Registered On'),
      ]);

      for (final r in data) {
        sheet.appendRow([
          excel_lib.TextCellValue(r.name),
          excel_lib.TextCellValue(r.gender),
          excel_lib.TextCellValue(r.populationSegment),
          excel_lib.TextCellValue(_formatShortDate(r.dateOfBirth)),
          excel_lib.TextCellValue(r.age?.toString() ?? '-'),
          excel_lib.TextCellValue(r.hasDisability ? 'Yes' : 'No'),
          excel_lib.TextCellValue(r.disabilityType),
          excel_lib.TextCellValue(r.contact),
          excel_lib.TextCellValue(r.guardianContact),
          excel_lib.TextCellValue(r.employmentStatus),
          excel_lib.TextCellValue(r.settlement),
          excel_lib.TextCellValue(r.community),
          excel_lib.TextCellValue(r.district),
          excel_lib.TextCellValue(r.region),
          excel_lib.TextCellValue(r.registeredBy),
          excel_lib.TextCellValue(r.institutionName),
          excel_lib.TextCellValue(r.weekOneCourse),
          excel_lib.TextCellValue(r.weekTwoCourse),
          excel_lib.TextCellValue(r.weekThreeCourse),
          excel_lib.TextCellValue(r.weekFourCourse),
          excel_lib.TextCellValue(r.trainingCenter),
          excel_lib.TextCellValue(r.preferredTime),
          excel_lib.TextCellValue(r.consentGiven ? 'Yes' : 'No'),
          excel_lib.TextCellValue(_formatDate(r.createdAt)),
        ]);
      }

      final bytes = workbook.save();
      if (bytes == null) {
        _showSnack('Could not build the Excel file.', isError: true);
        return;
      }

      final fileName =
          'potsec_registrations_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(bytes),
        mimeType: MimeType.microsoftExcel,
      );

      if (mounted) _showSnack('Exported ${data.length} $label record(s).');
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // App bar actions
  // ---------------------------------------------------------------------------

  void _openRegisterNow() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterNow()),
    );
  }

  Widget _buildRegisterNowAction() {
    final wide = MediaQuery.of(context).size.width >= 600;
    if (wide) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextButton.icon(
          onPressed: _openRegisterNow,
          icon: const Icon(Icons.how_to_reg_outlined, size: 18),
          label: const Text('Register Now'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }
    return IconButton(
      tooltip: 'Register Now',
      icon: const Icon(Icons.how_to_reg_outlined, color: Colors.white),
      onPressed: _openRegisterNow,
    );
  }

  Widget _buildSortControl() {
    return SizedBox(
      width: 210,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _sortColumnIndex,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                prefixIcon: const Icon(Icons.sort, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _sortOptions
                  .map((e) => DropdownMenuItem(
                value: e.value,
                child: Text('Sort: ${e.key}', overflow: TextOverflow.ellipsis),
              ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _sortColumnIndex = v;
                    _applyFilters();
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: _sortAscending ? 'Ascending' : 'Descending',
              icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
              onPressed: () => setState(() {
                _sortAscending = !_sortAscending;
                _applyFilters();
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      appBar: AppBar(
        backgroundColor: _primary,
        title: Row(
          children: [
            const Text('Admin Dashboard'),
            const SizedBox(width: 10),
            // Isolated so the pulse never repaints anything else.
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) =>
                    Opacity(opacity: _pulseAnimation.value, child: child),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration:
                  const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text('Live', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          _buildRegisterNowAction(),
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text('Something went wrong: $_error'));
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return isWide ? _buildWideLayout(constraints) : _buildNarrowLayout();
        },
      ),
    );
  }

  /// Desktop / tablet: header on top (can be hidden), lazy table below.
  Widget _buildWideLayout(BoxConstraints constraints) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.55),
          child: SingleChildScrollView(
            child: RepaintBoundary(
              child: Column(
                children: [
                  if (_showStats) ...[
                    _buildStatsRow(),
                    _buildRegionStatsRow(),
                  ],
                  _buildToolbar(showStatsToggle: true),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty ? _buildEmptyState() : _buildTable(),
        ),
      ],
    );
  }

  /// Phone / narrow: everything scrolls together; cards are built lazily.
  Widget _buildNarrowLayout() {
    final visible = min(_visibleCount, _filtered.length);
    final hasMore = visible < _filtered.length;

    return CustomScrollView(
      controller: _cardScroll,
      slivers: [
        SliverToBoxAdapter(
          child: RepaintBoundary(
            child: Column(
              children: [
                _buildStatsRow(),
                _buildRegionStatsRow(),
                _buildToolbar(showStatsToggle: false),
              ],
            ),
          ),
        ),
        if (_filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  if (index >= visible) return _buildLoadMoreFooter(visible);
                  return _buildCard(_filtered[index]);
                },
                childCount: visible + (hasMore ? 1 : 0),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header widgets
  // ---------------------------------------------------------------------------

  Widget _buildStatsRow() {
    final stats = [
      ('Total Registered', _total, Icons.groups_2_outlined, _primary),
      ('Male', _male, Icons.male_outlined, Colors.blue),
      ('Female', _female, Icons.female_outlined, Colors.pink),
      ('With Disability', _withDisability, Icons.accessible_outlined, Colors.deepOrange),
      ('Self Registered', _selfRegistered, Icons.how_to_reg_outlined, Colors.teal),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(stats.length, (i) {
          final s = stats[i];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + i * 120),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.scale(scale: value.clamp(0.0, 1.0), child: child),
              );
            },
            child: _statCard(s.$1, s.$2, s.$3, s.$4),
          );
        }),
      ),
    );
  }

  Widget _buildRegionStatsRow() {
    if (_regionCounts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              'By Region',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _regionCounts.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: _primary),
                    const SizedBox(width: 6),
                    Text(e.key,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${e.value}',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold, color: _primary),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color color) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: value),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (context, val, _) => Text(
                  '$val',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar({required bool showStatsToggle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search name, contact, location...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          _buildSortControl(),
          _filterDropdown(
            value: _regionFilter,
            hint: 'All Regions',
            items: _regionOptions,
            width: 200,
            onChanged: (v) => setState(() {
              _regionFilter = v;
              _applyFilters();
            }),
          ),
          _filterDropdown(
            value: _registeredByFilter,
            hint: 'All Registered By',
            items: _registeredByOptions,
            width: 200,
            onChanged: (v) => setState(() {
              _registeredByFilter = v;
              _applyFilters();
            }),
          ),
          ElevatedButton.icon(
            onPressed: _isExporting ? null : () => _exportToExcel(_filtered, label: 'filtered'),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Export Filtered'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isExporting ? null : () => _exportToExcel(_all, label: 'total'),
            icon: const Icon(Icons.download_for_offline_outlined, size: 18),
            label: const Text('Export All'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (showStatsToggle)
            TextButton.icon(
              onPressed: () => setState(() => _showStats = !_showStats),
              icon: Icon(_showStats ? Icons.unfold_less : Icons.unfold_more, size: 18),
              label: Text(_showStats ? 'Hide stats' : 'Show stats'),
              style: TextButton.styleFrom(foregroundColor: _primary),
            ),
          Text(
            '${_filtered.length} of ${_all.length} shown',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double width = 180,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String?>(
        value: value,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: [
          DropdownMenuItem(value: null, child: Text(hint, overflow: TextOverflow.ellipsis)),
          ...items.map(
                  (i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: Colors.black26),
          const SizedBox(height: 12),
          const Text('No registrations found', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildLoadMoreFooter(int visible) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: TextButton.icon(
          onPressed: _loadMore,
          icon: const Icon(Icons.expand_more),
          label: Text('Showing $visible of ${_filtered.length} - load more'),
          style: TextButton.styleFrom(foregroundColor: _primary),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Lazy table (wide screens)
  // ---------------------------------------------------------------------------

  Widget _buildTable() {
    final visible = min(_visibleCount, _filtered.length);
    final hasMore = visible < _filtered.length;

    return LayoutBuilder(
      builder: (context, c) {
        final width = max(_tableWidth, c.maxWidth - 32);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Scrollbar(
              controller: _hScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      _buildHeaderRow(),
                      Expanded(
                        // Only the rows on screen are built. Rows are added in
                        // pages of [_pageSize] as the user scrolls down.
                        child: ListView.builder(
                          controller: _tableScroll,
                          itemExtent: _rowHeight,
                          itemCount: visible + (hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= visible) return _buildLoadMoreFooter(visible);
                            return _buildRow(_filtered[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow() {
    return Material(
      color: const Color(0xFFE8F5E9),
      child: SizedBox(
        height: 48,
        child: Row(
          children: List.generate(_cols.length, _headerCell),
        ),
      ),
    );
  }

  Widget _headerCell(int i) {
    final col = _cols[i];
    final active = col.sortable && _sortColumnIndex == i;

    final label = Row(
      children: [
        Flexible(
          child: Text(
            col.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        if (active)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: _primary,
            ),
          ),
      ],
    );

    return SizedBox(
      width: col.width,
      height: 48,
      child: InkWell(
        onTap: col.sortable ? () => _onSort(i, active ? !_sortAscending : true) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(alignment: Alignment.centerLeft, child: label),
        ),
      ),
    );
  }

  Widget _buildRow(RegistrationModel r) {
    Widget cell(int i, Widget child) => SizedBox(
      width: _cols[i].width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );

    Widget txt(int i, String s) => cell(
      i,
      Text(
        s.isEmpty ? '-' : s,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
    );

    return Material(
      key: ValueKey(r.id),
      color: Colors.white,
      child: InkWell(
        onTap: () => _showDetailDialog(r),
        hoverColor: _primary.withOpacity(0.05),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: Row(
            children: [
              txt(0, r.name),
              cell(1, _genderBadge(r.gender)),
              txt(2, r.populationSegment),
              txt(3, _formatShortDate(r.dateOfBirth)),
              cell(4, _disabilityBadge(r)),
              txt(5, r.contact),
              txt(6, r.guardianContact),
              txt(7, r.employmentStatus),
              txt(8, r.settlement),
              txt(9, r.community),
              txt(10, r.district),
              txt(11, r.region),
              cell(12, _registeredByField(r)),
              txt(13, r.preferredTime),
              txt(14, _formatDate(r.createdAt)),
              cell(
                15,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      onPressed: () => _showDetailDialog(r),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                      onPressed: () => _handleDeleteTap(r),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card (narrow screens)
  // ---------------------------------------------------------------------------

  Widget _buildCard(RegistrationModel r) {
    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(r),
      onDismissed: (_) {
        FirebaseFirestore.instance.collection('registrations').doc(r.id).delete();
        _showSnack('${r.name} was removed.');
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: _primary.withOpacity(0.1),
            child: Text(r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                style: TextStyle(color: _primary, fontWeight: FontWeight.bold)),
          ),
          title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(r.populationSegment),
          trailing: _genderBadge(r.gender),
          // Children are only built when the tile is expanded.
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Date of Birth', _formatShortDate(r.dateOfBirth)),
                  _detailRow(
                      'Disability', r.hasDisability ? 'Yes - ${r.disabilityType}' : 'No'),
                  _detailRow('Contact', r.contact),
                  _detailRow('Guardian Contact', r.guardianContact),
                  _detailRow('Employment Status', r.employmentStatus),
                  _detailRow('Settlement', r.settlement),
                  _detailRow('Community', r.community),
                  _detailRow('District', r.district),
                  _detailRow('Region', r.region),
                  // Registered By appears right after Region
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text('Registered By',
                              style: TextStyle(color: Colors.black54, fontSize: 13)),
                        ),
                        Expanded(child: _registeredByField(r)),
                      ],
                    ),
                  ),
                  _detailRow('Preferred Time', r.preferredTime),
                  _detailRow('Registered', _formatDate(r.createdAt)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showDetailDialog(r),
                        icon: const Icon(Icons.open_in_full, size: 16),
                        label: const Text('Full View'),
                      ),
                      TextButton.icon(
                        onPressed: () => _handleDeleteTap(r),
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}