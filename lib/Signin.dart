import 'package:flutter/material.dart';
import 'package:mobile_app_project/Signup.dart';
import 'package:mobile_app_project/Lecturer%20Role/lect_home.dart';
import 'package:mobile_app_project/Staff%20Role/staff_home.dart';
import 'package:mobile_app_project/Student%20Role/stu_home.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:motion_toast/motion_toast.dart';
import 'config.dart'; // Import the config file

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SignInScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final String url = Config.baseUrl; // Use the baseUrl directly
  bool isWaiting = false;
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  String _usernameError = '';
  String _passwordError = '';

  // Login function
  void login() async {
    setState(() {
      isWaiting = true;
      _usernameError = '';
      _passwordError = '';
    });

    if (_idController.text.isEmpty) {
      setState(() {
        _usernameError = 'Please input your username';
        isWaiting = false;
      });
      _showErrorToast('Please input your username.');
      return;
    } else if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = 'Please input your password';
        isWaiting = false;
      });
      _showErrorToast('Please input your password.');
      return;
    }

    try {
      Uri uri = Uri.parse('$url/auth/login'); // Use the updated base URL
      Map<String, String> account = {
        'username': _idController.text.trim(),
        'password': _passwordController.text.trim(),
      };

      http.Response response = await http.post(
        uri,
        body: jsonEncode(account),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['accessToken']);

        final jwt = JWT.decode(data['accessToken']);
        Map<String, dynamic> payload = jwt.payload;

        // Safely check for role in the payload
        String role = payload['role']?.toLowerCase() ?? '';
        Widget homeScreen;

        switch (role) {
          case 'student':
            homeScreen = StuHomeScreen(accessToken: data['accessToken']);
            break;
          case 'staff':
            homeScreen = StaffHomeScreen(accessToken: data['accessToken']);
            break;
          case 'lecturer':
            homeScreen = LectHomeScreen(accessToken: data['accessToken']);
            break;
          default:
            setState(() {
              _passwordError = 'Unknown role';
            });
            _showErrorToast('Unknown role.');
            return;
        }

        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => homeScreen));

        // Show success toast
        _showSuccessToast('Login Successful! Welcome back!');
      } else if (response.statusCode == 401) {
        setState(() {
          _passwordError = 'Username or Password incorrect';
        });
        _showErrorToast('Incorrect username or password.');
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _passwordError = data['message'] ?? 'Unexpected error occurred';
        });
        _showErrorToast(data['message'] ?? 'Unexpected error occurred');
      }
    } catch (e) {
      setState(() {
        _passwordError = 'Network error. Please try again.';
      });
      _showErrorToast(
          'Network error. Please check your connection and try again.');
    } finally {
      setState(() {
        isWaiting = false;
      });
    }
  }

  // Function to show error toast
  void _showErrorToast(String message) {
    // MotionToast.error(
    //   title: const Text("Error"),
    //   description: Text(message),
    //   animationType: AnimationType.fromTop,
    //   position: MotionToastPosition.top,
    // ).show(context);
  }

  // Function to show success toast
  void _showSuccessToast(String message) {
    MotionToast.success(
      title: const Text("Success"),
      description: Text(message),
      animationType: AnimationType.fromTop,
      position: MotionToastPosition.top,
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              const Text(
                'Sign in',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontFamily: "Poppins-Bold",
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Login into the Booking Room App...',
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(179, 22, 21, 21),
                  fontFamily: "Poppins",
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _idController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Username',
                  labelStyle: const TextStyle(
                      color: Colors.black, fontFamily: "Poppins", fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                ),
                cursorColor: Colors.black,
                style: const TextStyle(color: Colors.black),
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
                      color: Colors.black, fontFamily: "Poppins", fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                ),
                cursorColor: Colors.black,
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 10),
              if (_usernameError.isNotEmpty)
                Text(
                  _usernameError,
                  style:
                      const TextStyle(color: Colors.red, fontFamily: "Poppins"),
                ),
              if (_passwordError.isNotEmpty)
                Text(
                  _passwordError,
                  style:
                      const TextStyle(color: Colors.red, fontFamily: "Poppins"),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignUpScreen()),
                      );
                    },
                    child: const Text(
                      'Create an account?',
                      style:
                          TextStyle(color: Colors.black, fontFamily: "Poppins"),
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
                    onPressed: isWaiting ? null : login,
                    child: isWaiting
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            'Sign in',
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
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
