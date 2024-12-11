import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_app_project/Dashboard.dart';
import 'package:mobile_app_project/Lecturer%20Role/lect_ViewPendingReq.dart';
import 'package:mobile_app_project/Lecturer%20Role/lect_browse_room_list.dart';
import 'package:mobile_app_project/Lecturer%20Role/lect_history.dart';
import 'package:mobile_app_project/logout.dart';
import 'package:motion_toast/motion_toast.dart';

class LectHomeScreen extends StatefulWidget {
  final String accessToken; // Add this line to pass the token

  const LectHomeScreen(
      {super.key, required this.accessToken}); // Make accessToken required

  @override
  State<LectHomeScreen> createState() => _LectHomeScreenState();
}

class _LectHomeScreenState extends State<LectHomeScreen> {
  int _selectedIndex = 0; // Default to home

  final List<String> _toastQueue = []; // Queue to store messages
  bool _isToastShowing = false; // Flag to check if a toast is currently showing

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
          userRole: 'approver',
        ),
      ),
    );
  }

  // Method to add messages to the queue
  void addToastMessage(String message) {
    _toastQueue.add(message);
    if (!_isToastShowing) {
      _showNextToast();
    }
  }

  // Method to show the next toast in the queue
  void _showNextToast() {
    if (_toastQueue.isEmpty) return;

    setState(() {
      _isToastShowing = true;
    });

    final message = _toastQueue.removeAt(0);

    // MotionToast.info(
    //   title: const Text("Notification"),
    //   description: Text(message),
    //   animationDuration: const Duration(milliseconds: 500),
    // ).show(context);

    // Reset the flag once the toast has been shown
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isToastShowing = false;
      });

      // Show the next toast in the queue
      _showNextToast();
    });
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
              onTap: _onLogoutTapped, // Call the Logout function on tap
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
          LectBrowseRoomList(
            role: 'approver',
            accessToken: widget.accessToken,
          ), // Home tab shows the LectBrowseRoomList Room Booking tab points to the BookingRequestsPage
          const BookingRequestsPage(), // Booking Status tab points to the BookingRequestsPage
          LectHistory(role: 'approver'),
          DashboardScreen(
              role: 'approver'), // History tab points to the LectHistory
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
                Text('Booking'),
                Text('Room'),
              ],
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today),
                SizedBox(height: 4),
                Text('Booking'),
                Text('Status'),
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
          BottomNavigationBarItem(
            icon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.dashboard),
                SizedBox(height: 4),
                Text('Dashboard'),
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
