import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app_project/Staff%20Role/staff_editRoomInfo.dart';
import 'dart:convert';
import 'dart:async';
import 'package:motion_toast/motion_toast.dart';
import 'package:mobile_app_project/config.dart'; // Import the config file

// Enum for room status
enum RoomStatus { free, reserved, pending, disabled }

class StaffBrowseRoomList extends StatefulWidget {
  final String role;
  final String accessToken;
  final TextEditingController _searchController = TextEditingController();

  // Constructor to receive the role and access token
  StaffBrowseRoomList(
      {super.key, required this.role, required this.accessToken});

  @override
  _StaffBrowseRoomListState createState() => _StaffBrowseRoomListState();
}

class _StaffBrowseRoomListState extends State<StaffBrowseRoomList> {
  List<Map<String, dynamic>> rooms = [];
  List<Map<String, dynamic>> filteredRooms =
      []; // To store the filtered rooms based on search query
  final TextEditingController _searchController = TextEditingController();
  late Timer _timer; // Timer for polling

  @override
  void initState() {
    super.initState();
    _fetchRooms(); // Fetch room data when the widget is initialized
    _startPolling(); // Start polling

    // Add listener to the search field to filter rooms as the user types
    _searchController.addListener(() {
      _filterRooms(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _timer.cancel(); // Cancel the timer when widget is disposed
    super.dispose();
  }

  void _startPolling() {
    // Poll every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchRooms();
    });
  }

  // Function to filter rooms based on search query
  void _filterRooms(String query) {
    final filtered = rooms.where((room) {
      final roomName = room['name'].toLowerCase();
      return roomName.contains(query.toLowerCase());
    }).toList();

    setState(() {
      filteredRooms = filtered;
    });
  }

  Future<void> _fetchRooms() async {
    final response = await http.get(
      Uri.parse('${Config.baseUrl}/rooms'),
      headers: {
        'Authorization': 'Bearer ${widget.accessToken}',
      },
    );

    if (response.statusCode == 200) {
      try {
        var responseData = json.decode(response.body);

        if (responseData['rooms'] is List) {
          List<Map<String, dynamic>> fetchedRooms = [];
          for (var room in responseData['rooms']) {
            List<Map<String, dynamic>> slots =
                (room['slots'] as List).map((slot) {
              return {
                'time': slot['time'],
                'status': RoomStatus.values.firstWhere(
                  (e) => e.toString().split('.').last == slot['status'],
                  orElse: () => RoomStatus.free,
                ),
              };
            }).toList();
            // Extract the wifi value and print it to the console
            String wifi = room['wifi'] == 0 ? 'No' : 'Free';
            // print(
            //     'Wifi for room ${room['roomName']}: $wifi'); // Print the wifi status

            fetchedRooms.add({
              'name': room['roomName'] ?? 'Unnamed',
              'roomID': room['roomID'],
              'capacity': room['capacity']?.toString() ?? 'N/A',
              'wifi': wifi,
              'imagePath': room['imagePath'] ?? '',
              'slots': slots,
            });
          }

          setState(() {
            rooms = fetchedRooms;
            filteredRooms = fetchedRooms; // Initially show all rooms
          });

          // Success toast
          // MotionToast.success(
          //   title: Text("Success"),
          //   description: Text("Rooms data loaded successfully."),
          // ).show(context);
        } else {
          // print(
          //     "Response data is not a list, it's a map. Response: $responseData");
        }
      } catch (e) {
        // print("Error decoding response body: $e");

        // // Error toast for decoding issues
        // MotionToast.error(
        //   title: Text("Error"),
        //   description: Text("Failed to decode room data."),
        // ).show(context);
      }
    }
// else {
    //     // print('Failed to load room data. Status code: ${response.statusCode}');

    //     // Error toast for failed request
    //     MotionToast.error(
    //       title: Text("Error"),
    //       description: Text(
    //           "Failed to load room data. Status code: ${response.statusCode}"),
    //     ).show(context);
    //   }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    String dayOfMonth = DateFormat('d').format(now);
    String dayOfWeek = DateFormat.EEEE().format(now);
    String monthYear = DateFormat('MMMM yyyy').format(now);

    bool hasAvailableRooms = filteredRooms.any((room) =>
        room['slots'].any((slot) => slot['status'] == RoomStatus.free));

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search TextField
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterRooms(
                              ''); // Clear the filtered rooms when the text is cleared
                        },
                      )
                    : null, // If the text is empty, no icons are displayed
                hintText: 'Browse room name',
                filled: true,
                fillColor: const Color(0xFFECE6F0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged:
                  _filterRooms, // Call the filter function on every change
            ),

            const SizedBox(
                height: 20), // Adding some space after the search field

            // Status labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusLabel('Free', const Color(0xFF4DC591)),
                _buildStatusLabel('Reserved', const Color(0xFFFF0000)),
                _buildStatusLabel('Pending', const Color(0xFFFFB948)),
                _buildStatusLabel('Disabled', const Color(0xFF88889D)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: filteredRooms.isEmpty
                  ? const Center(
                      child: Text(
                        "No rooms found for your search.",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : (hasAvailableRooms
                      ? ListView.builder(
                          itemCount: filteredRooms.length,
                          itemBuilder: (context, index) {
                            final room = filteredRooms[index];
                            return _buildRoomCard(
                              room['name'] ?? 'Unnamed',
                              room['roomID'],
                              room['capacity'] ?? 'N/A',
                              room['wifi'] ?? 'N/A',
                              room['imagePath'] ?? '',
                              room['slots'],
                              // Pass the slots data
                            );
                          },
                        )
                      : const Center(
                          child: Text(
                            "Currently, no free rooms are available.",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build status labels
  Widget _buildStatusLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  // A refined version for the room card widget, with slot handling and better performance.

  Widget _buildRoomCard(String roomName, int roomID, String capacity,
      String wifi, String imagePath, List<Map<String, dynamic>> slots) {
    return SizedBox(
      width: MediaQuery.of(context).size.width - 32,
      height: 180,
      child: Card(
        color: const Color(0xFFECE6F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              // Main Row for Room details
              Row(
                children: [
                  // Room image
                  Container(
                    width: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: (imagePath.isNotEmpty)
                            ? AssetImage('assets/images/$imagePath')
                            : const AssetImage('assets/images/room1.png')
                                as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Room details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        // Room nameno
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditRoomScreen(
                                  roomID: roomID,
                                  accessToken: widget.accessToken,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            roomName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person, size: 16),
                                const SizedBox(width: 4),
                                Text('Capacity: $capacity'),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(
                                  wifi == '0'
                                      ? Icons.signal_wifi_off
                                      : Icons.wifi,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text('Wifi: $wifi'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Time slots
                        Column(
                          children: _buildSlotGrid(slots),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditRoomScreen(
                          roomID: roomID,
                          accessToken: widget.accessToken,
                        ),
                      ),
                    );
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue, size: 18),
                      SizedBox(width: 4),
                      Text(
                        "Edit Room",
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
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
    );
  }

  // Helper function to build a grid of 4 slots (2x2 layout)
  List<Widget> _buildSlotGrid(List<Map<String, dynamic>> slots) {
    List<Widget> slotWidgets = [];
    int slotIndex = 0;

    // 2x2 grid layout: top-left, top-right, bottom-left, bottom-right
    for (int row = 0; row < 2; row++) {
      List<Widget> rowWidgets = [];
      for (int col = 0; col < 2; col++) {
        if (slotIndex < slots.length) {
          rowWidgets.add(
            Expanded(
              child: _buildSlotLabel(
                slots[slotIndex]['time'],
                _getSlotColor(slots[slotIndex]['status']),
              ),
            ),
          );
          slotIndex++;
        } else {
          rowWidgets.add(
            Expanded(
              child: Container(), // Empty slot if not enough slots
            ),
          );
        }
      }
      slotWidgets.add(
        Row(
          children: rowWidgets,
        ),
      );
    }

    return slotWidgets;
  }

  // Helper function to get the color based on the slot status
  Color _getSlotColor(RoomStatus status) {
    switch (status) {
      case RoomStatus.free:
        return const Color(0xFF4DC591); // Green for Free
      case RoomStatus.reserved:
        return const Color(0xFFFF0000); // Red for Reserved
      case RoomStatus.pending:
        return const Color(0xFFFFB948); // Orange for Pending
      case RoomStatus.disabled:
        return const Color(0xFF88889D); // Gray for Disabled
      default:
        return const Color(0xFF4DC591); // Default to green if unknown
    }
  }

  // Helper function to build the slot label
  Widget _buildSlotLabel(String time, Color color) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
