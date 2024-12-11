import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app_project/Student%20Role/stu_browse_room_list.dart';
import 'package:mobile_app_project/Student%20Role/stu_history.dart';
import 'package:mobile_app_project/Student%20Role/stu_status.dart';
import 'package:mobile_app_project/logout.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_app_project/config.dart'; // Import the config file

class StuHomeScreen extends StatefulWidget {
  final String accessToken; // Add this line to pass the token

  const StuHomeScreen(
      {super.key, required this.accessToken}); // Make accessToken required

  @override
  State<StuHomeScreen> createState() => _StuHomeScreenState();
}

class _StuHomeScreenState extends State<StuHomeScreen> {
  int _selectedIndex = 0; // Default to home
  String? bookingStatus;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onLogoutTapped() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const Logout(
                userRole: 'student',
              )),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchCurrentBooking();
  }

  Future<void> _fetchCurrentBooking() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/bookings/currentbook'), // Use global URL
        headers: {
          'Authorization':
              'Bearer ${widget.accessToken}', // Use accessToken here
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          bookingStatus = data['message'];
        });
      } else {
        setState(() {
          bookingStatus = 'No booking found for today.';
        });
      }
    } catch (e) {
      setState(() {
        bookingStatus = 'Failed to fetch booking status.';
      });
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
        automaticallyImplyLeading:
            false, // Prevents the back button from appearing
        title: Row(
          children: [
            Text(
              dayOfMonth,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayOfWeek,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  monthYear,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: InkWell(
              onTap: _onLogoutTapped,
              child: const CircleAvatar(
                backgroundColor: Colors.black,
                child: Icon(Icons.person, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          StuBrowseRoomList(
            role: 'student',
            accessToken: widget.accessToken, // Pass accessToken here
          ),
          StuStatus(role: 'student'),
          StuHistory(role: 'student'),
          Center(
            child: bookingStatus == null
                ? const CircularProgressIndicator()
                : Text(
                    bookingStatus!,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home),
                SizedBox(height: 4),
                Text('Booking Room'),
              ],
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_added),
                SizedBox(height: 4),
                Text('Booking Status'),
              ],
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history),
                SizedBox(height: 4),
                Text('History'),
              ],
            ),
            label: '',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
