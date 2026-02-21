import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../services/firebase_service.dart';
import '../main.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _chapterController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _biographyController = TextEditingController();

  bool _isLoading = false;
  Uint8List? _selectedImageBytes;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _chapterController.dispose();
    _schoolController.dispose();
    _positionController.dispose();
    _biographyController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final app = Provider.of<AppState>(context, listen: false);
    if (app.firebaseUser != null) {
      try {
        // Load Firebase user profile
        final profileData = await FirebaseService.getUserProfile(app.firebaseUser!.uid);
        if (profileData != null) {
          setState(() {
            _nameController.text = profileData['name'] ?? app.displayName;
            _chapterController.text = profileData['chapter'] ?? 'Your Chapter';
            _schoolController.text = profileData['school'] ?? 'Your School';
            _positionController.text = profileData['officerPosition'] ?? 'Member';
            _biographyController.text = profileData['biography'] ?? 'FBLA Member';
            _currentImageUrl = profileData['photoUrl'];
          });
        } else {
          // No profile data yet, use defaults
          setState(() {
            _nameController.text = app.displayName;
            _chapterController.text = '';
            _schoolController.text = '';
            _positionController.text = '';
            _biographyController.text = '';
            _currentImageUrl = null;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final app = Provider.of<AppState>(context, listen: false);
      
      if (app.firebaseUser != null) {
        // Save to Firebase
        String? photoUrl = _currentImageUrl;
        
        // Upload new image if selected
        if (_selectedImageBytes != null) {
          photoUrl = await FirebaseService.uploadProfileImage(
            app.firebaseUser!.uid, 
            _selectedImageBytes!
          );
        }

        // Update user profile in Firestore
        await FirebaseService.updateUserProfile(app.firebaseUser!.uid, {
          'name': _nameController.text.trim(),
          'chapter': _chapterController.text.trim(),
          'school': _schoolController.text.trim(),
          'officerPosition': _positionController.text.trim(),
          'biography': _biographyController.text.trim(),
          'photoUrl': photoUrl,
        });

        // Update local app state
        await app.setFirebaseUser(app.firebaseUser!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Profile updated successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fblaBlue = const Color(0xFF1D4E89);
    final Color fblaGold = const Color(0xFFF6C500);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: fblaBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: Text(
              'Save',
              style: TextStyle(
                color: fblaGold,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Image Section
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: fblaGold,
                        backgroundImage: _selectedImageBytes != null
                          ? MemoryImage(_selectedImageBytes!)
                            : (_currentImageUrl != null
                                ? NetworkImage(_currentImageUrl!)
                                    as ImageProvider
                                : null),
                        child: _selectedImageBytes == null &&
                                _currentImageUrl == null
                            ? Icon(
                                Icons.person,
                                size: 60,
                                color: fblaBlue,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: fblaBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 20),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _pickImage,
                    child: Text(
                      'Change Photo',
                      style: TextStyle(
                          color: fblaBlue, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name',
                prefixIcon: Icon(Icons.person_outline,
                    color: fblaBlue.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.white,
                border: border,
                enabledBorder: border,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: fblaBlue, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Chapter Field
            TextFormField(
              controller: _chapterController,
              decoration: InputDecoration(
                labelText: 'Chapter',
                hintText: 'e.g., Lincoln High School FBLA',
                prefixIcon: Icon(Icons.group, color: fblaBlue.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.white,
                border: border,
                enabledBorder: border,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: fblaBlue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // School Field
            TextFormField(
              controller: _schoolController,
              decoration: InputDecoration(
                labelText: 'School',
                hintText: 'Enter your school name',
                prefixIcon:
                    Icon(Icons.school, color: fblaBlue.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.white,
                border: border,
                enabledBorder: border,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: fblaBlue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Officer Position Field
            TextFormField(
              controller: _positionController,
              decoration: InputDecoration(
                labelText: 'Officer Position (Optional)',
                hintText: 'e.g., President, Vice President, Secretary',
                prefixIcon: Icon(Icons.badge, color: fblaBlue.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.white,
                border: border,
                enabledBorder: border,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: fblaBlue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Biography Field
            TextFormField(
              controller: _biographyController,
              decoration: InputDecoration(
                labelText: 'Biography (Optional)',
                hintText: 'Tell us about yourself and your FBLA journey',
                prefixIcon:
                    Icon(Icons.description, color: fblaBlue.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.white,
                border: border,
                enabledBorder: border,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: fblaBlue, width: 2),
                ),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: fblaBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                ),
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your profile information helps other FBLA members connect with you and learn about your chapter.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade800,
                        height: 1.3,
                      ),
                    ),
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
