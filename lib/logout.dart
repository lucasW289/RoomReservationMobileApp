import 'package:flutter/material.dart';
import 'package:mobile_app_project/Home.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motion_toast/motion_toast.dart';
import 'config.dart'; // Import the config file

class Logout extends StatefulWidget {
  final String userRole;

  const Logout({super.key, required this.userRole});

  @override
  _LogoutState createState() => _LogoutState();
}

class _LogoutState extends State<Logout> {
  String username = '';
  String userId = '';
  String name = '';
  String newPassword = '';
  final _formKey = GlobalKey<FormState>();

  // TextEditingControllers to handle form input
  TextEditingController usernameController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();

  // FocusNode to change the label text when focused
  FocusNode usernameFocusNode = FocusNode();
  FocusNode nameFocusNode = FocusNode();
  FocusNode passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    fetchUserDetails(); // Fetch user details when the widget is initialized
  }

  Future<void> fetchUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No token found. Please login again.')),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/user/details'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          username = data['user']['username'];
          userId = data['user']['id'].toString();
          name = data['user']['name']; // Assuming the server returns 'name'
          usernameController.text = username; // Set controller text
          nameController.text = name; // Set controller text
        });
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Failed to fetch user details')),
        );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Network error. Please try again.')),
      // );
    }
  }

  Future<void> updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No token found. Please login again.')),
      );
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('${Config.baseUrl}/user/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'username': username,
          'name': name,
          'newPassword': newPassword.isNotEmpty
              ? newPassword
              : null, // Send the new password if provided
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Profile updated successfully'),
          ),
        );
        if (data['user'] != null) {
          setState(() {
            username = data['user']['username'];
            name = data['user']['name'];
          });
        }
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to update profile'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.')),
      );
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No token found. Please login again.')),
      );
      return;
    }

    try {
      // print('Token: $token'); // Debugging
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/auth/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // print('Response status: ${response.statusCode}');
      // print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        await prefs.remove('token');
        MotionToast.success(
          description: const Text("Logout successful"),
          width: 300,
          height: 50,
          position: MotionToastPosition.top,
          animationType: AnimationType.fromTop,
        ).show(context);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
          );
        }
      } else {
        final data =
            response.body.isNotEmpty ? jsonDecode(response.body) : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data?['message'] ?? 'Logout failed')),
        );
      }
    } catch (e) {
      // print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.')),
      );
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    nameController.dispose();
    newPasswordController.dispose();
    usernameFocusNode.dispose();
    nameFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        title: Row(
          children: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context); // Go back to the previous screen
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Go Back',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10), // Space between button and title
            Text(
              "${widget.userRole}'s Profile", // Access userRole via widget object
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey,
                  child: Icon(
                    Icons.person,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: usernameController, // Use the controller
                        focusNode: usernameFocusNode,
                        decoration: InputDecoration(
                          labelText: username.isEmpty
                              ? 'Username'
                              : username, // Show placeholder if empty
                          hintText: 'Enter your username',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            username = value;
                          });
                        },
                        onTap: () {
                          setState(() {
                            usernameController.text = '';
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameController, // Use the controller
                        focusNode: nameFocusNode,
                        decoration: InputDecoration(
                          labelText: name.isEmpty
                              ? 'Name'
                              : name, // Show placeholder if empty
                          hintText: 'Enter your name',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            name = value;
                          });
                        },
                        onTap: () {
                          setState(() {
                            nameController.text = '';
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: newPasswordController,
                        focusNode: passwordFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'New password',
                          hintText: 'Enter your new password',
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value != null && value.length < 4) {
                            return 'Password must be at least 4 characters';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            newPassword = value;
                          });
                        },
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: updateProfile,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black),
                        child: const Text(
                          'Update Profile',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: logout,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
