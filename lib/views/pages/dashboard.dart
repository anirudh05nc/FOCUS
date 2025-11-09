import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import '../../utils/AppStyles.dart';

const MethodChannel platform = MethodChannel('com.example.focus/lock_mode');

class Dashboard extends StatefulWidget {
  final User user;
  const Dashboard({super.key, required this.user});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late Timer _timer;
  int _seconds = 0;
  bool _isRunning = false;
  bool _isTurnedOn = false;

  DateTime? _startTime;
  DateTime? _endTime;

  late final Widget _todayTasksList;

  @override
  void initState() {
    super.initState();
    _todayTasksList = _buildTasksList('Scheduled Today', _getTodayTasksStream());
  }

  Stream<QuerySnapshot> _getTodayTasksStream() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return FirebaseFirestore.instance
        .collection('tasks')
        .where('userId', isEqualTo: widget.user.uid)
        .where('isCompleted', isEqualTo: false)
        .where('deadline', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .where('deadline', isLessThanOrEqualTo: Timestamp.fromDate(endOfToday))
        .orderBy('deadline', descending: false)
        .snapshots();
  }

  Future<void> _enableLockMode() async {
    try {
      await platform.invokeMethod('pinApp');
      print('Screen Pinning enabled.');
    } on PlatformException catch (e) {
      print("Failed to enable lock mode: ${e.message}");
    }
  }

  Future<void> _disableLockMode() async {
    try {
      await platform.invokeMethod('unpinApp');
      print('Screen Pinning disabled.');
    } on PlatformException catch (e) {
      print("Failed to disable lock mode: ${e.message}");
    }
  }

  String _formatTime() {
    final Duration duration = Duration(seconds: _seconds);
    final String hours = duration.inHours.toString().padLeft(2, '0');
    final String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  void _startTimer() {
    if (_isRunning) _timer.cancel();

    setState(() {
      _seconds = 0;
      _isRunning = true;
      _startTime = DateTime.now();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  Future<void> _updateStreak() async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(widget.user.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        transaction.set(userRef, {
          'currentStreak': 1,
          'highestStreak': 1,
          'lastSessionDate': Timestamp.now(),
          'streakStartDate': Timestamp.now(),
        });
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final lastSession = (data['lastSessionDate'] as Timestamp).toDate();
      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);
      final lastDay = DateTime(lastSession.year, lastSession.month, lastSession.day);

      if (today.isAtSameMomentAs(lastDay)) return;

      int currentStreak = data['currentStreak'] as int;
      int highestStreak = data['highestStreak'] as int;
      Timestamp streakStartDate = data['streakStartDate'] as Timestamp;

      final yesterday = today.subtract(const Duration(days: 1));

      if (lastDay.isAtSameMomentAs(yesterday)) {
        currentStreak++;
      } else {
        currentStreak = 1;
        streakStartDate = Timestamp.now();
      }

      transaction.update(userRef, {
        'currentStreak': currentStreak,
        'highestStreak': max(currentStreak, highestStreak),
        'lastSessionDate': Timestamp.now(),
        'streakStartDate': streakStartDate,
      });
    });
  }

  void _stopTimer() async {
    if (!_isRunning) return;

    _timer.cancel();
    final endTime = DateTime.now();

    setState(() {
      _isRunning = false;
      _endTime = endTime;
    });

    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Start time was not recorded."), backgroundColor: Colors.red),
      );
      return;
    }

    final durationInSeconds = _endTime!.difference(_startTime!).inSeconds;

    if (durationInSeconds < 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Session is too short and will not be saved."), backgroundColor: Colors.orange),
        );
      }
      setState(() {
        _seconds = 0;
        _startTime = null;
        _endTime = null;
      });
      return;
    }

    try {
      final sessionData = {
        'userId': widget.user.uid,
        'startTime': Timestamp.fromDate(_startTime!),
        'endTime': Timestamp.fromDate(_endTime!),
        'durationInSeconds': durationInSeconds,
      };

      await FirebaseFirestore.instance.collection('focus_sessions').add(sessionData);
      await _updateStreak();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Focus session saved!"), backgroundColor: Colors.green),
        );
      }

      setState(() {
        _seconds = 0;
        _startTime = null;
        _endTime = null;
      });

    } catch (e) {
      print("Error saving session: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save session: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  void _showAddTaskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddTaskSheet(user: widget.user),
      ),
    );
  }

  @override
  void dispose() {
    if (_isRunning) {
      _timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddTaskSheet(context);
        },
        child: const Icon(Icons.add, color: Colors.black,),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.background.withOpacity(0.15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ]
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const SizedBox(height: 50),
                     Text(
                      "Start Focussing NOW!",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const Text("Focus Mode : "),
                        Switch(
                          value: _isTurnedOn,
                          onChanged: (bool value) {
                            setState(() {
                              _isTurnedOn = value;
                            });
                            if(value){
                              _enableLockMode();
                            }else{
                              _disableLockMode();
                            }
                          },
                          activeTrackColor: AppColors.primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    Container(
                      height: 230,
                      width: 230,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryColor, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Lottie.asset(
                              _isRunning
                                  ? 'assets/lotties/focusMode.json'
                                  : 'assets/lotties/loading.json',
                              key: ValueKey<bool>(_isRunning),
                              width: 230,
                              height: 230,
                              fit: BoxFit.cover,
                            ),

                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      _formatTime(),
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 40,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 30),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _isRunning ? null : _startTimer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            "START",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),

                        ElevatedButton(
                          onPressed: _isRunning ? _stopTimer : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            "STOP",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Divider(thickness: 1, color: AppColors.textColor,),
            ),
            _todayTasksList,
            const SizedBox(height: 90,),
          ],
        ),
      ),
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

  Widget _buildTasksList(String title, Stream<QuerySnapshot> stream) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor,));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                "No pending tasks for today!",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        final tasks = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(title, style: AppTextStyles.heading.copyWith(fontSize: 20)),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                final data = task.data() as Map<String, dynamic>;
                final docId = task.id;
                return _buildTaskCard(context, data, docId);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, Map<String, dynamic> data, String docId) {
    final deadline = (data['deadline'] as Timestamp).toDate();
    final formattedDeadline = DateFormat('MMM d, yyyy - hh:mm a').format(deadline);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
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
              onPressed: () => _showCompleteDialog(context, data, docId, deadline),
              splashRadius: 24,
            )
          ],
        ),
      ),
    );
  }

    void _showCompleteDialog(BuildContext context, Map<String, dynamic> taskData, String docId, DateTime deadline) {
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
                  final message = "Task '${taskData['title']}' marked as complete. Status: $status";
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message), backgroundColor: Colors.green),
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

class AddTaskSheet extends StatefulWidget {
  final User user;
  const AddTaskSheet({super.key, required this.user});

  @override
  _AddTaskSheetState createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String _selectedCategory = 'MEDIUM';
  DateTime? _selectedDeadline;
  String? _deadlineErrorText;

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDeadline ?? now.add(const Duration(hours: 1))),
    );

    if (time == null) return;

    final deadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (deadline.isBefore(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot select a past date or time."), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() {
      _selectedDeadline = deadline;
      _deadlineErrorText = null; 
    });
  }

  Future<void> _saveTask() async {
    final isFormValid = _formKey.currentState!.validate();
    
    if (_selectedDeadline == null) {
      setState(() {
        _deadlineErrorText = 'Please select a deadline.';
      });
    }

    if (!isFormValid || _selectedDeadline == null) {
      return;
    }

    try {
      final taskTitle = _titleController.text;
      final taskData = {
        'userId': widget.user.uid,
        'title': taskTitle,
        'category': _selectedCategory,
        'deadline': Timestamp.fromDate(_selectedDeadline!),
        'createdAt': Timestamp.now(),
        'isCompleted': false,
      };

      await FirebaseFirestore.instance.collection('tasks').add(taskData);

      if (mounted) {
        Navigator.pop(context);
        final message = "Task '$taskTitle' added successfully!";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add task: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatDeadline() {
    if (_selectedDeadline == null) return 'No deadline set';
    final d = _selectedDeadline!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Task', style: AppTextStyles.heading),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title of the Task',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(labelText: 'Category',border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),),
              items: ['HIGH', 'MEDIUM', 'LOW'].map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                });
              },
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: _deadlineErrorText == null ? Colors.grey : Colors.red, width: 1.0),
                borderRadius: BorderRadius.circular(25.0)
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _formatDeadline(), 
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickDeadline,
                      child: const Text('SELECT'),
                    ),
                  ],
                ),
              )
            ),
            if (_deadlineErrorText != null)
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                child: Text(
                  _deadlineErrorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _saveTask,
                style: AppButtonStyles.mainButtonStyle,
                child: const Text('SAVE TASK'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
