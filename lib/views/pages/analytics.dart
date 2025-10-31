import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:focus/utils/AppStyles.dart';
// import 'package:intl/intl.dart';

class AnalyticsPage extends StatefulWidget {
  final User user;
  const AnalyticsPage({
    required this.user,
    super.key,
  });

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _selectedPeriod = 'Month'; // Default to month to match bar chart image
  final List<String> _periods = ['Day', 'Week', 'Month', 'Year'];

  Stream<QuerySnapshot> _getStream() {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (_selectedPeriod) {
      case 'Week':
        final daysToSubtract = now.weekday - 1; 
        start = DateTime(now.year, now.month, now.day - daysToSubtract);
        end = DateTime(now.year, now.month, now.day + (7 - now.weekday), 23, 59, 59);
        break;
      case 'Month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59); 
        break;
      case 'Year':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'Day':
      default:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
    }

    return FirebaseFirestore.instance
        .collection('focus_sessions')
        .where('userId', isEqualTo: widget.user.uid)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots();
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 1) return "0s";
    if (totalSeconds < 60) return "$totalSeconds s";
    if (totalSeconds < 3600) return "${(totalSeconds / 60).floor()}m";
    
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    String result = "";
    if (hours > 0) result += "${hours}h ";
    if (minutes > 0) result += "${minutes}m";
    
    return result.trim().isEmpty ? "0m" : result.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPeriodSelector(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor,));
              }
              if (snapshot.hasError) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
                ));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    "No focus sessions recorded for this $_selectedPeriod.",
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                );
              }

              // --- DATA PROCESSING ---
              final sessions = snapshot.data!.docs;
              int totalDuration = 0, sessionCount = sessions.length, highestDuration = 0, lowestDuration = 0;
              int morningDuration = 0, morningCount = 0;
              int afternoonDuration = 0, afternoonCount = 0;
              int nightDuration = 0, nightCount = 0;

              if (sessions.isNotEmpty) {
                final firstDuration = (sessions.first.data() as Map<String, dynamic>)['durationInSeconds'] as int;
                highestDuration = firstDuration;
                lowestDuration = firstDuration;
              }

              for (var session in sessions) {
                final data = session.data() as Map<String, dynamic>;
                final duration = data['durationInSeconds'] as int;
                totalDuration += duration;
                if (duration > highestDuration) highestDuration = duration;
                if (duration < lowestDuration) lowestDuration = duration;

                final startTime = (data['startTime'] as Timestamp).toDate();
                final hour = startTime.hour;
                if (hour >= 5 && hour < 12) { morningDuration += duration; morningCount++; }
                else if (hour >= 12 && hour < 17) { afternoonDuration += duration; afternoonCount++; }
                else { nightDuration += duration; nightCount++; }
              }

              final averageDuration = sessionCount > 0 ? totalDuration ~/ sessionCount : 0;
              final avgMorning = morningCount > 0 ? morningDuration ~/ morningCount : 0;
              final avgAfternoon = afternoonCount > 0 ? afternoonDuration ~/ afternoonCount : 0;
              final avgNight = nightCount > 0 ? nightDuration ~/ nightCount : 0;

              // --- UI BUILD ---
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                children: [
                  _buildBarChart(sessions, totalDuration),
                  const SizedBox(height: 24),
                  _buildCircularAnalyticsRow(totalDuration, sessionCount, highestDuration, lowestDuration, averageDuration),
                  const SizedBox(height: 24),
                  const Divider(thickness: 1, indent: 16, endIndent: 16, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: FittedBox(child: Text("Focus by Time of Day", style: AppTextStyles.heading, textAlign: TextAlign.center)),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        _buildTimeOfDayCard(title: "Morning Average", value: _formatDuration(avgMorning), icon: Icons.wb_sunny_outlined, color: Colors.orangeAccent),
                        const SizedBox(height: 12),
                        _buildTimeOfDayCard(title: "Afternoon Average", value: _formatDuration(avgAfternoon), icon: Icons.brightness_5_outlined, color: Colors.blueAccent),
                        const SizedBox(height: 12),
                        _buildTimeOfDayCard(title: "Night Average", value: _formatDuration(avgNight), icon: Icons.nights_stay_outlined, color: Colors.deepPurpleAccent),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: AppColors.primaryColor, // Dark green color from image
        borderRadius: BorderRadius.circular(25.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _periods.map((period) {
          bool isSelected = _selectedPeriod == period;
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = period),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Text(
                period,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBarChart(List<QueryDocumentSnapshot> sessions, int totalDuration) {

    Map<int, int> dataMap = {};
    int maxVal = 0;
    String Function(int) labelBuilder = (i) => '';
    int labelStep = 1;

    final now = DateTime.now();

    switch(_selectedPeriod) {
      case 'Day':
        dataMap = { for(int i=0; i<24; i++) i: 0 };
        for (var session in sessions) {
          final hour = (session.data() as Map<String, dynamic>)['startTime'].toDate().hour;
          dataMap[hour] = (dataMap[hour] ?? 0) + (session.data() as Map<String, dynamic>)['durationInSeconds'] as int;
        }
        labelBuilder = (i) => '$i';
        labelStep = 3;
        break;
      case 'Week':
        dataMap = { for(int i=1; i<=7; i++) i: 0 };
        const weekLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        for (var session in sessions) {
          final weekday = (session.data() as Map<String, dynamic>)['startTime'].toDate().weekday;
          dataMap[weekday] = (dataMap[weekday] ?? 0) + (session.data() as Map<String, dynamic>)['durationInSeconds'] as int;
        }
        labelBuilder = (i) => weekLabels[i-1];
        labelStep = 1;
        break;
      case 'Month':
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        dataMap = { for(int i=1; i<=daysInMonth; i++) i: 0 };
        for (var session in sessions) {
          final day = (session.data() as Map<String, dynamic>)['startTime'].toDate().day;
          dataMap[day] = (dataMap[day] ?? 0) + (session.data() as Map<String, dynamic>)['durationInSeconds'] as int;
        }
        labelBuilder = (i) => '$i';
        labelStep = 5;
        break;
      case 'Year':
        dataMap = { for(int i=1; i<=12; i++) i: 0 };
        const monthLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
        for (var session in sessions) {
          final month = (session.data() as Map<String, dynamic>)['startTime'].toDate().month;
          dataMap[month] = (dataMap[month] ?? 0) + (session.data() as Map<String, dynamic>)['durationInSeconds'] as int;
        }
        labelBuilder = (i) => monthLabels[i-1];
        labelStep = 1;
        break;
    }
    maxVal = dataMap.values.isEmpty ? 1 : dataMap.values.reduce(max);
    if (maxVal == 0) maxVal = 1; // Avoid division by zero

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Focused Time Distribution", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text("Total focused time: ${_formatDuration(totalDuration)}", style: const TextStyle(color: Colors.black, fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: dataMap.entries.map((entry) {
                  final double barHeight = (entry.value / maxVal) * 120;
                  bool showLabel = entry.key % labelStep == 0 || labelStep == 1;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 4,
                        height: barHeight,
                        color: AppColors.primaryColor,
                      ),
                      const SizedBox(height: 4),
                      if(showLabel) Text(labelBuilder(entry.key), style: const TextStyle(fontSize: 10, color: Colors.black))
                      else const SizedBox(height: 14) // to align baselines
                    ],
                  );
                }).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCircularAnalyticsRow(int totalDuration, int sessionCount, int highest, int lowest, int average) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _buildCircularCard("Total Time", _formatDuration(totalDuration), Colors.white),
          _buildCircularCard("Sessions", sessionCount.toString(), Colors.white),
          _buildCircularCard("Longest", _formatDuration(highest), Colors.white),
          _buildCircularCard("Shortest", _formatDuration(lowest), Colors.white),
          _buildCircularCard("Average", _formatDuration(average), Colors.white),
        ],
      ),
    );
  }

  Widget _buildCircularCard(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          Container(
            height: 90, width: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
            ),
            child: Center(
              child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildTimeOfDayCard({required String title, required String value, required IconData icon, required Color color}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 5)),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textColor))),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
