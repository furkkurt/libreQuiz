import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math'; // For generating random UIDs in dev mode
import 'login_page.dart';
import 'web_layout_helper.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({Key? key}) : super(key: key);

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  bool _devMode = false; // Set to true to use dev mode
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _registerAnonymously() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      print("Attempting anonymous sign-in");
      UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
      
      print("Anonymous sign-in successful! User ID: ${userCredential.user?.uid}");
      
      // Store username and other details in Firebase database or Firestore
      // instead of updating profile
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful!')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = "Auth error: ${e.code}";
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      try {
        if (_devMode) {
          // Dev mode code (unchanged)
          await Future.delayed(const Duration(milliseconds: 500));
          print("DEV MODE: Simulated successful registration");
          
          // Generate a mock UID for dev mode
          String mockUid = _generateMockUid();
          print("DEV MODE: Generated mock UID: $mockUid");
          
          // Actually create the Firestore document
          await _createUserDocument(mockUid);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful (DEV MODE)')),
          );
          
          // Navigate to login page
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const LoginPage(),
            ),
          );
        } else {
          // REAL AUTHENTICATION MODE
          print("Creating Firebase Auth user with email: ${_emailController.text}");
          
          // Create user with email and password in Firebase Auth
          UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          
          // Get the user ID from the authentication result
          String uid = userCredential.user!.uid;
          print("Firebase Auth user created successfully with UID: $uid");
          
          // Create user document in Firestore
          await _createUserDocument(uid);
          
          // Set display name in Auth profile
          await userCredential.user!.updateDisplayName(_usernameController.text.trim());
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful!')),
          );
          
          // Navigate to login page or home page
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const LoginPage(),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        print("DETAILED AUTH ERROR: ${e.toString()}");
        print("Error code: ${e.code}");
        print("Error message: ${e.message}");
        
        // Provide user-friendly error messages
        String errorMsg;
        switch (e.code) {
          case 'email-already-in-use':
            errorMsg = 'This email is already registered. Please use a different email or log in.';
            break;
          case 'weak-password':
            errorMsg = 'Password is too weak. Please use a stronger password.';
            break;
          case 'invalid-email':
            errorMsg = 'Invalid email format. Please enter a valid email address.';
            break;
          default:
            errorMsg = 'Registration failed: ${e.message}';
        }
        
        setState(() {
          _errorMessage = errorMsg;
        });
      } catch (e) {
        print("General error during registration: $e");
        setState(() {
          _errorMessage = "Registration failed: ${e.toString()}";
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _login() async {
    // Reuse the register function for login during development
    await _register();
  }
  
  // Generate a random UID for dev mode
  String _generateMockUid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    final result = StringBuffer('dev_');
    
    for (var i = 0; i < 20; i++) {
      result.write(chars[random.nextInt(chars.length)]);
    }
    
    return result.toString();
  }
  
  Future<void> _createUserDocument(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'profilePicture': '',
      'friends': [],
      'badges': {},
      'quizzes': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    print("Firestore user document created for UID: $uid");
  }
  
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled in Firebase Console.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed (code: $code). Please try again.';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isWeb = WebLayoutHelper.isWeb;
    final fontSizeMultiplier = WebLayoutHelper.getFontSizeMultiplier(context);
    final buttonSizeMultiplier = WebLayoutHelper.getButtonSizeMultiplier(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Account', 
          style: TextStyle(
            fontSize: isWeb ? 24 * fontSizeMultiplier : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        toolbarHeight: isWeb ? 70 : 56,
      ),
      body: Stack(
        children: [
          // Background with opacity overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                image: DecorationImage(
                  image: const AssetImage('assets/bg.jpeg'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.7),
                    BlendMode.srcOver,
                  ),
                ),
              ),
            ),
          ),
          // Content
          WebLayoutHelper.wrapResponsive(
            context,
            Center(
              child: SingleChildScrollView(
                padding: WebLayoutHelper.getContentPadding(context),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo with animation
                    Hero(
                      tag: 'logo',
                      child: Image.asset(
                        'assets/logo.png',
                        width: isWeb ? 180 * buttonSizeMultiplier : 120,
                        height: isWeb ? 180 * buttonSizeMultiplier : 120,
                      ),
                    ),
                    
                    SizedBox(height: isWeb ? 30 : 20),
                    
                    // Registration Form
                    Container(
                      width: isWeb ? 500 : 350,
                      padding: EdgeInsets.all(isWeb ? 32 : 24),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Title
                            Text(
                              'Join LibreQuiz',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22 * fontSizeMultiplier,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            SizedBox(height: isWeb ? 25 : 20),
                            
                            // Error message
                            if (_errorMessage.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade400),
                                ),
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14 * fontSizeMultiplier,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            
                            // Username field
                            TextFormField(
                              controller: _usernameController,
                              style: TextStyle(
                                fontSize: 16 * fontSizeMultiplier,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Username',
                                labelStyle: TextStyle(
                                  fontSize: 14 * fontSizeMultiplier,
                                  color: Colors.grey[300],
                                ),
                                prefixIcon: Icon(
                                  Icons.person,
                                  size: 22 * buttonSizeMultiplier,
                                  color: Colors.deepOrange,
                                ),
                                // Apply similar styling as in login page
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20 * buttonSizeMultiplier * 0.8,
                                  vertical: 12 * buttonSizeMultiplier * 0.8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: Colors.grey.shade700),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: Colors.deepOrange),
                                ),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.3),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a username';
                                }
                                return null;
                              },
                            ),
                            
                            SizedBox(height: 20),
                            
                            // Email field (styled like in login page)
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(
                                fontSize: 16 * fontSizeMultiplier,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(
                                  fontSize: 14 * fontSizeMultiplier,
                                  color: Colors.grey[300],
                                ),
                                prefixIcon: Icon(
                                  Icons.email,
                                  size: 22 * buttonSizeMultiplier,
                                  color: Colors.deepOrange,
                                ),
                                // Apply same styling
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20 * buttonSizeMultiplier * 0.8,
                                  vertical: 12 * buttonSizeMultiplier * 0.8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: Colors.grey.shade700),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: Colors.deepOrange),
                                ),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.3),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                // Add email validation regex if needed
                                return null;
                              },
                            ),
                            
                            SizedBox(height: 20),
                            
                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: TextStyle(
                                fontSize: 16 * fontSizeMultiplier,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(
                                  fontSize: 14 * fontSizeMultiplier,
                                  color: Colors.grey[300],
                                ),
                                prefixIcon: Icon(
                                  Icons.lock,
                                  size: 22 * buttonSizeMultiplier,
                                  color: Colors.deepOrange,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.grey[400],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                // Apply same styling
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20 * buttonSizeMultiplier * 0.8,
                                  vertical: 12 * buttonSizeMultiplier * 0.8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(color: Colors.grey.shade700),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: Colors.deepOrange),
                                ),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.3),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            
                            SizedBox(height: isWeb ? 30 : 20),
                            
                            // Register button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  vertical: 15 * buttonSizeMultiplier,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 5,
                              ),
                              child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 18 * fontSizeMultiplier,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            ),
                            
                            SizedBox(height: isWeb ? 25 : 20),
                            
                            // Login option
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Already have an account? ",
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 14 * fontSizeMultiplier,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pushReplacementNamed('/login');
                                  },
                                  child: Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.deepOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14 * fontSizeMultiplier,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 