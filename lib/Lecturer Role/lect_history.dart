import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:motion_toast/motion_toast.dart';
import 'package:mobile_app_project/config.dart'; // Import the config file

enum RoomApprovalStatus { approved, rejected, pending }

class LectHistory extends StatefulWidget {
  final String role; // Declare role parameter
  const LectHistory({super.key, required this.role});

  @override
  _LectHistoryState createState() => _LectHistoryState();
}

class _LectHistoryState extends State<LectHistory> {
  bool isWaiting = false;
  DateTime? _selectedDate; // Store the selected date
  List<dynamic> bookings = [];
  late Timer _timer; // Timer for polling

// Filter bookings based on the selected date
  List<dynamic> getFilteredBookings() {
    if (_selectedDate == null) return bookings;

    // Filter bookings by the selected date
    return bookings.where((booking) {
      String bookingDateStr = booking['bookingDate']; // the date string
      DateTime bookingDate;

      try {
        // Try parsing as ISO format (yyyy-MM-dd)
        bookingDate = DateTime.parse(bookingDateStr);
      } catch (e) {
        // If parsing fails, try parsing in a custom format (MM/dd/yyyy)
        try {
          bookingDate = DateFormat('MM/dd/yyyy').parse(bookingDateStr);
        } catch (e) {
          // If both fail, use a default date (like current date) or handle the error
          // print('Invalid date format: $bookingDateStr');
          return false; // Skip this booking
        }
      }

      return _selectedDate!.year == bookingDate.year &&
          _selectedDate!.month == bookingDate.month &&
          _selectedDate!.day == bookingDate.day;
    }).toList();
  }

  Future<void> fetchBookingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('token');

    if (accessToken == null) {
      // print('Access token is not available');

      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/bookings/History'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['bookings'] != null && data['bookings'].isNotEmpty) {
          setState(() {
            bookings = data['bookings'];
          });
        } else {
          MotionToast.info(
            title: const Text("No Bookings"),
            description: const Text("No booking history found."),
          ).show(context);
        }
      } else {}
    } catch (error) {}
  }

  void _clearFilter() {
    setState(() {
      _selectedDate = null; // Clear the selected date
    });
  }

  @override
  void initState() {
    super.initState();
    fetchBookingHistory(); // Fetch bookings on initial load
    _startPolling(); // Start polling
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when widget is disposed
    super.dispose();
  }

  void _startPolling() {
    // Poll every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      fetchBookingHistory();
    });
  }

  Color _getApprovalColor(RoomApprovalStatus status) {
    switch (status) {
      case RoomApprovalStatus.approved:
        return const Color(0xFF4DC591);
      case RoomApprovalStatus.rejected:
        return const Color(0xFFFF0000);
      case RoomApprovalStatus.pending:
        return const Color(0xFFFFA500);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Booking History'),
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false, // Removes the back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter by Date Section
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter by Date',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        setState(() {
                          _selectedDate = pickedDate; // Set the selected date
                        });
                      },
                      child: const Text('Select Date'),
                    ),
                    if (_selectedDate != null)
                      GestureDetector(
                        onTap: _clearFilter,
                        child: const Icon(
                          Icons.cancel, // Updated icon
                          color: Color(0xFFFF0000), // Icon color
                          size: 30, // Icon size
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (_selectedDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Selected Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
              ),
            const SizedBox(height: 16),

            // Display loading message or bookings
            isWaiting
                ? const Center(child: CircularProgressIndicator())
                : getFilteredBookings().isEmpty
                    ? const Center(child: Text("No bookings found"))
                    : Expanded(
                        child: ListView.builder(
                          itemCount: getFilteredBookings().length,
                          itemBuilder: (context, index) {
                            var booking = getFilteredBookings()[index];
                            return _buildRoomCard(
                              booking['roomName'] ?? 'Unknown Room',
                              RoomApprovalStatus.values.firstWhere(
                                (e) =>
                                    e.toString() ==
                                    'RoomApprovalStatus.${booking['status'] ?? 'pending'}',
                                orElse: () => RoomApprovalStatus.pending,
                              ),
                              booking['decisionMakerName'] ?? 'Unknown',
                              booking['bookingDate'] ?? 'N/A',
                              booking['bookingTime'] ?? 'N/A',
                              booking['capacity'] ?? 'N/A',
                              booking['wifi'] ?? 'No Wifi',
                              booking['imageUrl'] ?? 'No pic',
                              booking['bookedByName'] ?? '',
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(
    String roomName,
    RoomApprovalStatus status,
    String decisionMakerName,
    String bookingDate,
    String bookingTime,
    String capacity, // Capacity should be passed
    String wifi, // Wifi availability should be passed
    String imageUrl,
    String bookedByName,
  ) {
    return Card(
      color: const Color(0xFFECE6F0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              width: 90,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
                image: DecorationImage(
                  image: AssetImage('assets/images/$imageUrl'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(roomName,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(capacity,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.wifi, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(wifi,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getApprovalColor(
                          status), // This applies the color based on status
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status == RoomApprovalStatus.approved
                          ? 'Approved by $decisionMakerName'
                          : status == RoomApprovalStatus.rejected
                              ? 'Rejected by $decisionMakerName'
                              : 'Pending Approval',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Booking Date',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('Booking Time',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(bookingDate,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      Text(bookingTime,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(6),

                    decoration: BoxDecoration(
                      // This applies the color based on status
                      borderRadius: BorderRadius.circular(4),
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),

                    // ignore: prefer_const_constructors
                    child: Text(
                      'Booking by $bookedByName',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
