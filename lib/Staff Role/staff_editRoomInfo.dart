import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:motion_toast/motion_toast.dart';

class EditRoomScreen extends StatefulWidget {
  final int roomID;
  final String accessToken;

  const EditRoomScreen(
      {super.key, required this.roomID, required this.accessToken});

  @override
  _EditRoomScreenState createState() => _EditRoomScreenState();
}

class _EditRoomScreenState extends State<EditRoomScreen> {
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();
  bool _isWifiAvailable = false; // Wi-Fi status initialized
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRoomDetails(); // Fetch the details of the room when the screen is initialized
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  // Fetch the room details from the server using the roomID
  Future<void> _fetchRoomDetails() async {
    setState(() {
      _isLoading = true;
    });

    final response = await http.get(
      Uri.parse('http://localhost:5001/rooms/${widget.roomID}'),
      headers: {
        'Authorization': 'Bearer ${widget.accessToken}',
      },
    );

    if (response.statusCode == 200) {
      try {
        var responseData = json.decode(response.body);
        var roomData = responseData['room'];

        setState(() {
          _nameController.text = roomData['room_name'] ?? '';
          _capacityController.text =
              roomData['room_capacity']?.toString() ?? '';
          _isWifiAvailable =
              roomData['is_wifi_available'] == 1; // Correctly set Wi-Fi status
        });
      } catch (e) {
        print("Error decoding room details: $e");
      }
    } else {
      MotionToast.error(
        title: const Text("Error"),
        description: Text(
            "Failed to fetch room details. Status code: ${response.statusCode}"),
      ).show(context);
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Function to update the room details on the server using PATCH method
  Future<void> _updateRoomDetails() async {
    setState(() {
      _isLoading = true;
    });

    final roomName = _nameController.text;
    final capacity = int.tryParse(_capacityController.text);
    final wifi = _isWifiAvailable ? 1 : 0; // Convert Wi-Fi status to 1/0

    if (roomName.isEmpty || capacity == null || capacity <= 0) {
      MotionToast.error(
        title: const Text("Error"),
        description: const Text("Please enter valid room details."),
      ).show(context);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final response = await http.patch(
      Uri.parse('http://localhost:5001/rooms/${widget.roomID}/edit'),
      headers: {
        'Authorization': 'Bearer ${widget.accessToken}',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': roomName,
        'capacity': capacity,
        'wifi': wifi, // Send the updated Wi-Fi status
      }),
    );

    if (response.statusCode == 200) {
      MotionToast.success(
        title: const Text("Success"),
        description: const Text("Room details updated successfully."),
      ).show(context);
      Navigator.pop(context); // Go back to the previous screen
    } else {
      MotionToast.error(
        title: const Text("Error"),
        description: const Text("Failed to update room details."),
      ).show(context);
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room Name Input
                  const Text(
                    'Room Name',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Capacity Input
                  const Text(
                    'Capacity',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Wi-Fi Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Wi-Fi Available',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Switch(
                        value: _isWifiAvailable,
                        onChanged: (value) {
                          setState(() {
                            _isWifiAvailable = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Update Button
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _updateRoomDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black, // Correct color
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Update Room Details',
                            style: TextStyle(color: Colors.white),
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
