import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:mobile_app_project/config.dart'; // Import the config file

class StuBooking extends StatefulWidget {
  const StuBooking({
    super.key,
    required this.role,
    required this.roomID,
    required this.accessToken,
  });

  @override
  State<StuBooking> createState() => _StuBookingState();
  final String role;
  final int roomID;
  final String accessToken;
}

class _StuBookingState extends State<StuBooking> {
  List<Map<String, dynamic>> slots = [];
  bool isLoading = true;
  bool isRoomReserved = false;
  String roomName = '';
  String roomImage = '';
  int roomCapacity = 0;
  bool isWifiAvailable = false;
  final PageController _pageController = PageController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchRoomDetails();
  }

  Future<void> fetchRoomDetails() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/rooms/${widget.roomID}'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          final room = data['room'];
          roomName = room['room_name'] ?? 'Room';
          roomImage = room['image_url'] ?? 'assets/images/default_room.png';
          roomCapacity = room['room_capacity'] ?? 0;
          isWifiAvailable = room['is_wifi_available'] == 1;
          slots = List<Map<String, dynamic>>.from(
            data['slots'].map((slot) => {
                  'slot_id': slot['slot_id'],
                  'time_range': slot['time_range'],
                  'status': slot['status'],
                  'user_id': slot['user_id'],
                  'created_at': slot['created_at']
                }),
          );
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load room details');
      }
    } catch (e) {
      print("Error fetching room details: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showReservationDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Confirm Booking',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text('Do you want to reserve this room?'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 77, 197, 145),
              ),
              onPressed: () async {
                await _bookSlot(index);
                Navigator.of(context).pop();
              },
              child: const Text('Confirm'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  String _errorMessage = ''; // This will store the error message

  Future<void> _bookSlot(int index) async {
    final slot = slots[index];
    final url = Uri.parse('${Config.baseUrl}/rooms/${widget.roomID}/book');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'slot_id': slot['slot_id'],
        }),
      );

      // Print the response status and body for debugging
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // Only update the UI if the booking was successful
        setState(() {
          slots[index]['status'] = 'pending';
          isRoomReserved = true;
          _errorMessage = ''; // Clear any previous error messages
        });
      } else if (response.statusCode == 400) {
        // Decode the response body
        final responseBody = json.decode(response.body);

        // Print to ensure we're getting the error correctly
        print('Error Message from Server: ${responseBody['error']}');

        // Set the error message in the state
        setState(() {
          _errorMessage =
              responseBody['error'] ?? 'Only one booking can be made a day';
        });
      } else {
        print('Failed to book the slot: ${response.body}');
        setState(() {
          _errorMessage = 'Failed to reserve the slot';
        });
      }
    } catch (e) {
      print("Error booking slot: $e");
      setState(() {
        _errorMessage = 'Error occurred while booking the slot';
      });
    }
  }

  void _goBack() {
    if (_selectedIndex > 0) {
      // If not the first page, go to the previous page and refresh the content
      setState(() {
        // Update any relevant state or data that needs to be refreshed here
        // For example, if you're updating slot status, etc.
      });

      // Move to the previous page in the PageView
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // If on the first page, pop the navigation stack (go back to the previous screen)
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    String dayOfMonth = DateFormat('d').format(now);
    String dayOfWeek = DateFormat.EEEE().format(now);
    String monthYear = DateFormat('MMMM yyyy').format(now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Handle logout action here
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            roomName,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10.0),
                            child: Image.network(
                              roomImage,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/images/$roomImage',
                                  height: 200,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 16),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people, size: 20),
                              const SizedBox(width: 5),
                              Text('$roomCapacity People'),
                              const SizedBox(width: 10),
                              if (isWifiAvailable) ...[
                                const Icon(Icons.wifi, size: 20),
                                const SizedBox(width: 5),
                                const Text('Wi-Fi Available'),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: slots.length,
                        itemBuilder: (context, index) {
                          final slot = slots[index];
                          Color statusColor;

                          switch (slot['status']) {
                            case 'free':
                              statusColor =
                                  const Color.fromARGB(255, 77, 197, 145);
                              break;
                            case 'pending':
                              statusColor =
                                  const Color.fromARGB(255, 255, 185, 72);
                              break;
                            case 'reserved':
                              statusColor =
                                  const Color.fromARGB(255, 255, 72, 72);
                              break;
                            default:
                              statusColor =
                                  const Color.fromARGB(255, 136, 136, 157);
                              break;
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            color: const Color.fromARGB(255, 236, 230, 240),
                            child: ListTile(
                              title: Text(slot['time_range']),
                              subtitle: Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: Text(
                                  slot['status'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              trailing: ElevatedButton(
                                onPressed: slot['status'] == 'free'
                                    ? () {
                                        _showReservationDialog(context, index);
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: slot['status'] == 'free'
                                      ? const Color.fromARGB(255, 77, 197, 145)
                                      : Colors.grey,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 5.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                ),
                                child: const Icon(Icons.arrow_forward),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
