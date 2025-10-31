import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:focus/utils/AppStyles.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

// A data class to hold the details for each focus persona.
class FocusPersona {
  final String title;
  final String description;
  final String lottieAsset;
  final Color color;

  FocusPersona({
    required this.title,
    required this.description,
    required this.lottieAsset,
    required this.color,
  });
}

class FocusSuggestion {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  FocusSuggestion({required this.title, required this.description, required this.icon, required this.color});
}

class PersonalDashboard extends StatefulWidget {
  final User user;
  const PersonalDashboard({
    super.key,
    required this.user,
  });

  @override
  State<PersonalDashboard> createState() => _PersonalDashboardState();
}

class _PersonalDashboardState extends State<PersonalDashboard> {

  // Determines the user's persona based on their focus habits.
  FocusPersona? _getFocusPersona(int avgMorning, int avgAfternoon, int avgNight) {
    if (avgMorning == 0 && avgAfternoon == 0 && avgNight == 0) {
      return null; // Not enough data to determine a persona.
    }

    if (avgMorning >= avgAfternoon && avgMorning >= avgNight) {
      return FocusPersona(
        title: "Early Bird",
        description: "You're most productive in the morning. Try tackling your most important tasks before noon to take advantage of your peak focus time!",
        lottieAsset: "assets/lotties/earlybird.json",
        color: Colors.orangeAccent,
      );
    } else if (avgAfternoon >= avgMorning && avgAfternoon >= avgNight) {
      return FocusPersona(
        title: "Sustained Worker",
        description: "Your focus peaks in the afternoon. Use this time for deep work sessions and power through your to-do list while your energy is high.",
        lottieAsset: "assets/lotties/person.json",
        color: Colors.blueAccent,
      );
    } else {
      return FocusPersona(
        title: "Night Owl",
        description: "You come alive when the sun goes down! Your best focus sessions happen at night. Embrace the quiet and make the most of your late-night productivity.",
        lottieAsset: "assets/lotties/nightowl.json",
        color: Colors.deepPurpleAccent,
      );
    }
  }
  
  FocusSuggestion _getSuggestion(int averageSeconds) {
    final averageMinutes = averageSeconds / 60;

    if (averageMinutes < 30) {
        return FocusSuggestion(
            title: "Keep Going!",
            description: "Your average session is under 30 minutes. Try to build momentum by adding 5-10 minutes to each session this week.",
            icon: Icons.trending_down,
            color: Colors.redAccent,
        );
    } else if (averageMinutes < 60) {
        return FocusSuggestion(
            title: "Solid Foundation!",
            description: "You're consistently focusing for 30-60 minutes. This is great! Challenge yourself with a longer session for your most important task of the day.",
            icon: Icons.trending_up,
            color: Colors.blueAccent,
        );
    } else if (averageMinutes < 300) { // < 5 hours
        return FocusSuggestion(
            title: "In the Zone!",
            description: "You're a focus machine! Your sessions show incredible discipline. Make sure you're taking short breaks to stay fresh.",
            icon: Icons.celebration_rounded,
            color: Colors.green,
        );
    } else { // >= 5 hours
        return FocusSuggestion(
            title: "Productivity Master!",
            description: "Your dedication to deep work is inspiring! Remember that even masters need to rest to maintain their edge.",
            icon: Icons.workspace_premium_rounded,
            color: Colors.deepPurpleAccent,
        );
    }
}

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 60) return "$totalSeconds seconds";
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
        return "$hours ${hours == 1 ? 'hour' : 'hours'}${minutes > 0 ? ' and $minutes ${minutes == 1 ? 'minute' : 'minutes'}' : ''}";
    } else {
        return "$minutes ${minutes == 1 ? 'minute' : 'minutes'}";
    }
}

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.user.uid).snapshots(),
      builder: (context, userSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('focus_sessions')
              .where('userId', isEqualTo: widget.user.uid)
              .snapshots(),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting || userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
            }
            if (sessionSnapshot.hasError || userSnapshot.hasError) {
              return const Center(child: Text("Error loading data", style: TextStyle(color: Colors.red)));
            }
            if (!sessionSnapshot.hasData || sessionSnapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            // --- Persona Data Processing ---
            int morningDuration = 0, morningCount = 0;
            int afternoonDuration = 0, afternoonCount = 0;
            int nightDuration = 0, nightCount = 0;
            int totalDuration = 0;

            for (var session in sessionSnapshot.data!.docs) {
              final data = session.data() as Map<String, dynamic>;
              final duration = data['durationInSeconds'] as int;
              totalDuration += duration;
              final startTime = (data['startTime'] as Timestamp).toDate();
              final hour = startTime.hour;

              if (hour >= 5 && hour < 12) { morningDuration += duration; morningCount++; }
              else if (hour >= 12 && hour < 17) { afternoonDuration += duration; afternoonCount++; }
              else { nightDuration += duration; nightCount++; }
            }
            
            final sessionCount = sessionSnapshot.data!.docs.length;
            final averageFocusSeconds = sessionCount > 0 ? totalDuration ~/ sessionCount : 0;

            final avgMorning = morningCount > 0 ? morningDuration ~/ morningCount : 0;
            final avgAfternoon = afternoonCount > 0 ? afternoonDuration ~/ afternoonCount : 0;
            final avgNight = nightCount > 0 ? nightDuration ~/ nightCount : 0;
            final persona = _getFocusPersona(avgMorning, avgAfternoon, avgNight);

            if (persona == null) {
              return _buildEmptyState();
            }

            // --- UI BUILD ---
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildPersonaCard(persona),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildFocusSuggestionsCard(averageFocusSeconds),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildStreakDetails(userSnapshot.data),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFocusSuggestionsCard(int averageFocusSeconds) {
    if (averageFocusSeconds == 0) return const SizedBox.shrink();

    final suggestion = _getSuggestion(averageFocusSeconds);
    final formattedAverage =_formatDuration(averageFocusSeconds);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(suggestion.icon, color: suggestion.color, size: 32),
                const SizedBox(width: 12),
                Text(
                  suggestion.title,
                  style: AppTextStyles.heading.copyWith(fontSize: 22, color: suggestion.color),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Your average focus session is $formattedAverage.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
            ),
          ],
        ),
      ),
    );
}

  Widget _buildStreakDetails(DocumentSnapshot? userDoc) {
    if (userDoc == null || !userDoc.exists) {
      return const Center(
        child: Text("Start a session to begin your streak!"),
      );
    }

    final data = userDoc.data() as Map<String, dynamic>;
    final currentStreak = data['currentStreak'] as int? ?? 0;
    final highestStreak = data['highestStreak'] as int? ?? 0;
    final streakStartDate = (data['streakStartDate'] as Timestamp?)?.toDate();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your Streak",
              style: AppTextStyles.heading.copyWith(fontSize: 22, color: AppColors.textColor),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              icon: Icons.local_fire_department_rounded,
              title: 'Current Streak',
              value: '$currentStreak days',
              color: Colors.orange,
            ),
            const Divider(height: 24),
            _buildStatRow(
              icon: Icons.star_rounded,
              title: 'Highest Streak',
              value: '$highestStreak days',
              color: Colors.amber,
            ),
            if (streakStartDate != null) ...[
              const Divider(height: 24),
              _buildStatRow(
                icon: Icons.calendar_today_rounded,
                title: 'Streak Started',
                value: DateFormat('MMM d, yyyy').format(streakStartDate),
                color: Colors.blue,
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow({required IconData icon, required String title, required String value, required Color color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // The main card to display the user's focus persona.
  Widget _buildPersonaCard(FocusPersona persona) {
    return Card(
      elevation: 8,
      shadowColor: persona.color.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: Lottie.asset(
              persona.lottieAsset,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Text(
                  persona.title,
                  style: AppTextStyles.heading.copyWith(color: persona.color, fontSize: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  persona.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.textColor, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // A widget to show when there's not enough data.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/lotties/person.json', height: 200),
            const SizedBox(height: 20),
            const Text(
              "Not enough data yet!",
              style: AppTextStyles.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "Complete a few focus sessions, and we'll provide personalized insights here.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
