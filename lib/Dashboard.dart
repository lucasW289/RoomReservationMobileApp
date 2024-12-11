import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motion_toast/motion_toast.dart';
import 'package:mobile_app_project/config.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
  final String role;

  const DashboardScreen({super.key, required this.role});
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 3;
  // State variables for the data fetched from the API
  int totalRooms = 0;
  int totalSlots = 0;
  int freeSlots = 0;
  int pendingSlots = 0;
  int reservedSlots = 0;
  int disabledSlots = 0;
  bool isLoading = false;
  bool isFetching = false; // Prevent overlapping API calls
  Timer? _timer; // Timer for polling
  Timer? _resetTimer; // Timer for reset at midnight
  DateTime? lastResetDate; // Store last reset date

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer if active
    _resetTimer?.cancel(); // Cancel the reset timer if active
    super.dispose();
  }

  // Function to fetch data from the API
  Future<void> fetchData() async {
    if (isFetching) return; // Prevent overlapping calls
    setState(() {
      isFetching = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('token');
    final lastResetString = prefs.getString('lastResetDate');

    DateTime currentDate = DateTime.now();
    DateTime lastReset =
        lastResetString != null ? DateTime.parse(lastResetString) : currentDate;

    // If it's a new day, reset the data
    if (currentDate.day != lastReset.day) {
      _resetData();
      prefs.setString('lastResetDate', currentDate.toIso8601String());
    }

    if (accessToken == null) {
      setState(() {
        isFetching = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/dashboard'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          totalRooms = data['totalRooms'];
          totalSlots = data['totalSlots'];
          freeSlots = data['freeSlots'];
          pendingSlots = data['pendingSlots'];
          reservedSlots = data['reservedSlots'];
          disabledSlots = data['disabledSlots'];
        });
      }
    } catch (error) {
      // Handle error
    } finally {
      setState(() {
        isFetching = false;
      });
    }
  }

  void _resetData() {
    setState(() {
      totalRooms = 0;
      totalSlots = 0;
      freeSlots = 0;
      pendingSlots = 0;
      reservedSlots = 0;
      disabledSlots = 0;
    });
    // Optionally, show a reset notification
    MotionToast.info(
      title: const Text("Data Reset"),
      description: const Text("The dashboard data has been reset."),
    ).show(context);
  }

  @override
  void initState() {
    super.initState();
    _startPolling(); // Start polling
    fetchData(); // Initial data fetch

    // Schedule an auto-reset at midnight
    _scheduleMidnightReset();
  }

  void _scheduleMidnightReset() {
    // Check if it's midnight every minute
    _resetTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      DateTime now = DateTime.now();
      if (now.hour == 0 && now.minute == 0) {
        _resetData();
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTotalCard(
                              count: totalRooms.toString(),
                              label: 'Study Rooms',
                              icon: Icons.meeting_room,
                              backgroundColor: Colors.lightBlue.shade100,
                              iconColor: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTotalCard(
                              count: totalSlots.toString(),
                              label: 'Time Slots',
                              icon: Icons.calendar_today,
                              backgroundColor: Colors.deepPurple.shade100,
                              iconColor: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStatusCard(
                            count: freeSlots.toString(),
                            label: 'Free',
                            backgroundColor: Colors.lightGreen.shade100,
                            textColor: const Color(0xFF4DC591),
                            icon: Icons.check_circle,
                          ),
                          _buildStatusCard(
                            count: pendingSlots.toString(),
                            label: 'Pending',
                            backgroundColor: Colors.orange.shade100,
                            textColor: const Color(0xFFB87333),
                            icon: Icons.access_time,
                          ),
                          _buildStatusCard(
                            count: disabledSlots.toString(),
                            label: 'Disabled',
                            backgroundColor: Colors.grey.shade300,
                            textColor: const Color(0xFF88889D),
                            icon: Icons.block,
                          ),
                          _buildStatusCard(
                            count: reservedSlots.toString(),
                            label: 'Reserved',
                            backgroundColor: Colors.red.shade100,
                            textColor: const Color(0xFFFF0000),
                            icon: Icons.bookmark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          height: 200,
                          padding: const EdgeInsets.all(16),
                          child: _buildPieChart(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTotalCard({
    required String count,
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 23,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required String count,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: textColor,
            size: 23,
          ),
          const SizedBox(height: 10),
          Text(
            count,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            value: freeSlots.toDouble(),
            color: Colors.lightGreen,
            title: 'Free',
            radius: 50,
            titleStyle: const TextStyle(color: Colors.white),
          ),
          PieChartSectionData(
            value: pendingSlots.toDouble(),
            color: Colors.orange,
            title: 'Pending',
            radius: 50,
            titleStyle: const TextStyle(color: Colors.white),
          ),
          PieChartSectionData(
            value: disabledSlots.toDouble(),
            color: Colors.grey,
            title: 'Disabled',
            radius: 50,
            titleStyle: const TextStyle(color: Colors.white),
          ),
          PieChartSectionData(
            value: reservedSlots.toDouble(),
            color: Colors.red,
            title: 'Reserved',
            radius: 50,
            titleStyle: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
