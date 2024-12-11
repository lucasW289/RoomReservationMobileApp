import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app_project/Staff%20Role/staff_addNewRoom.dart';
import 'package:mobile_app_project/config.dart';
import 'package:motion_toast/motion_toast.dart';
import 'dart:async';

class RoomBookingScreen extends StatefulWidget {
  final String role;

  const RoomBookingScreen({super.key, required this.role});

  @override
  _RoomBookingScreenState createState() => _RoomBookingScreenState();
}

class _RoomBookingScreenState extends State<RoomBookingScreen> {
  Map<String, List<String>> roomStatuses = {};
  bool isLoading = true; // Initial loading state
  late Timer _timer; // Timer for polling

  @override
  void initState() {
    super.initState();
    fetchRoomData();
    _startPolling(); // Start polling
  }

  void _startPolling() {
    // Poll every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      fetchRoomData();
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when widget is disposed
    super.dispose();
  }

  Future<void> fetchRoomData() async {
    setState(() {
      isLoading = true; // Show loading state while fetching
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${Config.baseUrl}/rooms/'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Print the raw response for debugging
        // print('Received data: $data');

        // Check if data structure is valid
        if (data is Map && data['rooms'] is List) {
          setState(() {
            roomStatuses = {
              for (var room in data['rooms'])
                room['roomID'].toString(): room['slots'].map<String>((slot) {
                  return slot['status']
                      .toString(); // Use the actual status from the database
                }).toList(),
            };
            isLoading = false;
          });

          // Print room details to the console
          for (var room in data['rooms']) {
            String roomId = room['roomID'].toString();
            String roomName = room['roomName'] ?? 'Unnamed Room';
            List<String> slotStatuses = room['slots'].map<String>((slot) {
              return slot['status'].toString();
            }).toList();

            // Print the room details in the format you requested
            // print('$roomId  | $roomName  | ${slotStatuses.join(' | ')}');
          }
        } else {
          // print('Unexpected data structure: $data');
          setState(() {
            isLoading = false;
          });
        }
      } else {
        // print('Failed to load room data: ${response.body}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (error) {
      // print('Error fetching room data: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateSlotStatus(
      String roomId, int slotIndex, String newStatus) async {
    // Only allow updates if the new status is not "free" or "disabled"
    if (newStatus == 'free' || newStatus == 'disabled') {
      // If it's 'free' or 'disabled', just update the local state, no DB call
      setState(() {
        roomStatuses[roomId]![slotIndex] = newStatus;
      });

      // Show a toast notification when the room is marked as 'free' or 'disabled'
      MotionToast.success(
        title: const Text("Success"),
        description: Text("$newStatus the room successfully!"),
        toastDuration: const Duration(seconds: 2),
      ).show(context);
      return; // Skip database update
    }

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('token');

    try {
      final response = await http.patch(
        Uri.parse('${Config.baseUrl}/rooms/$roomId/$slotIndex/toggle-status'),
        headers: {'Authorization': 'Bearer $accessToken'},
        body: json.encode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        fetchRoomData(); // Refresh room data after update
        // Show success toast after updating the status successfully in the backend
        MotionToast.success(
          title: const Text("Success"),
          description: Text("$newStatus the room successfully!"),
          toastDuration: const Duration(seconds: 2),
        ).show(context);
      } else {
        MotionToast.error(
          title: const Text("Error"),
          description: const Text("Failed to update status"),
          toastDuration: const Duration(seconds: 2),
        ).show(context);
      }
    } catch (error) {
      MotionToast.error(
        title: const Text("Error"),
        description: const Text("Failed to update status"),
        toastDuration: const Duration(seconds: 2),
      ).show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Editing Rooms',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Divider(thickness: 1, color: Colors.grey[300]),
                    const SizedBox(height: 10),

                    // Table Header
                    const Row(
                      children: [
                        Expanded(
                            child: Text('Time',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                          child: Column(
                            children: [
                              Text('08:00', textAlign: TextAlign.center),
                              Text('-', textAlign: TextAlign.center),
                              Text('10:00', textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text('10:00', textAlign: TextAlign.center),
                              Text('-', textAlign: TextAlign.center),
                              Text('12:00', textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text('13:00', textAlign: TextAlign.center),
                              Text('-', textAlign: TextAlign.center),
                              Text('15:00', textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text('15:00', textAlign: TextAlign.center),
                              Text('-', textAlign: TextAlign.center),
                              Text('17:00', textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Room Booking Table
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: roomStatuses.keys.map((roomId) {
                            // print(
                            //     "Room status : Room ID:  ${roomStatuses[roomId]!}");
                            return buildRoomRow(roomId, roomStatuses[roomId]!);
                          }).toList(),
                        ),
                      ),
                    ),

                    // Add New Rooms Button
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AddRoomScreen()),
                          );
                        },
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Add new rooms',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          minimumSize: const Size(150, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
      ),
    );
  }

// Updated buildStatusDropdown method to ensure each time slot is independent
  Widget buildRoomRow(String roomId, List<String> slots) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Room ID with a bold style
          Expanded(
            flex: 2,
            child: Text(
              roomId,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // Loop through the slots to show the status (with dropdown)
          ...slots.asMap().entries.map((entry) {
            int index = entry.key;
            String status = entry.value;
            // print("StatusDropDown : ${roomId}....${index}...${status}");
            return Expanded(
              flex: 2,
              child: Center(
                child: buildStatusDropdown(roomId, index, status),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildStatusDropdown(String roomId, int index, String currentStatus) {
    List<String> statuses = [
      'free',
      'disabled',
      'reserved', // Added Reserved status
      'pending', // Added Pending status
    ];

    // Dropdown list only for 'free' and 'disabled' statuses
    List<String> dropDownList = [
      'free',
      'disabled',
    ];

    // Ensure currentStatus is valid or default to 'free'
    if (!statuses.contains(currentStatus)) {
      currentStatus = 'free'; // Default to 'free' if status is invalid
      // print('Invalid status. Defaulting to "free"');
    }

    Color getStatusColor(String status) {
      switch (status) {
        case 'free':
          return const Color(0xFF4DC591);
        case 'disabled':
          return const Color(0xFF88889D);
        case 'reserved': // Color for reserved status
          return const Color(0xFFDD6B4B);
        case 'pending': // Color for pending status
          return const Color(0xFFFCB943);
        default:
          return Colors.grey;
      }
    }

    return SizedBox(
      height: 30, // Fixed height for consistency
      child: currentStatus == 'reserved' || currentStatus == 'pending'
          ? Container(
              width: 55, // Fixed width for consistency
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(
                color: getStatusColor(currentStatus),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  currentStatus,
                  style: const TextStyle(color: Colors.white, fontSize: 8),
                ),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentStatus,
                icon: const Icon(Icons.arrow_drop_down, size: 8),
                elevation: 15,
                style: const TextStyle(color: Colors.white, fontSize: 8),
                onChanged: (String? newValue) {
                  if (newValue != null && newValue != currentStatus) {
                    updateSlotStatus(roomId, index, newValue);
                  }
                },
                items: dropDownList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Container(
                      width: 55, // Fixed width for consistency
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 2),
                      decoration: BoxDecoration(
                        color: getStatusColor(value),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          value,
                          style:
                              const TextStyle(color: Colors.white, fontSize: 8),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
