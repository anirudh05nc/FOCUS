import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:focus/views/pages/analytics.dart';
import 'package:focus/views/pages/dashboard.dart';
import 'package:focus/views/pages/personal_dashboard.dart';
import 'package:focus/views/pages/tasks_page.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/AppStyles.dart';

class WidgetTree extends StatefulWidget {
  final User user;
  const WidgetTree({
    super.key,
    required this.user,
  });

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {

  int  _selectedPage = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request multiple permissions at once
    await [
      Permission.notification,
      // Permission.storage,
    ].request();
  }

  void _onPageSelected(int value){
    setState(() {
      _selectedPage = value;
    });
    Navigator.pop(context);
  }

  String _getCurrentPageTitle(){
    switch(_selectedPage){
      case 0:
        return "FOCUS";
      case 1:
        return "PERSONAL DASHBOARD";
      case 2:
        return "ANALYTICS";
      case 3:
        return "TASKS";
      default:
        return "FOCUS";
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      Dashboard(user: widget.user),
      PersonalDashboard(user: widget.user),
      AnalyticsPage(user: widget.user),
      TasksPage(user: widget.user),
    ];

    return Scaffold(
      backgroundColor: AppColors.mainbackground,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.mainbackground,
        title: FittedBox(child: Text(_getCurrentPageTitle(), style: AppTextStyles.heading,)),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.user.uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox();
              }
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final streak = data['currentStreak'] as int? ?? 0;

              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Row(
                  children: [
                    Text('🔥', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 4),
                    Text(
                      streak.toString(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.mainbackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            // Drawer Header with Custom Styling
            DrawerHeader(
              decoration: BoxDecoration(
                color: AppColors.drawerHeaderColor,
                // Optional: Rounded corner inside the header
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.bubble_chart, // Focus-related icon
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  // Use AppTextStyles.heading and adjust color for contrast
                  Text(
                    'Focus Menu',
                    style: AppTextStyles.heading.copyWith(color: Colors.white, fontSize: 24),
                  ),
                  Text(
                    widget.user.email ?? 'Unknown User',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            // Drawer Items
            ListTile(
              leading: const Icon(Icons.home_outlined, color: AppColors.listTileColor),
              title: const Text('Home', style: TextStyle(color: AppColors.listTileColor, fontWeight: FontWeight.w500)),
              onTap: () => _onPageSelected(0), // Switch to Dashboard page
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined, color: AppColors.listTileColor),
              title: const Text('Personal Dashboard', style: TextStyle(color: AppColors.listTileColor, fontWeight: FontWeight.w500)),
              onTap: () => _onPageSelected(1),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.analytics_outlined, color: AppColors.listTileColor),
              title: const Text('Analytics', style: TextStyle(color: AppColors.listTileColor, fontWeight: FontWeight.w500)),
              onTap: () => _onPageSelected(2),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.task_alt_rounded, color: AppColors.listTileColor),
              title: const Text('Tasks', style: TextStyle(color: AppColors.listTileColor, fontWeight: FontWeight.w500)),
              onTap: () => _onPageSelected(3),
            ),
            const Divider(),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  FirebaseAuth.instance.signOut();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white
                ),
                child: const Text("LOGOUT"),
              ),
            )
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedPage,
        children: pages,
      ), // Use the new list here
    );
  }
}
