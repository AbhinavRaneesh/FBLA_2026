import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseTestScreen extends StatefulWidget {
  @override
  _FirebaseTestScreenState createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  String _status = 'Testing Firebase...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _testFirebase();
  }

  Future<void> _testFirebase() async {
    try {
      if (mounted) {
        setState(() {
          _status = 'Testing Firebase initialization...';
        });
      }

      // Test Firebase Core
      final app = Firebase.app();
      if (mounted) {
        setState(() {
          _status = 'Firebase Core: OK (${app.name})';
        });
      }

      // Test Firebase Auth
      final auth = FirebaseAuth.instance;
      if (mounted) {
        setState(() {
          _status = 'Firebase Auth: OK (${auth.app.name})';
        });
      }

      // Test Firestore
      final firestore = FirebaseFirestore.instance;
      if (mounted) {
        setState(() {
          _status = 'Firestore: OK (${firestore.app.name})';
        });
      }

      // Test Firestore write
      await firestore.collection('test').doc('test').set({
        'message': 'Hello Firebase!',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _status = 'Firestore Write: OK';
        });
      }

      // Test Firestore read
      final doc = await firestore.collection('test').doc('test').get();
      if (doc.exists && mounted) {
        setState(() {
          _status = 'Firestore Read: OK (${doc.data()?['message']})';
        });
      }

      // Test Auth - try creating a test user
      try {
        final testEmail =
            'test_${DateTime.now().millisecondsSinceEpoch}@example.com';
        await auth.createUserWithEmailAndPassword(
          email: testEmail,
          password: 'testpassword123',
        );
        if (mounted) {
          setState(() {
            _status = 'Auth Test: OK - User created successfully';
          });
        }

        // Clean up test user
        await auth.currentUser?.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use' && mounted) {
          setState(() {
            _status = 'Auth Test: OK - Authentication is working';
          });
        } else if (e.code == 'operation-not-allowed' && mounted) {
          setState(() {
            _status =
                'Auth Test: ERROR - Email/Password authentication is not enabled in Firebase Console';
          });
        } else if (mounted) {
          setState(() {
            _status = 'Auth Test: ERROR - ${e.code}: ${e.message}';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _status = 'Auth Test: ERROR - $e';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'ERROR: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firebase Test'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              CircularProgressIndicator()
            else
              Icon(
                _status.contains('ERROR') ? Icons.error : Icons.check_circle,
                color: _status.contains('ERROR') ? Colors.red : Colors.green,
                size: 64,
              ),
            SizedBox(height: 20),
            Text(
              _status,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testFirebase,
              child: Text('Test Again'),
            ),
          ],
        ),
      ),
    );
  }
}
