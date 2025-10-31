import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:focus/utils/AppStyles.dart';
import 'package:intl/intl.dart';


class TasksPage extends StatelessWidget {
  final User user;
  const TasksPage({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tasks').where('userId', isEqualTo: user.uid).orderBy('deadline', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No tasks created yet. Add one from the Home page!",
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          );
        }

        // --- DATA PROCESSING ---
        final allTasks = snapshot.data!.docs;
        final totalTasks = allTasks.length;

        final completedTasks = allTasks.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data.containsKey('isCompleted') && data['isCompleted'] == true;
        }).toList();

        final pendingTasks = allTasks.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return !data.containsKey('isCompleted') || data['isCompleted'] == false;
        }).toList();

        final onTimeTasks = completedTasks.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data.containsKey('completionStatus') && data['completionStatus'] == 'On Time';
        }).length;

        final delayedTasks = completedTasks.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data.containsKey('completionStatus') && data['completionStatus'] == 'Delayed';
        }).length;

        final completionRate = totalTasks > 0 ? (completedTasks.length / totalTasks) : 0.0;

        // --- UI BUILD ---
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(child: const Text("Task Completion Rate", style: AppTextStyles.heading)),
                const SizedBox(height: 30),
                SizedBox(
                  width: 230,
                  height: 230,
                  child: CustomPaint(
                    painter: TaskCompletionPainter(
                      completionRate: completionRate,
                      backgroundColor: Colors.red.shade100,
                      progressColor: Colors.green.shade400,
                    ),
                    child: Center(
                      child: Text(
                        '${(completionRate * 100).toStringAsFixed(0)}%',
                        style: AppTextStyles.heading.copyWith(fontSize: 50, color: AppColors.textColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                _buildStatCard(totalTasks, onTimeTasks, delayedTasks, pendingTasks.length, completedTasks.length),
                const SizedBox(height: 20),
                const Divider(thickness: 1, height: 30, indent: 20, endIndent: 20),
                _buildTaskList(context, 'Total Pending Tasks', pendingTasks),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskList(BuildContext context, String title, List<DocumentSnapshot> tasks) {
    if (tasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("No pending tasks!", style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Text(title, style: AppTextStyles.heading.copyWith(fontSize: 20)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          itemBuilder: (ctx, index) {
            final task = tasks[index];
            final data = task.data() as Map<String, dynamic>;
            return _buildTaskCard(context, data, task.id);
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(int total, int onTime, int delayed, int pending, int completed) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildStatRow(icon: Icons.list_alt, title: 'Total Tasks Created', value: total.toString(), color: AppColors.textColor),
            const Divider(height: 24),
            _buildStatRow(icon: Icons.check_circle, title: 'Tasks Completed', value: completed.toString(), color: Colors.green.shade600),
            const Divider(height: 24),
            _buildStatRow(icon: Icons.timer, title: 'Completed On Time', value: onTime.toString(), color: Colors.blue.shade600),
            const Divider(height: 24),
            _buildStatRow(icon: Icons.warning_amber_rounded, title: 'Completed Late', value: delayed.toString(), color: Colors.orange.shade600),
            const Divider(height: 24),
            _buildStatRow(icon: Icons.pending_actions, title: 'Tasks Pending', value: pending.toString(), color: Colors.red.shade600),
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
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textColor)),
          ],
        ),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'HIGH':
        return Colors.redAccent;
      case 'MEDIUM':
        return Colors.orangeAccent;
      case 'LOW':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTaskCard(BuildContext context, Map<String, dynamic> data, String docId) {
    final deadline = (data['deadline'] as Timestamp).toDate();
    final formattedDeadline = DateFormat('MMM d, yyyy - hh:mm a').format(deadline);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: _getCategoryColor(data['category']), width: 5)),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Due: $formattedDeadline",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                data['category'],
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              ),
              backgroundColor: _getCategoryColor(data['category']),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
              onPressed: () => _showCompleteDialog(context, docId, deadline),
              splashRadius: 24,
            )
          ],
        ),
      ),
    );
  }

  void _showCompleteDialog(BuildContext context, String docId, DateTime deadline) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Move to Completed'),
          content: const Text('Are you sure you want to mark this task as complete?'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Yes', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final now = DateTime.now();
                final String status = now.isAfter(deadline) ? 'Delayed' : 'On Time';

                try {
                  await FirebaseFirestore.instance.collection('tasks').doc(docId).update({
                    'isCompleted': true,
                    'completedAt': Timestamp.fromDate(now),
                    'completionStatus': status,
                  });
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Task completed!"), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to update task: $e"), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class TaskCompletionPainter extends CustomPainter {
  final double completionRate;
  final Color backgroundColor;
  final Color progressColor;

  TaskCompletionPainter({
    required this.completionRate,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;

    final backgroundPaint = Paint()..color = backgroundColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth;

    final progressPaint = Paint()..color = progressColor..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * completionRate;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
