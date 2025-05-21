import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'registration_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  bool _devMode = true; // Set to false when ready for real authentication

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
        if (_devMode) {
          // In dev mode, try to find the user by email in Firestore
          await Future.delayed(const Duration(milliseconds: 500));
          print("DEV MODE: Trying to find user document with email: ${_emailController.text}");
          
          try {
            // Query Firestore for a user with this email
            final querySnapshot = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: _emailController.text.trim())
                .limit(1)
                .get();
                
            if (querySnapshot.docs.isNotEmpty) {
              final userDoc = querySnapshot.docs.first;
              print("DEV MODE: Found user document with ID: ${userDoc.id}");
              
              // In a real app, you'd check password here
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Login successful!')),
              );
              
              // Navigate to home page
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomePage()),
              );
            } else {
              setState(() {
                _errorMessage = "No user found with this email. Please register first.";
              });
            }
          } catch (firestoreError) {
            print("DEV MODE: Error checking Firestore: $firestoreError");
            setState(() {
              _errorMessage = "Error checking user account: $firestoreError";
            });
          }
        } else {
          // REAL AUTHENTICATION MODE
          print("Attempting Firebase Auth login with email: ${_emailController.text}");
          
          // Sign in with email and password
          UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          
          String uid = userCredential.user!.uid;
          print("Login successful! User ID: $uid");
          
          // Check if the user has a Firestore document
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
              
          // Create user document if it doesn't exist
          if (!userDoc.exists) {
            print("User document not found, creating one");
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'username': userCredential.user!.displayName ?? 'User',
              'email': userCredential.user!.email ?? '',
              'profilePicture': '',
              'friends': [],
              'badges': {},
              'quizzes': [],
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful!')),
          );
          
          // Navigate to home page
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      } on FirebaseAuthException catch (e) {
        print("DETAILED AUTH ERROR: ${e.toString()}");
        print("Error code: ${e.code}");
        print("Error message: ${e.message}");
        
        // Provide user-friendly error messages
        String errorMsg;
        switch (e.code) {
          case 'user-not-found':
            errorMsg = 'No user found with this email. Please register first.';
            break;
          case 'wrong-password':
            errorMsg = 'Incorrect password. Please try again.';
            break;
          case 'invalid-email':
            errorMsg = 'Invalid email format. Please enter a valid email address.';
            break;
          case 'user-disabled':
            errorMsg = 'This account has been disabled. Please contact support.';
            break;
          default:
            errorMsg = 'Login failed: ${e.message}';
        }
        
        setState(() {
          _errorMessage = errorMsg;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'An error occurred: ${e.toString()}';
        });
        print("Login error: $e");
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: 350,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/logo.png',
                        height: 120,
                        width: 200,
                      ),
                      const SizedBox(height: 30),
                      
                      // Error message
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      
                      // Email/Username field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            hintText: 'Email or Username',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            border: InputBorder.none,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email or username';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      // Password field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            hintText: 'Password',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            border: InputBorder.none,
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      // Forgot Password link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // Handle forgot password
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Login and Register buttons
                      _isLoading 
                          ? Column(
                              children: [
                                const CircularProgressIndicator(color: Colors.white),
                                const SizedBox(height: 10),
                                Text(
                                  'Processing... This might take a moment',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    // Navigate to registration page
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const RegistrationPage(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text(
                                    'Register',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 