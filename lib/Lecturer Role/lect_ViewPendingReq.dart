import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app_project/config.dart'; // Import the config file

class BookingRequestsPage extends StatefulWidget {
  const BookingRequestsPage({super.key});

  @override
  _BookingRequestsPageState createState() => _BookingRequestsPageState();
}

class _BookingRequestsPageState extends State<BookingRequestsPage> {
  int _selectedIndex = 1;
  List<dynamic> pendingBookings = [];
  bool isLoading = true;
  String errorMessage = '';
  String successMessage = ''; // To show success messages

  @override
  void initState() {
    super.initState();
    fetchPendingRequests();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Handle navigation to other pages if needed
  }

  // Fetch the access token from local storage
  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Fetch pending booking requests from the backend
  Future<void> fetchPendingRequests() async {
    const String url = "${Config.baseUrl}/bookings/pendingrequests";
    final accessToken = await _getAccessToken();

    if (accessToken == null) {
      // print("No access token found");
      return;
    }

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': 'Bearer $accessToken',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // If no pending bookings, display friendly message
        if (data['bookings'] == null || (data['bookings'] as List).isEmpty) {
          setState(() {
            isLoading = false;
            errorMessage = "No pending booking requests found for today.";
            successMessage = ''; // Clear any success message
          });
        } else {
          setState(() {
            pendingBookings = data['bookings'];
            isLoading = false;
            errorMessage = '';
            successMessage = ''; // Clear any error message
          });
        }
      } else {
        // print('Error fetching bookings: ${response.body}');
        setState(() {
          isLoading = false;
          errorMessage = 'No pending booking requests found for today.';
          successMessage = ''; // Clear any success message
        });
      }
    } catch (e) {
      // print('Error: $e');
      setState(() {
        isLoading = false;
        errorMessage =
            'Failed to fetch data. Please check your internet connection.';
        successMessage = ''; // Clear any success message
      });
    }
  }

  // Handle the approval or rejection of booking requests
  Future<void> handleDecision(String bookingID, String decision) async {
    final String url = "${Config.baseUrl}/bookings/decision/$bookingID";
    final accessToken = await _getAccessToken();

    if (accessToken == null) {
      // print("No access token found");
      return;
    }

    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'decision': decision}),
      );

      if (response.statusCode == 200) {
        // print('Decision submitted: $decision for Booking ID: $bookingID');
        setState(() {
          successMessage = 'Successfully $decision the booking request.';
        });
        fetchPendingRequests(); // Refresh the list
      } else {
        // print('Error submitting decision: ${response.body}');
        setState(() {
          successMessage = ''; // Clear any success message
        });
      }
    } catch (e) {
      // print('Error: $e');
      setState(() {
        successMessage = ''; // Clear any success message
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Pending Requests",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Search Bar for managing booking requests
            TextField(
              decoration: InputDecoration(
                hintText: 'Manage Booking Requests',
                prefixIcon: const Icon(Icons.search,
                    color: Color.fromARGB(255, 68, 68, 68)),
                suffixIcon: const Icon(Icons.close,
                    color: Color.fromARGB(255, 68, 68, 68)),
                filled: true,
                fillColor: const Color(0xFFECE6F0),
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Display loading indicator, error message, or success message
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Row is removed, text and icon will now automatically wrap
                            const Icon(
                              Icons.info_outline, // Info icon
                              color: Color.fromARGB(255, 0, 132, 255),
                              size: 20,
                            ),
                            const SizedBox(
                                height: 8), // Space between icon and text
                            Text(
                              errorMessage,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color.fromARGB(255, 0, 132, 255),
                              ),
                              textAlign:
                                  TextAlign.center, // Center align the text
                            ),
                          ],
                        ),
                      )
                    : successMessage.isNotEmpty
                        ? Center(
                            child: Text(
                              successMessage,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          )
                        : // This handles the case when neither error nor success message is available
                        Expanded(
                            child: ListView.builder(
                              itemCount: pendingBookings.length,
                              itemBuilder: (context, index) {
                                final booking = pendingBookings[index];
                                return Column(
                                  children: [
                                    BookingRequestCard(
                                      room: booking['room_name'],
                                      time: booking['time_range'],
                                      name:
                                          "Booked by User ID: ${booking['user_id_booked']}",
                                      id: booking['booking_id'].toString(),
                                      imageUrl:
                                          'assets/images/${booking['image_url']}', // Local image URL
                                      onApprove: () => handleDecision(
                                          booking['booking_id'].toString(),
                                          'approved'),
                                      onReject: () => handleDecision(
                                          booking['booking_id'].toString(),
                                          'rejected'),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                );
                              },
                            ),
                          ),
          ],
        ),
      ),
    );
  }
}

// Custom Card widget to display booking request details
class BookingRequestCard extends StatelessWidget {
  final String room;
  final String time;
  final String name;
  final String id;
  final String imageUrl;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const BookingRequestCard({
    super.key,
    required this.room,
    required this.time,
    required this.name,
    required this.id,
    required this.imageUrl,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color.fromRGBO(236, 230, 240, 1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    imageUrl, // Local image URL
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.image,
                      size: 100,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB948),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          time,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(name, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text("Booking ID: $id",
                          style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF58B400),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Approve'),
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
