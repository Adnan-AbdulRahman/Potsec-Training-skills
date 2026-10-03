import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:potsecskillstraining/admin/dashboard.dart';


class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF2E7D32);

  final _formKey = GlobalKey<FormState>();

  // Personal
  final _nameController = TextEditingController();

  // Contact
  final _contactController = TextEditingController();
  final _guardianContactController = TextEditingController();

  // Background
  final _communityController = TextEditingController();

  // Programme
  final _registeredByController = TextEditingController();

  // Fixed / non-editable programme fields
  final _institutionController =
  TextEditingController(text: 'PRINCE OSEI-TUTU SKILLS AND ENTREPRENEURIAL COLLEGE');

  // Admin password dialog controller
  final _adminPasswordController = TextEditingController();

  // Change this to update the admin password
  static const String _adminPassword = '4296';

  String? _selectedGender;
  String? _selectedPopulationSegment;
  String? _selectedEmploymentStatus;
  bool? _hasDisability;
  String? _selectedDisabilityType;
  String? _selectedSettlement;
  String? _selectedRegion;
  String? _selectedDistrict;
  String? _selectedTrainingCenter;
  String? _selectedPreferredTime;
  String? _registeredByOption;
  DateTime? _dateOfBirth;
  bool _consentGiven = false;

  bool _isSubmitting = false;
  bool _isHoveringSubmit = false;
  bool _isHoveringFab = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  double _formProgress = 0.0;

  static const List<String> _genderOptions = ['Male', 'Female'];

  static const List<String> _populationSegments = [
    'Refugee',
    'Internally displaced',
    'Disability person',
    'Refugee with disability',
    'Internally Displaced with disability',
    'N/A',
  ];

  static const List<String> _employmentStatuses = [
    'Employed',
    'Self employed',
    'Need Employment',
  ];

  static const List<String> _disabilityTypes = [
    'Albinism',
    'Epilepsy',
    'Hearing Impairment',
    'Speech Impairment',
    'Intellectual Disability',
    'Little person',
    'Mental Disability',
    'Physical Impairment',
    'Speech Impairment',
    'Visual Impairment',
  ];

  // TODO: replace with your actual settlement/camp names
  static const List<String> _settlements = [
    'Rural',
    'Peri-Urban',
    'Urban',
  ];

  static const List<String> _regions = [


    'Ashanti',
    'Greater Accra',
    'Bono',
    'Bono East',
    'Central',
    'Eastern',

    'Oti',
    'Savannah',
    'Upper East',
    'Upper West',
    'Volta',
    'Western',
    'Western North',
    'Ahafo',

    'North East',
    'Northern',
  ];

  // Districts (MMDAs) grouped by region.
  static const Map<String, List<String>> _districtsByRegion = {

    'Ashanti': [
      'Adansi Asokwa',
      'Adansi North',
      'Adansi South',
      'Afigya-Kwabre North',
      'Afigya-Kwabre South',
      'Ahafo-Ano North',
      'Ahafo-Ano South East',
      'Ahafo-Ano South West',
      'Akrofuom',
      'Amansie Central',
      'Amansie West',
      'Amansie South',
      'Asante-Akim Central',
      'Asante-Akim North',
      'Asante-Akim South',
      'Asokore-Mampong',
      'Asokwa',
      'Atwima-Kwanwoma',
      'Atwima-Mponua',
      'Atwima-Nwabiagya',
      'Atwima-Nwabiagya North',
      'Bekwai',
      'Bosome Freho',
      'Bosomtwe',
      'Ejisu',
      'Ejura/Sekyedumase',
      'Juaben',
      'Kumasi',
      'Kwabre East',
      'Kwadaso',
      'Mampong',
      'Obuasi East',
      'Obuasi',
      'Offinso',
      'Offinso North',
      'Oforikrom',
      'Old Tafo',
      'Sekyere Afram Plains',
      'Sekyere Central',
      'Sekyere East',
      'Sekyere Kumawu',
      'Sekyere South',
      'Suame',
    ],
    'Greater Accra': [
      'Ablekuma Central',
      'Ablekuma North',
      'Ablekuma West',
      'Accra',
      'Ada East',
      'Ada West',
      'Adenta',
      'Ashaiman',
      'Ayawaso Central',
      'Ayawaso East',
      'Ayawaso North',
      'Ayawaso West',
      'Ga Central',
      'Ga East',
      'Ga North',
      'Ga South',
      'Ga West',
      'Korle-Klottey',
      'Kpone-Katamanso',
      'Krowor',
      'La-Dade-Kotopon',
      'La-Nkwantanang-Madina',
      'Ledzokuku',
      'Ningo-Prampram',
      'Okaikwei North',
      'Shai-Osudoku',
      'Tema',
      'Tema West',
      'Weija Gbawe',
    ],
    'Bono': [
      'Banda',
      'Berekum East',
      'Berekum West',
      'Dormaa Central',
      'Dormaa East',
      'Dormaa West',
      'Jaman North',
      'Jaman South',
      'Sunyani',
      'Sunyani West',
      'Tain',
      'Wenchi',
    ],
    'Bono East': [
      'Atebubu-Amantin',
      'Kintampo North',
      'Kintampo South',
      'Nkoranza North',
      'Nkoranza South',
      'Pru East',
      'Pru West',
      'Sene East',
      'Sene West',
      'Techiman',
      'Techiman North',
    ],
    'Central': [
      'Abura/Asebu/Kwamankese',
      'Agona East',
      'Agona West',
      'Ajumako/Enyan/Essiam',
      'Asikuma Odoben Brakwa',
      'Assin Central',
      'Assin North',
      'Assin South',
      'Awutu Senya East',
      'Awutu Senya West',
      'Cape Coast',
      'Effutu',
      'Ekumfi',
      'Gomoa East',
      'Gomoa Central',
      'Gomoa West',
      'Komenda/Edina/Eguafo/Abirem',
      'Mfantsiman',
      'Twifo Atti Morkwa',
      'Twifo/Hemang/Lower Denkyira',
      'Upper Denkyira East',
      'Upper Denkyira West',
    ],
    'Eastern': [
      'Abuakwa North',
      'Abuakwa South',
      'Achiase',
      'Akuapim North',
      'Akuapim South',
      'Akyemansa',
      'Asene Manso Akroso',
      'Asuogyaman',
      'Atiwa East',
      'Atiwa West',
      'Ayensuano',
      'Birim Central',
      'Birim North',
      'Birim South',
      'Denkyembour',
      'Fanteakwa North',
      'Fanteakwa South',
      'Kwaebibirem',
      'Kwahu Afram Plains North',
      'Kwahu Afram Plains South',
      'Kwahu East',
      'Kwahu South',
      'Kwahu West',
      'Lower Manya Krobo',
      'New Juaben North',
      'New Juaben South',
      'Nsawam Adoagyire',
      'Okere',
      'Suhum',
      'Upper Manya Krobo',
      'Upper West Akim',
      'West Akim',
      'Yilo-Krobo',
    ],


    'Oti': [
      'Biakoye',
      'Guan',
      'Jasikan',
      'Kadjebi',
      'Krachi East',
      'Krachi Nchumuru',
      'Krachi West',
      'Nkwanta North',
      'Nkwanta South',
    ],
    'Savannah': [
      'Bole',
      'Central Gonja',
      'East Gonja',
      'North Gonja',
      'North East Gonja',
      'Sawla-Tuna-Kalba',
      'West Gonja',
    ],
    'Upper East': [
      'Bawku',
      'Bawku West',
      'Binduri',
      'Bolgatanga East',
      'Bolgatanga',
      'Bongo',
      'Builsa North',
      'Builsa South',
      'Garu',
      'Kassena-Nankana',
      'Kassena-Nankana West',
      'Nabdam',
      'Pusiga',
      'Talensi',
      'Tempane',
    ],
    'Upper West': [
      'Daffiama Bussie Issa',
      'Jirapa',
      'Lambussie Karni',
      'Lawra',
      'Nadowli-Kaleo',
      'Nandom',
      'Sissala East',
      'Sissala West',
      'Wa East',
      'Wa',
      'Wa West',
    ],
    'Volta': [
      'Adaklu',
      'Afadzato South',
      'Agotime Ziope',
      'Akatsi North',
      'Akatsi South',
      'Anloga',
      'Central Tongu',
      'Ho',
      'Ho West',
      'Hohoe',
      'Keta',
      'Ketu North',
      'Ketu South',
      'Kpando',
      'North Dayi',
      'North Tongu',
      'South Dayi',
      'South Tongu',
    ],
    'Western': [
      'Ahanta West',
      'Amenfi Central',
      'Amenfi West',
      'Effia Kwesimintsim',
      'Ellembelle',
      'Jomoro',
      'Mpohor',
      'Nzema East',
      'Prestea-Huni Valley',
      'Sekondi Takoradi',
      'Shama',
      'Tarkwa-Nsuaem',
      'Wassa Amenfi East',
      'Wassa East',
    ],
    'Western North': [
      'Aowin',
      'Bia East',
      'Bia West',
      'Bibiani Anhwiaso Bekwai',
      'Bodi',
      'Juaboso',
      'Sefwi Akontombra',
      'Sefwi-Wiawso',
      'Suaman',
    ],
    'Ahafo': [
      'Asunafo North',
      'Asunafo South',
      'Asutifi North',
      'Asutifi South',
      'Tano North',
      'Tano South',
    ],

    'North East': [
      'Bunkpurugu Nyankpanduri',
      'Chereponi',
      'East Mamprusi',
      'Mamprugu Moagduri',
      'West Mamprusi',
      'Yunyoo-Nasuan',
    ],
    'Northern': [
      'Gushegu',
      'Karaga',
      'Kpandai',
      'Kumbungu',
      'Mion',
      'Nanton',
      'Nanumba North',
      'Nanumba South',
      'Saboba',
      'Sagnarigu',
      'Savelugu',
      'Tamale',
      'Tatale Sanguli',
      'Tolon',
      'Yendi',
      'Zabzugu',
    ],
  };

  // TODO: replace with your actual training center names
  static const List<String> _trainingCenters = [
    'Potsec Kumasi Campus',
    'Potsec Accra Campus',
  ];

  static const List<String> _preferredTimes = [
    'Morning',
    'Afternoon',
    'Evening',
  ];

  static const List<String> _registeredByOptions = [
    'Self Registered',
    'Other',
  ];

  late final AnimationController _buttonController;
  late final Animation<double> _buttonScale;

  late final AnimationController _iconFloatController;
  late final Animation<double> _iconFloat;

  late final AnimationController _fabController;
  late final Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _iconFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _iconFloat = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _iconFloatController, curve: Curves.easeInOut),
    );

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fabScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );

    for (final c in [
      _nameController,
      _contactController,
      _guardianContactController,
      _communityController,
      _registeredByController,
    ]) {
      c.addListener(_updateProgress);
    }
  }

  void _updateProgress() {
    final answered = [
      _nameController.text.trim().isNotEmpty,
      _selectedGender != null,
      _selectedPopulationSegment != null,
      _dateOfBirth != null,
      _hasDisability != null,
      _contactController.text.trim().isNotEmpty,
      _guardianContactController.text.trim().isNotEmpty,
      _selectedEmploymentStatus != null,
      _selectedSettlement != null,
      _communityController.text.trim().isNotEmpty,
      _selectedRegion != null,
      _selectedDistrict != null,
      _selectedTrainingCenter != null,
      _selectedPreferredTime != null,
      _registeredByOption != null &&
          (_registeredByOption != 'Other' || _registeredByController.text.trim().isNotEmpty),
      _consentGiven,
    ];
    final filled = answered.where((a) => a).length;
    final progress = filled / answered.length;
    if (progress != _formProgress) {
      setState(() => _formProgress = progress);
    }
  }

  @override
  void dispose() {
    _buttonController.dispose();
    _iconFloatController.dispose();
    _fabController.dispose();
    _nameController.dispose();
    _contactController.dispose();
    _guardianContactController.dispose();
    _communityController.dispose();
    _registeredByController.dispose();
    _institutionController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: _primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
      _updateProgress();
    }
  }

  void _validateAndReview() {
    FocusScope.of(context).unfocus();
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);

    final formValid = _formKey.currentState!.validate();
    final selectionsComplete = _selectedGender != null &&
        _selectedPopulationSegment != null &&
        _selectedEmploymentStatus != null &&
        _selectedSettlement != null &&
        _selectedRegion != null &&
        _selectedDistrict != null &&
        _selectedTrainingCenter != null &&
        _selectedPreferredTime != null &&
        _dateOfBirth != null &&
        _hasDisability != null &&
        (_hasDisability != true || _selectedDisabilityType != null);

    if (!formValid || !selectionsComplete) {
      _shake();
      _showSnack('Please fill in all required fields correctly.', isError: true);
      return;
    }

    if (!_consentGiven) {
      _shake();
      _showSnack('Please provide consent before submitting.', isError: true);
      return;
    }

    _openReviewSheet();
  }

  void _shake() {
    _buttonController.forward(from: 0).then((_) => _buttonController.reverse());
  }

  void _openReviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, (1 - value) * 40),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Review Your Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _reviewRow('Name', _nameController.text.trim()),
                        _reviewRow('Gender', _selectedGender ?? ''),
                        _reviewRow('Population Segment', _selectedPopulationSegment ?? ''),
                        _reviewRow(
                            'Date of Birth',
                            _dateOfBirth == null
                                ? ''
                                : DateFormat('MMM d, yyyy').format(_dateOfBirth!)),
                        _reviewRow(
                            'Disability',
                            _hasDisability == true
                                ? 'Yes - ${_selectedDisabilityType ?? ''}'
                                : 'No'),
                        _reviewRow('Contact', _contactController.text.trim()),
                        _reviewRow('Guardian Contact', _guardianContactController.text.trim()),
                        _reviewRow('Employment Status', _selectedEmploymentStatus ?? ''),
                        _reviewRow('Settlement', _selectedSettlement ?? ''),
                        _reviewRow('Community', _communityController.text.trim()),
                        _reviewRow('Region', _selectedRegion ?? ''),
                        _reviewRow('District', _selectedDistrict ?? ''),
                        _reviewRow('Institution', _institutionController.text),
                        _reviewRow('Training Center', _selectedTrainingCenter ?? ''),
                        _reviewRow('Preferred Time', _selectedPreferredTime ?? ''),
                        _reviewRow(
                            'Registered By',
                            _registeredByOption == 'Other'
                                ? _registeredByController.text.trim()
                                : (_registeredByOption ?? '')),
                        _reviewRow('Consent', _consentGiven ? 'Given' : 'Not given'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                          Navigator.of(context).pop();
                          _performSend();
                        },
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Confirm & Send'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _performSend() async {
    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('registrations').add({
        'consentGiven': _consentGiven,
        'name': _nameController.text.trim(),
        'gender': _selectedGender,
        'populationSegment': _selectedPopulationSegment,
        'hasDisability': _hasDisability,
        'disabilityType': _hasDisability == true ? _selectedDisabilityType : null,
        'dateOfBirth': _dateOfBirth == null ? null : Timestamp.fromDate(_dateOfBirth!),
        'contact': _contactController.text.trim(),
        'guardianContact': _guardianContactController.text.trim(),
        'employmentStatus': _selectedEmploymentStatus,
        'settlement': _selectedSettlement,
        'community': _communityController.text.trim(),
        'region': _selectedRegion,
        'district': _selectedDistrict,
        'institutionName': _institutionController.text,
        'weekOneCourse': 'N/A',
        'weekTwoCourse': 'N/A',
        'weekThreeCourse': 'N/A',
        'weekFourCourse': 'N/A',
        'trainingCenter': _selectedTrainingCenter,
        'preferredTime': _selectedPreferredTime,
        'registeredBy': _registeredByOption == 'Other'
            ? _registeredByController.text.trim()
            : _registeredByOption,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSuccessDialog();
      _clearForm();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Something went wrong: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _contactController.clear();
    _guardianContactController.clear();
    _communityController.clear();
    _registeredByController.clear();
    setState(() {
      _selectedGender = null;
      _selectedPopulationSegment = null;
      _selectedEmploymentStatus = null;
      _hasDisability = null;
      _selectedDisabilityType = null;
      _selectedSettlement = null;
      _selectedRegion = null;
      _selectedDistrict = null;
      _selectedTrainingCenter = null;
      _selectedPreferredTime = null;
      _registeredByOption = null;
      _dateOfBirth = null;
      _consentGiven = false;
      _formProgress = 0;
      _autovalidateMode = AutovalidateMode.disabled;
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Success',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, __, ___) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Transform.scale(
          scale: curved.value,
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 64),
                    const SizedBox(height: 16),
                    const Text('Registration Successful!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text(
                      'Welcome to Potsec Skills Training 1. We will reach out soon.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        child: Text('Done', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- Admin access ----------

  void _showAdminAccessDialog() {
    _adminPasswordController.clear();
    bool obscure = true;
    bool hasError = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void attemptVerify() {
              if (_adminPasswordController.text.trim() == _adminPassword) {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AdminDashboard()),
                );
              } else {
                setDialogState(() => hasError = true);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, color: _primary),
                  SizedBox(width: 8),
                  Text('Admin Access'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _adminPasswordController,
                    obscureText: obscure,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    autofocus: true,
                    onChanged: (_) {
                      if (hasError) setDialogState(() => hasError = false);
                    },
                    onSubmitted: (_) => attemptVerify(),
                    decoration: InputDecoration(
                      labelText: 'Enter Admin Password',
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock_outline, color: _primary),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                      errorText: hasError ? 'Incorrect password' : null,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: attemptVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Enter', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------- Animation helper ----------

  Widget _fadeInSection(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + index * 120),
      curve: Curves.easeOutCubic,
      builder: (context, value, c) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, (1 - value) * 24), child: c),
        );
      },
      child: child,
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      floatingActionButton: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHoveringFab = true),
        onExit: (_) => setState(() => _isHoveringFab = false),
        child: AnimatedBuilder(
          animation: _fabScale,
          builder: (context, child) {
            final hoverBoost = _isHoveringFab ? 1.08 : 1.0;
            return Transform.scale(scale: _fabScale.value * hoverBoost, child: child);
          },
          child: FloatingActionButton.extended(
            onPressed: _isSubmitting ? null : _validateAndReview,
            backgroundColor: _primary,
            icon: const Icon(Icons.send, color: Colors.white),
            label: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            height: 260,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isWide ? 1100 : 700),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Form(
                              key: _formKey,
                              autovalidateMode: _autovalidateMode,
                              child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isSubmitting)
            AnimatedOpacity(
              opacity: _isSubmitting ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          const Expanded(child: SizedBox.shrink()),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
            tooltip: 'Admin Access',
            onPressed: _showAdminAccessDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildPersonalSection(),
        const SizedBox(height: 20),
        _buildContactSection(),
        const SizedBox(height: 20),
        _buildBackgroundSection(),
        const SizedBox(height: 20),
        _buildProgrammeSection(),
        const SizedBox(height: 20),
        _buildConsentSection(),
        const SizedBox(height: 24),
        _buildProgressBar(),
        const SizedBox(height: 16),
        _buildSubmitButton(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildPersonalSection(),
                    const SizedBox(height: 20),
                    _buildContactSection(),
                    const SizedBox(height: 20),
                    _buildBackgroundSection(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildProgrammeSection(),
                    const SizedBox(height: 20),
                    _buildConsentSection(),
                    const SizedBox(height: 20),
                    _buildProgressBar(),
                    const SizedBox(height: 16),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return _fadeInSection(
      6,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Form completion',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              Text('${(_formProgress * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: _primary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _formProgress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor: const AlwaysStoppedAnimation<Color>(_primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return _fadeInSection(
      0,
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _iconFloat,
              builder: (context, child) {
                return Transform.translate(offset: Offset(0, _iconFloat.value), child: child);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Potsec Skills Training',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Free skills training — register below to join US',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required int index,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return _fadeInSection(
      index,
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: _primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalSection() {
    return _sectionCard(
      index: 1,
      title: 'Personal Information',
      icon: Icons.person_outline,
      children: [
        _buildTextField(
          controller: _nameController,
          label: 'Full Name',
          icon: Icons.badge_outlined,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
        const SizedBox(height: 14),
        _buildDropdown(
          value: _selectedGender,
          label: 'Gender',
          icon: Icons.wc_outlined,
          items: _genderOptions,
          onChanged: (v) {
            setState(() => _selectedGender = v);
            _updateProgress();
          },
        ),
        const SizedBox(height: 14),
        _buildDropdown(
          value: _selectedPopulationSegment,
          label: 'Population Segment',
          icon: Icons.groups_outlined,
          items: _populationSegments,
          onChanged: (v) {
            setState(() => _selectedPopulationSegment = v);
            _updateProgress();
          },
        ),
        const SizedBox(height: 14),
        _buildDateOfBirthField(),
        const SizedBox(height: 14),
        _buildDisabilityToggle(),
      ],
    );
  }

  Widget _buildContactSection() {
    return _sectionCard(
      index: 2,
      title: 'Contact Information',
      icon: Icons.phone_outlined,
      children: [
        _buildTextField(
          controller: _contactController,
          label: 'Contact (phone number)',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Contact is required';
            if (v.trim().length < 7) return 'Enter a valid contact number';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _guardianContactController,
          label: 'Guardian Contact',
          icon: Icons.contact_phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]'))],
          validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Guardian contact is required' : null,
        ),
      ],
    );
  }

  Widget _buildBackgroundSection() {
    return _sectionCard(
      index: 3,
      title: 'Background Details',
      icon: Icons.map_outlined,
      children: [
        _buildDropdown(
          value: _selectedEmploymentStatus,
          label: 'Employment Status',
          icon: Icons.work_outline,
          items: _employmentStatuses,
          onChanged: (v) {
            setState(() => _selectedEmploymentStatus = v);
            _updateProgress();
          },
        ),
        const SizedBox(height: 14),
        _buildDropdown(
          value: _selectedSettlement,
          label: 'Settlement',
          icon: Icons.holiday_village_outlined,
          items: _settlements,
          onChanged: (v) {
            setState(() => _selectedSettlement = v);
            _updateProgress();
          },
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _communityController,
          label: 'Community',
          icon: Icons.location_city_outlined,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Community is required' : null,
        ),
        const SizedBox(height: 14),
        _buildDropdown(
          value: _selectedRegion,
          label: 'Region',
          icon: Icons.public_outlined,
          items: _regions,
          onChanged: (v) {
            setState(() {
              _selectedRegion = v;
              _selectedDistrict = null;
            });
            _updateProgress();
          },
        ),
        const SizedBox(height: 14),
        _buildDistrictDropdown(),
      ],
    );
  }

  Widget _buildDistrictDropdown() {
    final hasRegion = _selectedRegion != null;
    final districts = hasRegion ? (_districtsByRegion[_selectedRegion] ?? const <String>[]) : const <String>[];

    return DropdownButtonFormField<String>(
      value: _selectedDistrict,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'District *',
        hintText: hasRegion ? 'Select district' : 'Select region first',
        prefixIcon: Icon(Icons.map_outlined, color: hasRegion ? _primary : Colors.black38),
        filled: true,
        fillColor: hasRegion ? const Color(0xFFF7F9F6) : const Color(0xFFF0F0F0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 1.5)),
      ),
      items: districts
          .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: hasRegion
          ? (v) {
        setState(() => _selectedDistrict = v);
        _updateProgress();
      }
          : null,
      validator: (v) => v == null ? 'Please select a district' : null,
    );
  }

  Widget _buildProgrammeSection() {
    return _sectionCard(
      index: 4,
      title: 'Programme Details',
      icon: Icons.school_outlined,
      children: [
        _lockedField('Institution Name', Icons.account_balance_outlined, _institutionController),
        const SizedBox(height: 14),
        _buildDropdown(
          value: _selectedTrainingCenter,
          label: 'Training Center',
          icon: Icons.location_on_outlined,
          items: _trainingCenters,
          onChanged: (v) {
            setState(() => _selectedTrainingCenter = v);
            _updateProgress();
          },
        ),
        const SizedBox(height: 14),
        _buildDropdown(
          value: _selectedPreferredTime,
          label: 'Preferred Time',
          icon: Icons.schedule_outlined,
          items: _preferredTimes,
          onChanged: (v) {
            setState(() => _selectedPreferredTime = v);
            _updateProgress();
          },
        ),
        const SizedBox(height: 14),
        _buildDropdown(
          value: _registeredByOption,
          label: 'Registered By',
          icon: Icons.edit_note_outlined,
          items: _registeredByOptions,
          required: false,
          onChanged: (v) {
            setState(() {
              _registeredByOption = v;
              if (v != 'Other') _registeredByController.clear();
            });
            _updateProgress();
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: _registeredByOption == 'Other'
              ? Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _buildTextField(
              controller: _registeredByController,
              label: 'Name of Person Who Registered',
              icon: Icons.person_outline,
              validator: (v) => (_registeredByOption == 'Other' &&
                  (v == null || v.trim().isEmpty))
                  ? 'Please enter the name'
                  : null,
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildConsentSection() {
    return _fadeInSection(
      5,
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _consentGiven ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _consentGiven ? _primary : Colors.black12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _consentGiven,
              activeColor: _primary,
              onChanged: (v) {
                setState(() => _consentGiven = v ?? false);
                _updateProgress();
              },
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _consentGiven = !_consentGiven);
                  _updateProgress();
                },
                child: const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'I confirm the information provided is accurate and I consent to Potsec Skills Training storing and using this data for registration and programme purposes.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateOfBirthField() {
    return GestureDetector(
      onTap: _pickDateOfBirth,
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          controller: TextEditingController(
            text: _dateOfBirth == null ? '' : DateFormat('MMM d, yyyy').format(_dateOfBirth!),
          ),
          decoration: InputDecoration(
            labelText: 'Date of Birth *',
            hintText: 'Select date of birth',
            prefixIcon: const Icon(Icons.calendar_today_outlined, color: _primary),
            filled: true,
            fillColor: const Color(0xFFF7F9F6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (v) => _dateOfBirth == null ? 'Please select date of birth' : null,
        ),
      ),
    );
  }

  Widget _buildDisabilityToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Does the participant have a disability? *',
            style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            _toggleChip('No', _hasDisability == false, () {
              setState(() {
                _hasDisability = false;
                _selectedDisabilityType = null;
              });
              _updateProgress();
            }),
            const SizedBox(width: 10),
            _toggleChip('Yes', _hasDisability == true, () {
              setState(() => _hasDisability = true);
              _updateProgress();
            }),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: _hasDisability == true
              ? Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _buildDropdown(
              value: _selectedDisabilityType,
              label: 'Type of Disability',
              icon: Icons.accessible_outlined,
              items: _disabilityTypes,
              onChanged: (v) {
                setState(() => _selectedDisabilityType = v);
                _updateProgress();
              },
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _toggleChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _primary : const Color(0xFFF7F9F6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? _primary : Colors.black12),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _lockedField(String label, IconData icon, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      enabled: false,
      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primary),
        suffixIcon: const Icon(Icons.lock_outline, size: 18, color: Colors.black38),
        filled: true,
        fillColor: const Color(0xFFF0F0F0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        prefixIcon: Icon(icon, color: _primary),
        filled: true,
        fillColor: const Color(0xFFF7F9F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 1.5)),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = true,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon, color: _primary),
        filled: true,
        fillColor: const Color(0xFFF7F9F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 1.5)),
      ),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
      validator: required ? (v) => v == null ? 'Please select $label' : null : null,
    );
  }

  Widget _buildSubmitButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHoveringSubmit = true),
      onExit: (_) => setState(() => _isHoveringSubmit = false),
      child: AnimatedBuilder(
        animation: _buttonScale,
        builder: (context, child) {
          return Transform.scale(scale: 1 - _buttonScale.value, child: child);
        },
        child: GestureDetector(
          onTapDown: (_) => _buttonController.forward(),
          onTapUp: (_) => _buttonController.reverse(),
          onTapCancel: () => _buttonController.reverse(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(0, _isHoveringSubmit ? -2 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(_isHoveringSubmit ? 0.4 : 0.2),
                  blurRadius: _isHoveringSubmit ? 16 : 8,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _validateAndReview,
              icon: _isSubmitting
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
                  : const Icon(Icons.send, color: Colors.white, size: 18),
              label: Text(
                _isSubmitting ? 'Sending...' : 'Send Application',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),
        ),
      ),
    );
  }
}