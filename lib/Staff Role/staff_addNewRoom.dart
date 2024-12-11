import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app_project/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AddRoomScreen(),
    );
  }
}

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({super.key});

  @override
  _AddRoomScreenState createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final TextEditingController roomNameController = TextEditingController();
  final TextEditingController peopleController = TextEditingController();
  bool isRoomEnabled = false;
  String? _selectedImage;
  late SharedPreferences prefs;

  // New variable to track Wi-Fi status (as a string "1" or "0")
  String wifiStatus = "0"; // Default is "no" (0)

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  void _loadPrefs() async {
    prefs = await SharedPreferences.getInstance();
  }

  Future<void> _saveRoom() async {
    final accessToken = prefs.getString('token');
    if (accessToken == null || accessToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token is missing. Please log in.')),
      );
      return;
    }

    if (roomNameController.text.isEmpty ||
        peopleController.text.isEmpty ||
        _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all fields and select an image')),
      );
      return;
    }

    final imageName = _selectedImage?.split('/').last ?? '';

    // Debugging: print the room enable state and wifi status
    // print("Room enabled: $isRoomEnabled");
    // print("Wi-Fi status: $wifiStatus"); // Added print statement for wifi status

    // Set `ena` to 'free' if enabled, 'disable' if not
    final enaStatus = isRoomEnabled ? 'free' : 'disabled'; // This looks correct

    final response = await http.post(
      Uri.parse('${Config.baseUrl}/add'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': roomNameController.text,
        'ena': enaStatus, // Use the dynamic value here
        'num': peopleController.text,
        'wifi': wifiStatus, // Use the "1" or "0" string value
        'image': imageName,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room added successfully!')),
      );
      setState(() {
        _selectedImage = null;
        roomNameController.clear();
        peopleController.clear();
        wifiStatus = "0"; // Reset wifi status to "no"
        isRoomEnabled = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add room. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> roomImages = [
      'assets/images/room1.png',
      'assets/images/room2.png',
      'assets/images/room3.png',
      'assets/images/room4.png',
      'assets/images/room5.png',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Add Room')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: roomNameController,
              decoration: const InputDecoration(labelText: 'Room Name'),
            ),
            SwitchListTile(
              title: const Text('Enable Room'),
              value: isRoomEnabled,
              onChanged: (value) {
                // print("Switch Toggled: $value"); // Debugging print statement
                setState(() {
                  isRoomEnabled = value;
                });
              },
            ),
            TextField(
              controller: peopleController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Number of People'),
            ),
            const SizedBox(height: 20),
            const Text('Wi-Fi (Yes/No)'),
            Row(
              children: [
                Row(
                  children: [
                    Radio<String>(
                      value: "1", // "Yes" value
                      groupValue: wifiStatus,
                      onChanged: (String? value) {
                        setState(() {
                          wifiStatus = value!;
                        });
                        // print(
                        //     "Wi-Fi status: $wifiStatus"); // Print the new wifi status
                      },
                    ),
                    const Text("Yes"),
                  ],
                ),
                const SizedBox(
                  width: 20,
                ),
                Row(
                  children: [
                    Radio<String>(
                      value: "0", // "No" value
                      groupValue: wifiStatus,
                      onChanged: (String? value) {
                        setState(() {
                          wifiStatus = value!;
                        });
                        // print(
                        //     "Wi-Fi status: $wifiStatus"); // Print the new wifi status
                      },
                    ),
                    const Text("No"),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Select Image'),
            GridView.builder(
              shrinkWrap: true,
              itemCount: roomImages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final imageName = roomImages[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImage = imageName;
                    });
                    // print(
                    //     "Selected Image: $imageName"); // Debugging print statement
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedImage == imageName
                            ? Colors.blue
                            : Colors.grey,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset(
                      imageName,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                        roomNameController.clear();
                        peopleController.clear();
                        wifiStatus = "0"; // Reset wifi status to "no"
                        isRoomEnabled = false;
                      });
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.black),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
