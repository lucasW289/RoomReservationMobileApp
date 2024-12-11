import 'package:flutter/material.dart';
import 'package:motion_toast/motion_toast.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:mobile_app_project/config.dart'; // Import the config file

class StuStatus extends StatefulWidget {
  final String role;
  const StuStatus({super.key, required this.role});

  @override
  State<StuStatus> createState() => _StuStatusState();
}

class _StuStatusState extends State<StuStatus> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;
  List<Map<String, String>> bookings = [];
  late Timer _timer; // Timer for polling

  // Fetch bookings method with MotionToast feedback
  Future<void> fetchBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('token');

    if (accessToken == null) {
      print('Access token is not available');
      // MotionToast.error(
      //   description: Text("Access token is missing!"),
      //   position: MotionToastPosition.bottom,
      //   width: 300,
      // ).show(context);
      return;
    }

    try {
      final jwt = JWT.decode(accessToken);
      final userId = jwt.payload['user_id'];
      final role = jwt.payload['role'];

      print('Decoded User ID: $userId');
      print('Decoded Role: $role');

      final url = Uri.parse('${Config.baseUrl}/bookings/History?today=true');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('Status Code: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('API Response: ${response.body}');

        final data = json.decode(response.body);

        if (data['bookings'] != null && data['bookings'].isNotEmpty) {
          print('Bookings: ${data['bookings']}');
          setState(() {
            bookings = List<Map<String, String>>.from(
              data['bookings'].map((booking) => {
                    'roomName': booking['roomName']?.toString() ?? 'Room 1',
                    'status': booking['status']?.toString() ?? 'Unknown',
                    'decisionMakerName':
                        booking['decisionMakerName']?.toString() ?? 'N/A',
                    'bookingDate': booking['bookingDate']?.toString() ?? 'N/A',
                    'bookingTime': booking['bookingTime']?.toString() ?? 'N/A',
                    'capacity': booking['capacity']?.toString() ?? 'N/A',
                    'wifi': booking['wifi']?.toString() ?? 'N/A',
                    'imageUrl': booking['imageUrl']?.toString() ?? 'room1.png',
                  }),
            );
          });

          // MotionToast.success(
          //   description: Text("Bookings loaded successfully!"),
          //   position: MotionToastPosition.bottom,
          //   width: 300,
          // ).show(context);
        } else {
          print('No bookings available');
          setState(() {
            bookings = [];
          });

          // MotionToast.info(
          //   description: Text("No bookings available for today."),
          //   position: MotionToastPosition.bottom,
          //   width: 300,
          // ).show(context);
        }
      } else {
        print('Failed to load bookings. Status Code: ${response.statusCode}');
        // MotionToast.error(
        //   description: Text("Failed to load bookings."),
        //   position: MotionToastPosition.bottom,
        //   width: 300,
        // ).show(context);
      }
    } catch (error) {
      print('Error fetching bookings: $error');
      // MotionToast.error(
      //   description: Text("Error fetching bookings."),
      //   position: MotionToastPosition.bottom,
      //   width: 300,
      // ).show(context);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchBookings(); // Fetch the bookings when the widget is initialized
    _startPolling(); // Start polling
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when widget is disposed
    super.dispose();
  }

  void _startPolling() {
    // Poll every 15 seconds
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      fetchBookings();
    });
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    String dayOfWeek = DateFormat.EEEE().format(now);
    String monthYear = DateFormat('MMMM yyyy').format(now);

    return Scaffold(
      body: bookings.isEmpty
          ? const Center(
              child: Text(
                'No Booking Today',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Popins-Regular',
                ),
              ),
            )
          : PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        bookings.isNotEmpty ? bookings[0]['roomName']! : '',
                        style: const TextStyle(
                          fontSize: 25,
                          fontFamily: 'Popins-Regular',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: Image.asset(
                          'assets/images/${bookings.isNotEmpty ? bookings[0]['imageUrl']! : ''}',
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people, size: 20),
                          const SizedBox(width: 5),
                          Text(
                            bookings.isNotEmpty
                                ? bookings[0]['capacity']!
                                : 'N/A',
                            style: const TextStyle(
                              fontFamily: 'Popins-Regular',
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.wifi, size: 20),
                          const SizedBox(width: 5),
                          Text(
                            bookings.isNotEmpty ? bookings[0]['wifi']! : 'N/A',
                            style: const TextStyle(
                              fontFamily: 'Popins-Regular',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: bookings.length,
                          itemBuilder: (context, index) {
                            final booking = bookings[index];
                            Color statusColor = const Color(0xFFFFB948);

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 16),
                              color: Colors.white,
                              child: ListTile(
                                title: Row(
                                  children: [
                                    Text(
                                      booking['bookingTime']!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontFamily: 'Popins-Regular',
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      width: 100,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0, vertical: 4.0),
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                        ),
                                        child: Text(
                                          booking['status']!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Popins-Regular',
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
