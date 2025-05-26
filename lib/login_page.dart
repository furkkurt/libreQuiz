import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'registration_page.dart';
import 'home_page.dart';
import 'web_layout_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        // Add more detailed logging
        print("DEBUG: Attempting login with Firebase Auth");
        print("DEBUG: Email: ${_emailController.text.trim()}");
        print("DEBUG: Password length: ${_passwordController.text.length}");
        
        // Print Firebase initialization status
        print("DEBUG: Firebase Auth instance: ${FirebaseAuth.instance}");
        print("DEBUG: Current user: ${FirebaseAuth.instance.currentUser}");
        
        // Try to sign in
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        
        print("DEBUG: Login successful. User ID: ${userCredential.user?.uid}");
        
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      } on FirebaseAuthException catch (e) {
        // Enhanced error logging
        print("FIREBASE AUTH ERROR: ${e.code}");
        print("FIREBASE AUTH ERROR Message: ${e.message}");
        print("FIREBASE AUTH ERROR Details: $e");
        
        setState(() {
          _errorMessage = _getMessageFromErrorCode(e.code);
          _isLoading = false;
        });
      } catch (e) {
        print("UNEXPECTED AUTH ERROR: $e");
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginAnonymously() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      await FirebaseAuth.instance.signInAnonymously();
      
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign in anonymously. Please try again.';
        _isLoading = false;
      });
    }
  }

  // Helper function to convert Firebase error codes to user-friendly messages
  String _getMessageFromErrorCode(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email. Please register first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email format. Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
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
      // Use a stylish appBar that matches the theme
      appBar: AppBar(
        title: Text(
          'LibreQuiz', 
          style: TextStyle(
            fontSize: isWeb ? 24 * fontSizeMultiplier : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        toolbarHeight: isWeb ? 70 : 56,
      ),
      // Use Stack to ensure proper background coverage
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
                        width: isWeb ? 150 : 120,
                        height: isWeb ? 150 : 120,
                      ),
                    ),
                    
                    SizedBox(height: isWeb ? 40 : 30),
                    
                    // Login Form with glass-like effect
                    Container(
                      width: isWeb ? 400 : 350,
                      padding: EdgeInsets.all(isWeb ? 24 : 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                            
                            // Email field
                            TextFormField(
                              controller: _emailController,
                              style: TextStyle(
                                fontSize: 15 * fontSizeMultiplier,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(
                                  fontSize: 13 * fontSizeMultiplier,
                                  color: Colors.grey[300],
                                ),
                                prefixIcon: Icon(
                                  Icons.email,
                                  size: 22 * buttonSizeMultiplier,
                                  color: Colors.deepOrange,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 15 * buttonSizeMultiplier,
                                  vertical: 10 * buttonSizeMultiplier,
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
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                return null;
                              },
                            ),
                            
                            SizedBox(height: isWeb ? 25 : 20),
                            
                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              style: TextStyle(
                                fontSize: 15 * fontSizeMultiplier,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(
                                  fontSize: 13 * fontSizeMultiplier,
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
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 15 * buttonSizeMultiplier,
                                  vertical: 10 * buttonSizeMultiplier,
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
                              obscureText: _obscurePassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                            
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // Add forgot password functionality
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: Colors.deepOrange,
                                    fontSize: 14 * fontSizeMultiplier,
                                  ),
                                ),
                              ),
                            ),
                            
                            SizedBox(height: isWeb ? 30 : 20),
                            
                            // Login button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20 * buttonSizeMultiplier,
                                  vertical: 12 * buttonSizeMultiplier,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 5,
                              ),
                              child: _isLoading
                                ? SizedBox(
                                    height: 20, 
                                    width: 20, 
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0, 
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)
                                    )
                                  )
                                : Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 16 * fontSizeMultiplier,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            ),
                            
                            SizedBox(height: isWeb ? 25 : 20),
                            
                            // Register option
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 14 * fontSizeMultiplier,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pushReplacementNamed('/register');
                                  },
                                  child: Text(
                                    'Register',
                                    style: TextStyle(
                                      color: Colors.deepOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14 * fontSizeMultiplier,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            SizedBox(height: isWeb ? 25 : 20),
                            
                            // Anonymous login option
                            TextButton(
                              onPressed: _loginAnonymously,
                              child: Text(
                                'Continue as Guest',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 14 * fontSizeMultiplier,
                                ),
                              ),
                            ),
                            
                            SizedBox(height: isWeb ? 25 : 20),
                            
                            // Emergency access option
                            TextButton(
                              onPressed: () {
                                print("EMERGENCY: Bypassing login screen");
                                Navigator.of(context).pushReplacementNamed('/home');
                              },
                              child: Text(
                                'Emergency Access (Dev Only)',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
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