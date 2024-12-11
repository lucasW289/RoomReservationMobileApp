import 'package:flutter/material.dart';
import 'package:mobile_app_project/Signin.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:motion_toast/motion_toast.dart';
import 'package:mobile_app_project/config.dart'; // Import the config file

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SignUpScreen(),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final String url = Config.baseUrl; // Use the baseUrl directly
  bool isWaiting = false;
  bool isSignUpComplete = false;

  final _idController = TextEditingController();
  final _usernameController =
      TextEditingController(); // Add username controller
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Declare state variables for error messages
  String _idError = '';
  String _usernameError = ''; // Username error
  String _nameError = '';
  String _passwordError = '';
  String _confirmPasswordError = '';

  void signup() async {
    setState(() {
      isWaiting = true;
      // Clear previous error messages
      _idError = '';
      _usernameError = '';
      _nameError = '';
      _passwordError = '';
      _confirmPasswordError = '';
    });

    // Validation in Flutter for better UX
    if (_idController.text.isEmpty) {
      setState(() {
        _idError = 'Input your ID';
        isWaiting = false;
      });
      MotionToast.error(
        description: const Text('ID is required'),
      ).show(context);
      return;
    }
    if (_usernameController.text.isEmpty) {
      setState(() {
        _usernameError = 'Input your username';
        isWaiting = false;
      });
      MotionToast.error(
        description: const Text('Username is required'),
      ).show(context);
      return;
    }
    if (_nameController.text.isEmpty) {
      setState(() {
        _nameError = 'Input your Name';
        isWaiting = false;
      });
      MotionToast.error(
        description: const Text('Name is required'),
      ).show(context);
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = 'Input your password';
        isWaiting = false;
      });
      MotionToast.error(
        description: const Text('Password is required'),
      ).show(context);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match';
        isWaiting = false;
      });
      MotionToast.error(
        description: const Text('Passwords do not match'),
      ).show(context);
      return;
    }

    try {
      Uri uri = Uri.parse('$url/auth/signup');
      Map<String, dynamic> account = {
        'id': _idController.text.trim(),
        'username': _usernameController.text.trim(), // Include username
        'name': _nameController.text.trim(),
        'password': _passwordController.text.trim(),
        'confirmPassword': _confirmPasswordController.text.trim(),
      };

      http.Response response = await http.post(
        uri,
        body: jsonEncode(account),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          isSignUpComplete = true;
        });

        MotionToast.success(
          description: const Text('Sign-up successful!'),
        ).show(context);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignInScreen()),
        );
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _passwordError = data['message'];
        });

        // MotionToast.error(
        //   description: Text('Error: ${data['message']}'),
        // ).show(context);
      }
    } catch (e) {
      setState(() {
        _passwordError = 'Network error. Please try again.';
      });

      MotionToast.error(
        description: const Text('Network error. Please try again.'),
      ).show(context);
    } finally {
      setState(() {
        isWaiting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sign up',
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 34, 34, 34),
                        fontFamily: "Poppins-Bold"),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Create the Account for The Booking Room App..',
                    style: TextStyle(
                        fontSize: 16,
                        color: Color.fromARGB(179, 29, 29, 29),
                        fontFamily: "Poppins"),
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _idController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'ID',
                      labelStyle: const TextStyle(
                          color: Colors.black,
                          fontFamily: "Poppins",
                          fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    cursorColor: Colors.black,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Username',
                      labelStyle: const TextStyle(
                          color: Colors.black,
                          fontFamily: "Poppins",
                          fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    cursorColor: Colors.black,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Name',
                      labelStyle: const TextStyle(
                          color: Colors.black,
                          fontFamily: "Poppins",
                          fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    cursorColor: Colors.black,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Password',
                      labelStyle: const TextStyle(
                          color: Colors.black,
                          fontFamily: "Poppins",
                          fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    cursorColor: Colors.black,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Confirm Password',
                      labelStyle: const TextStyle(
                          color: Colors.black,
                          fontFamily: "Poppins",
                          fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    cursorColor: Colors.black,
                  ),
                  const SizedBox(height: 10),
                  if (_idError.isNotEmpty)
                    Text(_idError, style: const TextStyle(color: Colors.red)),
                  if (_usernameError.isNotEmpty)
                    Text(_usernameError,
                        style: const TextStyle(color: Colors.red)),
                  if (_nameError.isNotEmpty)
                    Text(_nameError, style: const TextStyle(color: Colors.red)),
                  if (_passwordError.isNotEmpty)
                    Text(_passwordError,
                        style: const TextStyle(color: Colors.red)),
                  if (_confirmPasswordError.isNotEmpty)
                    Text(_confirmPasswordError,
                        style: const TextStyle(color: Colors.red)),
                  if (isSignUpComplete)
                    const Text('Sign Up Complete',
                        style: TextStyle(color: Colors.green)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SignInScreen()),
                          );
                        },
                        child: const Text(
                          'Already an account?',
                          style: TextStyle(
                              color: Colors.black, fontFamily: "Poppins"),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: signup,
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                              color: Colors.white, fontFamily: "Poppins"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  @override
  void dispose() {
    _idController.dispose();
    _usernameController.dispose(); // Dispose username controller
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
