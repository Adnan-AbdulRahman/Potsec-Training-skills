// register_now.dart
//
// Potsec Skills Training — On-site attendance registration
// ---------------------------------------------------------
// Dependencies (already used elsewhere in the app):
//   cloud_firestore, intl, excel, file_saver
//
// Reads pre-registered people from the "registrations" collection and saves
// the ones who actually showed up into a SEPARATE collection: "attendees".
// The attendee document ID is the registration ID, so the same person can
// never be registered twice.

import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class _Person {
  final String id;
  final String name;
  final String contact;
  final String guardianContact;
  final String gender;
  final String populationSegment;
  final String region;
  final String district;
  final String community;
  final String trainingCenter;
  final String preferredTime;
  final String registeredBy;

  _Person({
    required this.id,
    required this.name,
    required this.contact,
    required this.guardianContact,
    required this.gender,
    required this.populationSegment,
    required this.region,
    required this.district,
    required this.community,
    required this.trainingCenter,
    required this.preferredTime,
    required this.registeredBy,
  });

  factory _Person.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    String s(String k) => (d[k] ?? '').toString();
    return _Person(
      id: doc.id,
      name: s('name'),
      contact: s('contact'),
      guardianContact: s('guardianContact'),
      gender: s('gender'),
      populationSegment: s('populationSegment'),
      region: s('region'),
      district: s('district'),
      community: s('community'),
      trainingCenter: s('trainingCenter'),
      preferredTime: s('preferredTime'),
      registeredBy: s('registeredBy'),
    );
  }
}

class _Attendee {
  final String id; // same as the registration ID
  final String name;
  final String contact;
  final DateTime? checkedInAt;

  _Attendee({
    required this.id,
    required this.name,
    required this.contact,
    required this.checkedInAt,
  });

  factory _Attendee.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final ts = d['checkedInAt'];
    return _Attendee(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      contact: (d['contact'] ?? '').toString(),
      checkedInAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class _AlreadyRegistered implements Exception {}

class RegisterNow extends StatefulWidget {
  const RegisterNow({super.key});

  @override
  State<RegisterNow> createState() => _RegisterNowState();
}

class _RegisterNowState extends State<RegisterNow> {
  static const Color _primary = Color(0xFF2E7D32);
  static const String _registrationsCollection = 'registrations';
  static const String _attendeesCollection = 'attendees';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  String _query = '';
  final Set<String> _busyIds = {};
  bool _isExporting = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Search logic
  // ---------------------------------------------------------------------
  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  bool _looksNumeric(String q) =>
      q.isNotEmpty && !RegExp(r'[A-Za-z]').hasMatch(q) && _digits(q).isNotEmpty;

  bool _phoneMatches(String phone, String qDigits) {
    final p = _digits(phone);
    if (p.isEmpty) return false;
    if (p.contains(qDigits)) return true;
    // Handles 055... typed against +233 55... stored (and vice versa).
    if (qDigits.startsWith('0') && p.contains(qDigits.substring(1))) return true;
    return false;
  }

  List<_Person> _search(List<_Person> people) {
    final q = _query.trim().toLowerCase();
    if (q.length < 2) return [];

    final List<_Person> out;
    if (_looksNumeric(q)) {
      final qd = _digits(q);
      out = people
          .where((p) => _phoneMatches(p.contact, qd) || _phoneMatches(p.guardianContact, qd))
          .toList();
    } else {
      final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      out = people.where((p) {
        final name = p.name.toLowerCase();
        return tokens.every(name.contains);
      }).toList();
    }

    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out.take(30).toList();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  // ---------------------------------------------------------------------
  // Register / undo
  // ---------------------------------------------------------------------
  Future<void> _checkIn(_Person p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Register this person?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _dialogLine(Icons.phone_outlined, p.contact),
            _dialogLine(Icons.location_on_outlined, p.trainingCenter),
            _dialogLine(Icons.schedule_outlined, p.preferredTime),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.how_to_reg_outlined, size: 18),
            label: const Text('Register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyIds.add(p.id));
    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection(_attendeesCollection).doc(p.id);
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) throw _AlreadyRegistered();
        tx.set(ref, {
          'registrationId': p.id,
          'name': p.name,
          'contact': p.contact,
          'guardianContact': p.guardianContact,
          'gender': p.gender,
          'populationSegment': p.populationSegment,
          'region': p.region,
          'district': p.district,
          'community': p.community,
          'trainingCenter': p.trainingCenter,
          'preferredTime': p.preferredTime,
          'registeredBy': p.registeredBy,
          'checkedInAt': FieldValue.serverTimestamp(),
        });
      });
      if (!mounted) return;
      _snack('${p.name} has been registered.');
      // Ready for the next person in the queue.
      _searchController.clear();
      setState(() => _query = '');
      _focusNode.requestFocus();
    } on _AlreadyRegistered {
      if (mounted) _snack('${p.name} is already registered.', isError: true);
    } catch (e) {
      if (mounted) _snack('Could not register: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(p.id));
    }
  }

  Future<void> _undo(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Undo registration?'),
        content: Text('$name will be removed from the attendance list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Undo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyIds.add(id));
    try {
      await FirebaseFirestore.instance.collection(_attendeesCollection).doc(id).delete();
      if (mounted) _snack('$name removed from attendance.');
    } catch (e) {
      if (mounted) _snack('Could not undo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : _primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  // ---------------------------------------------------------------------
  // Export (Name + Contact only)
  // ---------------------------------------------------------------------
  Future<void> _exportAttendees() async {
    setState(() => _isExporting = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_attendeesCollection)
          .orderBy('checkedInAt', descending: true)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) _snack('No registered people to export yet.', isError: true);
        return;
      }

      final attendees = snap.docs.map(_Attendee.fromDoc).toList();

      final workbook = excel_lib.Excel.createExcel();
      final sheet = workbook['Registered'];
      workbook.setDefaultSheet('Registered');

      sheet.appendRow([
        excel_lib.TextCellValue('Name'),
        excel_lib.TextCellValue('Contact'),
      ]);

      for (final a in attendees) {
        sheet.appendRow([
          excel_lib.TextCellValue(a.name),
          excel_lib.TextCellValue(a.contact),
        ]);
      }

      final bytes = workbook.save();
      if (bytes == null) {
        if (mounted) _snack('Could not build the Excel file.', isError: true);
        return;
      }

      final fileName =
          'potsec_registered_attendees_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(bytes),

        mimeType: MimeType.microsoftExcel,
      );

      if (mounted) _snack('Exported ${attendees.length} registered ${attendees.length == 1 ? 'person' : 'people'}.');
    } catch (e) {
      if (mounted) _snack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ---------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------
  String _timeLabel(DateTime? t) {
    if (t == null) return 'just now';
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? DateFormat('h:mm a').format(t) : DateFormat('MMM d, h:mm a').format(t);
  }

  Widget _dialogLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black45),
          const SizedBox(width: 8),
          Expanded(child: Text(text.isEmpty ? '-' : text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: const Text('Register Attendance'),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              tooltip: 'Download registered (name & contact)',
              icon: const Icon(Icons.download_outlined),
              onPressed: _exportAttendees,
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection(_registrationsCollection).snapshots(),
        builder: (context, regSnap) {
          if (regSnap.hasError) {
            return Center(child: Text('Something went wrong: ${regSnap.error}'));
          }
          if (!regSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final people = regSnap.data!.docs.map(_Person.fromDoc).toList();
          final peopleIds = people.map((p) => p.id).toSet();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(_attendeesCollection)
                .orderBy('checkedInAt', descending: true)
                .snapshots(),
            builder: (context, attSnap) {
              if (attSnap.hasError) {
                return Center(child: Text('Something went wrong: ${attSnap.error}'));
              }
              if (!attSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final attendees = attSnap.data!.docs.map(_Attendee.fromDoc).toList();
              final attendeeMap = {for (final a in attendees) a.id: a};

              final registeredCount = attendees.where((a) => peopleIds.contains(a.id)).length;
              final remaining = (people.length - registeredCount).clamp(0, people.length);

              final results = _search(people);
              final searching = _query.trim().length >= 2;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    children: [
                      _buildStats(people.length, registeredCount, remaining),
                      _buildSearchField(),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: searching
                              ? _buildResults(results, attendeeMap)
                              : _buildRecent(attendees),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStats(int total, int registered, int remaining) {
    final stats = [
      ('Pre-registered', total, Icons.groups_2_outlined, _primary),
      ('Registered today', registered, Icons.how_to_reg_outlined, Colors.teal),
      ('Yet to arrive', remaining, Icons.hourglass_empty_outlined, Colors.orange),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: List.generate(stats.length, (i) {
          final s = stats[i];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == stats.length - 1 ? 0 : 10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 350 + i * 120),
                curve: Curves.easeOutBack,
                builder: (context, v, child) => Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.scale(scale: v.clamp(0.0, 1.0), child: child),
                ),
                child: _statCard(s.$1, s.$2, s.$3, s.$4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  builder: (context, val, _) => Text('$val',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        autofocus: true,
        onChanged: (v) {
          _onQueryChanged(v);
          setState(() {}); // refresh the clear button immediately
        },
        decoration: InputDecoration(
          hintText: 'Search by name or phone number',
          prefixIcon: const Icon(Icons.search, color: _primary),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.close), onPressed: _clearSearch),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(List<_Person> results, Map<String, _Attendee> attendeeMap) {
    if (results.isEmpty) {
      return Center(
        key: const ValueKey('no-results'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.person_search_outlined, size: 64, color: Colors.black26),
            SizedBox(height: 12),
            Text('No pre-registered person found', style: TextStyle(color: Colors.black54)),
            SizedBox(height: 4),
            Text('Check the spelling or try the phone number',
                style: TextStyle(color: Colors.black38, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      key: ValueKey('results-$_query'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final p = results[index];
        final attendee = attendeeMap[p.id];
        final delay = (index * 40).clamp(0, 300);
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 250 + delay),
          curve: Curves.easeOut,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child),
          ),
          child: _personCard(p, attendee),
        );
      },
    );
  }

  Widget _personCard(_Person p, _Attendee? attendee) {
    final isRegistered = attendee != null;
    final busy = _busyIds.contains(p.id);
    final isFemale = p.gender.toLowerCase() == 'female';
    final genderColor = isFemale ? Colors.pink : Colors.blue;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRegistered ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isRegistered ? _primary.withOpacity(0.5) : Colors.transparent),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: genderColor.withOpacity(0.12),
            child: Text(
              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
              style: TextStyle(color: genderColor.shade700, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name.isEmpty ? '(no name)' : p.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text([p.contact, p.gender].where((e) => e.isNotEmpty).join(' • '),
                    style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                Text(
                  [p.district, p.region].where((e) => e.isNotEmpty).join(', '),
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
                Text(
                  [p.trainingCenter, p.preferredTime].where((e) => e.isNotEmpty).join(' • '),
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _primary),
            )
          else if (isRegistered)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Registered',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(_timeLabel(attendee.checkedInAt),
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
                InkWell(
                  onTap: () => _undo(p.id, p.name),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('Undo',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.redAccent,
                            decoration: TextDecoration.underline)),
                  ),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: () => _checkIn(p),
              icon: const Icon(Icons.how_to_reg_outlined, size: 18),
              label: const Text('Register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecent(List<_Attendee> attendees) {
    if (attendees.isEmpty) {
      return Center(
        key: const ValueKey('recent-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.how_to_reg_outlined, size: 64, color: Colors.black26),
            SizedBox(height: 12),
            Text('Nobody registered yet', style: TextStyle(color: Colors.black54)),
            SizedBox(height: 4),
            Text('Search a name or phone number above to register someone',
                style: TextStyle(color: Colors.black38, fontSize: 12)),
          ],
        ),
      );
    }

    final recent = attendees.take(15).toList();
    return ListView(
      key: const ValueKey('recent-list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6, left: 4),
          child: Text('Recently registered',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
        ),
        ...List.generate(recent.length, (i) {
          final a = recent[i];
          final busy = _busyIds.contains(a.id);
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 250 + (i * 30).clamp(0, 300)),
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: _primary.withOpacity(0.1),
                  child: const Icon(Icons.check, size: 16, color: _primary),
                ),
                title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${a.contact}  •  ${_timeLabel(a.checkedInAt)}'),
                trailing: busy
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                )
                    : IconButton(
                  tooltip: 'Undo',
                  icon: const Icon(Icons.undo, size: 18, color: Colors.redAccent),
                  onPressed: () => _undo(a.id, a.name),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}