// admin_dashboard.dart
//
// Potsec Skills Training — Admin Dashboard home screen
// ---------------------------------------------------------
// Dependencies required in pubspec.yaml:
//   cloud_firestore: ^5.0.0
//   excel: ^4.0.3
//   file_saver: ^0.2.14
//   intl: ^0.19.0
//
// This is the landing screen for admin/staff: a live region breakdown up
// top, then a grid of navigation cards into the rest of the app.
//
// Adjust these three imports to match where the files actually live in
// your project.
import 'package:potsecskillstraining/admin/add%20portfolio.dart';
import 'package:potsecskillstraining/admin/attendance.dart';

import 'admin.dart'; // class Admin — people who filled the registration form
import 'not register.dart';
import 'register.dart'; // class RegisterNow — search & register attendees

import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const Color _primary = Color(0xFF2E7D32);

  bool _isExporting = false;

  // ---------------------------------------------------------------------
  // Small data helpers (kept local to this file, no shared model needed)
  // ---------------------------------------------------------------------
  String _str(Map<String, dynamic> d, String key) => (d[key] ?? '').toString();

  Map<String, int> _countBy(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      String key,
      ) {
    final counts = <String, int>{};
    for (final doc in docs) {
      final value = _str(doc.data(), key).trim();
      if (value.isEmpty) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts;
  }

  // ---------------------------------------------------------------------
  // Export (full registrations, same shape as the Admin page's export)
  // ---------------------------------------------------------------------
  Future<void> _exportAllRegistrations(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) async {
    if (docs.isEmpty) {
      _snack('There is nothing to export yet.', isError: true);
      return;
    }

    setState(() => _isExporting = true);
    try {
      final workbook = excel_lib.Excel.createExcel();
      final sheet = workbook['Registrations'];
      workbook.setDefaultSheet('Registrations');

      sheet.appendRow([
        excel_lib.TextCellValue('Name'),
        excel_lib.TextCellValue('Gender'),
        excel_lib.TextCellValue('Population Segment'),
        excel_lib.TextCellValue('Contact'),
        excel_lib.TextCellValue('Guardian Contact'),
        excel_lib.TextCellValue('Employment Status'),
        excel_lib.TextCellValue('Settlement'),
        excel_lib.TextCellValue('Community'),
        excel_lib.TextCellValue('District'),
        excel_lib.TextCellValue('Region'),
        excel_lib.TextCellValue('Registered By'),
        excel_lib.TextCellValue('Institution'),
        excel_lib.TextCellValue('Training Center'),
        excel_lib.TextCellValue('Preferred Time'),
      ]);

      for (final doc in docs) {
        final d = doc.data();
        sheet.appendRow([
          excel_lib.TextCellValue(_str(d, 'name')),
          excel_lib.TextCellValue(_str(d, 'gender')),
          excel_lib.TextCellValue(_str(d, 'populationSegment')),
          excel_lib.TextCellValue(_str(d, 'contact')),
          excel_lib.TextCellValue(_str(d, 'guardianContact')),
          excel_lib.TextCellValue(_str(d, 'employmentStatus')),
          excel_lib.TextCellValue(_str(d, 'settlement')),
          excel_lib.TextCellValue(_str(d, 'community')),
          excel_lib.TextCellValue(_str(d, 'district')),
          excel_lib.TextCellValue(_str(d, 'region')),
          excel_lib.TextCellValue(_str(d, 'registeredBy')),
          excel_lib.TextCellValue(_str(d, 'institutionName')),
          excel_lib.TextCellValue(_str(d, 'trainingCenter')),
          excel_lib.TextCellValue(_str(d, 'preferredTime')),
        ]);
      }

      final bytes = workbook.save();
      if (bytes == null) {
        _snack('Could not build the Excel file.', isError: true);
        return;
      }

      final fileName =
          'potsec_registrations_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(bytes),

        mimeType: MimeType.microsoftExcel,
      );

      _snack('Exported ${docs.length} record(s).');
    } catch (e) {
      _snack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
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
  // Breakdown dialogs (Training Centers / Analytics Overview)
  // ---------------------------------------------------------------------
  void _showBreakdownDialog(String title, Map<String, int> counts, IconData icon) {
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: _primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                    child: Text('No data yet', style: TextStyle(color: Colors.black54)),
                  )
                      : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(e.key,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('${e.value}',
                                  style: TextStyle(
                                      color: _primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: _primary),
                    child: const Text('Close', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAnalyticsDialog(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final byGender = _countBy(docs, 'gender');
    final byPopulation = _countBy(docs, 'populationSegment');
    final byEmployment = _countBy(docs, 'employmentStatus');
    final withDisability = docs.where((d) => d.data()['hasDisability'] == true).length;
    final withoutDisability = docs.length - withDisability;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insights_outlined, color: _primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Analytics Overview',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    children: [
                      _analyticsSection('Gender', byGender),
                      _analyticsSection('Population Segment', byPopulation),
                      _analyticsSection('Employment Status', byEmployment),
                      _analyticsSection('Disability', {
                        'With disability': withDisability,
                        'Without disability': withoutDisability,
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: _primary),
                    child: const Text('Close', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _analyticsSection(String title, Map<String, int> counts) {
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 6),
          if (entries.isEmpty)
            const Text('No data yet', style: TextStyle(color: Colors.black38, fontSize: 12))
          else
            ...entries.map(
                  (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                    Text('${e.value}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openSettingsPlaceholder() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF4F7F2),
          appBar: AppBar(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            title: const Text('Settings'),
          ),
          body: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings_outlined, size: 64, color: Colors.black26),
                SizedBox(height: 12),
                Text('Settings coming soon', style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ),
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
        title: const Text('Admin Dashboard'),
        actions: [
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('registrations').snapshots(),
        builder: (context, regSnap) {
          if (regSnap.hasError) {
            return Center(child: Text('Something went wrong: ${regSnap.error}'));
          }
          if (!regSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final regDocs = regSnap.data!.docs;
          final regionCounts = _countBy(regDocs, 'region');
          final trainingCenterCounts = _countBy(regDocs, 'trainingCenter');
          final registrationIds = regDocs.map((d) => d.id).toSet();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('attendees').snapshots(),
            builder: (context, attSnap) {
              final attDocs = attSnap.data?.docs ?? [];
              final registeredCount =
                  attDocs.where((d) => registrationIds.contains(d.id)).length;
              final notRegisteredCount =
              (regDocs.length - registeredCount).clamp(0, regDocs.length);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 10),
                      child: Text('By Region',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
                    ),
                    _buildRegionStrip(regionCounts),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 12),
                      child: Text('Go to',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                    _buildNavGrid(
                      regDocs: regDocs,
                      totalForms: regDocs.length,
                      registeredCount: registeredCount,
                      notRegisteredCount: notRegisteredCount,
                      trainingCenterCounts: trainingCenterCounts,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRegionStrip(Map<String, int> regionCounts) {
    if (regionCounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('No registrations yet', style: TextStyle(color: Colors.black54)),
      );
    }

    final entries = regionCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(entries.length, (i) {
        final e = entries[i];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + i * 60),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.scale(scale: v.clamp(0.0, 1.0), child: child),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: _primary),
                const SizedBox(width: 6),
                Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${e.value}',
                      style:
                      const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _primary)),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNavGrid({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> regDocs,
    required int totalForms,
    required int registeredCount,
    required int notRegisteredCount,
    required Map<String, int> trainingCenterCounts,
  }) {
    final items = <_DashCard>[
      _DashCard(
        title: 'Registration Forms',
        subtitle: 'People who filled the form',
        icon: Icons.assignment_outlined,
        count: totalForms,
        color: _primary,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Admin())),
      ),
      _DashCard(
        title: 'Registered Attendees',
        subtitle: 'People who have checked in',
        icon: Icons.how_to_reg_outlined,
        count: registeredCount,
        color: Colors.teal,
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterNow())),
      ),
      _DashCard(
        title: 'Not Yet Registered',
        subtitle: 'Pre-registered, still to arrive',
        icon: Icons.hourglass_empty_outlined,
        count: notRegisteredCount,
        color: Colors.orange,
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotRegister())),
      ),
      _DashCard(
        title: 'Export Reports',
        subtitle: 'Download all forms as Excel',
        icon: Icons.download_outlined,
        count: null,
        color: Colors.indigo,
        onTap: () => _exportAllRegistrations(regDocs),
      ),
      _DashCard(
        title: 'Attendance',
        subtitle: 'Attendance Systemn',
        icon: Icons.apartment_outlined,
        count: trainingCenterCounts.length,
        color: Colors.brown,
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Attendance())),
      ),
      _DashCard(
        title: 'Add My Portfolio',
        subtitle: 'Portfolio Of The Training',
        icon: Icons.insights_outlined,
        count: null,
        color: Colors.deepPurple,
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddPortfolio())),

      ),
      _DashCard(
        title: 'Settings',
        subtitle: 'App preferences',
        icon: Icons.settings_outlined,
        count: null,
        color: Colors.blueGrey,
        onTap: _openSettingsPlaceholder,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
            ? 3
            : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + index * 70),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.scale(scale: v.clamp(0.0, 1.0), child: child),
              ),
              child: _navCard(item),
            );
          },
        );
      },
    );
  }

  Widget _navCard(_DashCard item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  if (item.count != null)
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: item.count!),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      builder: (context, val, _) => Text(
                        '$val',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold, color: item.color),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(item.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final int? count;
  final Color color;
  final VoidCallback onTap;

  _DashCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
  });
}