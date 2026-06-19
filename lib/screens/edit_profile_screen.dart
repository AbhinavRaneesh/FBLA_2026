import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../main.dart' show AppState, appBackgroundGradient, fblaGold, fblaNavy;
import '../models/school.dart';
import '../services/firebase_service.dart';
import '../services/ml_kit_service.dart';
import '../services/school_search_service.dart';
import '../widgets/school_autocomplete_field.dart';
import '../widgets/app_snackbar.dart';
import 'nlc_ready_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color _fblaBlue = Color(0xFF1D4E89);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _chapterController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _biographyController = TextEditingController();
  final FocusNode _schoolFocus = FocusNode();

  bool _isLoading = false;
  bool _isAnalyzingImage = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImagePath;
  String? _currentImageUrl;
  List<MlKitLabel> _imageLabels = [];
  String? _imageAnalysisError;

  String? _selectedState = 'UT';
  School? _selectedSchool;
  List<String> _nlcEvents = const [];

  @override
  void initState() {
    super.initState();
    unawaited(SchoolSearchService.instance.prefetchState('UT'));
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _chapterController.dispose();
    _schoolController.dispose();
    _positionController.dispose();
    _biographyController.dispose();
    _schoolFocus.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final app = Provider.of<AppState>(context, listen: false);
    if (app.firebaseUser == null) return;

    try {
      final profileData =
          await FirebaseService.getUserProfile(app.firebaseUser!.uid);
      if (profileData == null || !mounted) return;

      final savedName = (profileData['name'] ?? '').toString().trim();
      final fallbackName = app.displayName.trim().isNotEmpty
          ? app.displayName.trim()
          : app.userEmail.split('@').first.trim();
      final schoolState =
          (profileData['schoolState'] ?? 'UT').toString().trim().toUpperCase();
      final schoolName = (profileData['school'] ?? '').toString().trim();
      final schoolId = (profileData['schoolId'] ?? '').toString().trim();
      final schoolCity = (profileData['schoolCity'] ?? '').toString().trim();

      School? loadedSchool;
      if (schoolId.isNotEmpty && schoolName.isNotEmpty) {
        loadedSchool = School(
          id: schoolId,
          name: schoolName,
          city: schoolCity,
          state: schoolState.isNotEmpty ? schoolState : 'UT',
        );
      }

      setState(() {
        _nameController.text =
            savedName.toLowerCase() == 'fbla member' || savedName.isEmpty
                ? fallbackName
                : savedName;
        _chapterController.text =
            (profileData['chapter'] ?? '').toString().trim();
        _schoolController.text = schoolName;
        _positionController.text =
            (profileData['officerPosition'] ?? '').toString().trim();
        _biographyController.text =
            (profileData['biography'] ?? '').toString().trim();
        _currentImageUrl = profileData['photoUrl']?.toString();
        _selectedState =
            schoolState.isNotEmpty ? schoolState : _selectedState;
        _selectedSchool = loadedSchool;
        _nlcEvents = (profileData['nlcEvents'] is List)
            ? (profileData['nlcEvents'] as List)
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList()
            : const [];
      });
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final imageBytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = imageBytes;
        _selectedImagePath = pickedFile.path;
        _imageLabels = [];
        _imageAnalysisError = null;
      });
    }
  }

  Future<void> _analyzeSelectedImage() async {
    if (_selectedImagePath == null) {
      if (!mounted) return;
      AppSnackBar.warning(context, 'Pick an image first.');
      return;
    }

    if (kIsWeb) {
      if (!mounted) return;
      AppSnackBar.info(
        context,
        'ML Kit image labeling runs on Android and iOS devices only.',
      );
      return;
    }

    setState(() {
      _isAnalyzingImage = true;
      _imageAnalysisError = null;
    });

    final mlKitService = createMlKitImageLabelingService();

    try {
      final labels = await mlKitService.analyzeImage(_selectedImagePath!);
      if (!mounted) return;
      setState(() => _imageLabels = labels);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _imageAnalysisError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      await mlKitService.dispose();
      if (mounted) setState(() => _isAnalyzingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final app = Provider.of<AppState>(context, listen: false);
      if (app.firebaseUser == null) {
        // Demo / offline session has no Firebase user — persist the name
        // locally so the edit isn't a silent no-op.
        await app.login(
          app.userEmail,
          _nameController.text.trim(),
          role: app.signupRole,
          grade: app.gradeLevel,
        );
        if (!mounted) return;
        AppSnackBar.success(context, 'Profile saved.');
        Navigator.pop(context);
        return;
      }

      String? photoUrl = _currentImageUrl;
      if (_selectedImageBytes != null) {
        photoUrl = await FirebaseService.uploadProfileImage(
          app.firebaseUser!.uid,
          _selectedImageBytes!,
        );
      }

      final fullName = _nameController.text.trim();
      final schoolName = _schoolController.text.trim();
      final selected = _selectedSchool;

      await app.firebaseUser!.updateDisplayName(fullName);

      await FirebaseService.updateUserProfile(app.firebaseUser!.uid, {
        'name': fullName,
        'chapter': _chapterController.text.trim(),
        'school': selected?.name ?? schoolName,
        'schoolId': selected?.id,
        'schoolCity': selected?.city,
        'schoolState': selected?.state ?? _selectedState,
        'schoolVerified': selected != null,
        'officerPosition': _positionController.text.trim(),
        'biography': _biographyController.text.trim(),
        'photoUrl': photoUrl,
        'nlcEvents': _nlcEvents,
      });

      await app.setFirebaseUser(app.firebaseUser!);
      if (!mounted) return;
      AppSnackBar.success(context, 'Profile saved.');
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        'Could not save profile. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _fblaBlue.withValues(alpha: 0.85)),
      filled: true,
      fillColor: const Color(0xFF0B1624),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: fblaGold.withValues(alpha: 0.8), width: 2),
      ),
    );
  }

  Future<void> _editNlcEvents() async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NlcEventPickerSheet(initial: _nlcEvents),
    );
    if (picked != null) {
      setState(() => _nlcEvents = picked);
    }
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1624),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStateDropdown() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0B1624),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedState,
          isExpanded: true,
          dropdownColor: const Color(0xFF0B1624),
          hint: Text(
            'Choose your state',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
          ),
          icon: Icon(
            Icons.expand_more_rounded,
            color: Colors.white.withValues(alpha: 0.55),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          items: SchoolSearchService.stateAbbreviations
              .map(
                (state) => DropdownMenuItem(
                  value: state,
                  child: Text(SchoolSearchService.stateLabel(state)),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedState = value;
              _selectedSchool = null;
              _schoolController.clear();
            });
            if (value == 'UT') {
              unawaited(SchoolSearchService.instance.prefetchState('UT'));
            }
          },
        ),
      ),
    );
  }

  ImageProvider? _avatarImageProvider() {
    if (_selectedImageBytes != null) {
      return MemoryImage(_selectedImageBytes!);
    }
    if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return NetworkImage(_currentImageUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final avatarImage = _avatarImageProvider();

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: const Text(
              'Save',
              style: TextStyle(
                color: fblaGold,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomSafe + 96),
            children: [
              _buildSectionCard(
                title: 'Profile Photo',
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 58,
                          backgroundColor: fblaGold.withValues(alpha: 0.2),
                          backgroundImage: avatarImage,
                          onBackgroundImageError:
                              avatarImage == null ? null : (_, __) {},
                          child: avatarImage == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 58,
                                  color: fblaGold,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Material(
                            color: _fblaBlue,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _pickImage,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _pickImage,
                      child: const Text(
                        'Change Photo',
                        style: TextStyle(
                          color: fblaGold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isAnalyzingImage ? null : _analyzeSelectedImage,
                    icon: _isAnalyzingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      _isAnalyzingImage ? 'Analyzing...' : 'Analyze with ML Kit',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                  ),
                  if (_imageAnalysisError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _imageAnalysisError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                    ),
                  ],
                  if (_imageLabels.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._imageLabels.map(
                      (label) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${(label.confidence * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Profile Details',
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: _fieldDecoration(
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      icon: Icons.person_outline_rounded,
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _chapterController,
                    decoration: _fieldDecoration(
                      label: 'Chapter',
                      hint: 'e.g., Lincoln High School FBLA',
                      icon: Icons.groups_outlined,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'School',
                children: [
                  Text(
                    'School search is available for Utah (UT). Type 2+ letters to see matches.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'State',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStateDropdown(),
                  const SizedBox(height: 14),
                  Text(
                    'School name',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SchoolAutocompleteField(
                    stateAbbr: _selectedState,
                    controller: _schoolController,
                    focusNode: _schoolFocus,
                    selectedSchool: _selectedSchool,
                    accentColor: fblaGold,
                    focusedBorderColor: fblaGold.withValues(alpha: 0.9),
                    fieldBackgroundColor: const Color(0xFF0B1624),
                    borderColor: Colors.white12,
                    onSchoolChanged: (school) {
                      setState(() => _selectedSchool = school);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'About You',
                children: [
                  TextFormField(
                    controller: _positionController,
                    decoration: _fieldDecoration(
                      label: 'Officer Position (Optional)',
                      hint: 'e.g., President, Secretary',
                      icon: Icons.workspace_premium_outlined,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _biographyController,
                    decoration: _fieldDecoration(
                      label: 'Biography (Optional)',
                      hint: 'Tell members about your FBLA journey',
                      icon: Icons.notes_rounded,
                      maxLines: 4,
                    ),
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    maxLength: 500,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'My NLC Events',
                children: [
                  Text(
                    _nlcEvents.isEmpty
                        ? 'No events selected yet. Choose the competitions you are preparing for at NLC.'
                        : _nlcEvents.join(' · '),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _editNlcEvents,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(_nlcEvents.isEmpty
                        ? 'Choose NLC Events'
                        : 'Edit NLC Events (${_nlcEvents.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: fblaGold,
                      side: BorderSide(color: fblaGold.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fblaGold,
                    foregroundColor: fblaNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: fblaNavy,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: fblaGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: fblaGold.withValues(alpha: 0.28)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: fblaGold, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your profile helps other FBLA members find and connect with you across the chapter.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.4,
                        ),
                      ),
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
}
