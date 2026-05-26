import 'dart:convert';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const StreakApp());
}

class Habit {
  String name;
  int streak;
  DateTime? lastCompletedDate;

  Habit({
    required this.name,
    this.streak = 0,
    this.lastCompletedDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'streak': streak,
      'lastCompletedDate': lastCompletedDate?.toIso8601String(),
    };
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      name: json['name'] ?? 'Untitled Habit',
      streak: json['streak'] ?? 0,
      lastCompletedDate: json['lastCompletedDate'] != null
          ? DateTime.tryParse(json['lastCompletedDate'])
          : null,
    );
  }
}

class StreakApp extends StatefulWidget {
  const StreakApp({super.key});

  @override
  State<StreakApp> createState() => _StreakAppState();
}

class _StreakAppState extends State<StreakApp> {
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    loadTheme();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      isDarkMode = !isDarkMode;
    });

    await prefs.setBool('isDarkMode', isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Streaks',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.deepOrange,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepOrange,
      ),
      home: HabitHomePage(
        isDarkMode: isDarkMode,
        toggleTheme: toggleTheme,
      ),
    );
  }
}

class HabitHomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const HabitHomePage({
    super.key,
    required this.isDarkMode,
    required this.toggleTheme,
  });

  @override
  State<HabitHomePage> createState() => _HabitHomePageState();
}

class _HabitHomePageState extends State<HabitHomePage> {
  static const int storageVersion = 1;

  List<Habit> habits = [];
  final TextEditingController habitController = TextEditingController();
  late ConfettiController confettiController;

  @override
  void initState() {
    super.initState();
    confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    loadHabits();
  }

  @override
  void dispose() {
    habitController.dispose();
    confettiController.dispose();
    super.dispose();
  }

  DateTime effectiveToday() {
    final now = DateTime.now();

    if (now.hour < 3) {
      final yesterday = now.subtract(const Duration(days: 1));
      return DateTime(yesterday.year, yesterday.month, yesterday.day);
    }

    return DateTime(now.year, now.month, now.day);
  }

  DateTime onlyDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool isSameDate(DateTime d1, DateTime d2) {
    final a = onlyDate(d1);
    final b = onlyDate(d2);

    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool isYesterday(DateTime lastDate, DateTime today) {
    final yesterday = onlyDate(today).subtract(const Duration(days: 1));
    return isSameDate(lastDate, yesterday);
  }

  bool isCompletedToday(Habit habit) {
    if (habit.lastCompletedDate == null) return false;
    return isSameDate(habit.lastCompletedDate!, effectiveToday());
  }

  Future<void> loadHabits() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('storageVersion', storageVersion);

    final habitData = prefs.getString('habits');

    if (habitData == null) {
      setState(() {
        habits = [
          Habit(name: 'Exercise'),
          Habit(name: 'Reading'),
          Habit(name: 'Coding'),
        ];
      });
      saveHabits();
      return;
    }

    try {
      final decodedData = jsonDecode(habitData);

      if (decodedData is List) {
        setState(() {
          habits = decodedData
              .map((item) => Habit.fromJson(item))
              .toList();
        });
      }
    } catch (error) {
      await prefs.remove('habits');

      setState(() {
        habits = [
          Habit(name: 'Exercise'),
          Habit(name: 'Reading'),
          Habit(name: 'Coding'),
        ];
      });

      saveHabits();
    }
  }

  Future<void> saveHabits() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('storageVersion', storageVersion);

    final habitJson = habits.map((habit) => habit.toJson()).toList();

    await prefs.setString('habits', jsonEncode(habitJson));
  }

  void completeHabit(int index) {
    final habit = habits[index];
    final today = effectiveToday();

    if (habit.lastCompletedDate != null &&
        isSameDate(habit.lastCompletedDate!, today)) {
      return;
    }

    setState(() {
      if (habit.lastCompletedDate != null &&
          isYesterday(habit.lastCompletedDate!, today)) {
        habit.streak++;
      } else {
        habit.streak = 1;
      }

      habit.lastCompletedDate = today;
    });

    saveHabits();
    HapticFeedback.mediumImpact();
    confettiController.play();
  }

  void addHabit() {
    final habitName = habitController.text.trim();

    if (habitName.isEmpty) return;

    setState(() {
      habits.add(Habit(name: habitName));
      habitController.clear();
    });

    saveHabits();
    Navigator.pop(context);
  }

  void deleteHabit(int index) {
    final deletedHabit = habits[index];

    setState(() {
      habits.removeAt(index);
    });

    saveHabits();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${deletedHabit.name} deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            setState(() {
              habits.insert(index, deletedHabit);
            });
            saveHabits();
          },
        ),
      ),
    );
  }

  void resetAllHabits() {
    setState(() {
      habits = [
        Habit(name: 'Exercise'),
        Habit(name: 'Reading'),
        Habit(name: 'Coding'),
      ];
    });

    saveHabits();
  }

  void showAddHabitDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Habit'),
          content: TextField(
            controller: habitController,
            decoration: const InputDecoration(
              labelText: 'Habit name',
              hintText: 'Example: Walking',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                habitController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: addHabit,
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  int get bestStreak {
    if (habits.isEmpty) return 0;
    return habits.map((habit) => habit.streak).reduce((a, b) => a > b ? a : b);
  }

  int get completedTodayCount {
    return habits.where((habit) => isCompletedToday(habit)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar.large(
                pinned: true,
                title: const Text('Habit Streaks'),
                actions: [
                  IconButton(
                    onPressed: widget.toggleTheme,
                    icon: Icon(
                      widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    ),
                  ),
                  IconButton(
                    onPressed: resetAllHabits,
                    icon: const Icon(Icons.restart_alt),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: SummaryHeader(
                  bestStreak: bestStreak,
                  completedToday: completedTodayCount,
                  totalHabits: habits.length,
                ),
              ),

              if (habits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(onAddHabit: showAddHabitDialog),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final habit = habits[index];
                      final completed = isCompletedToday(habit);

                      return HabitCard(
                        habit: habit,
                        completed: completed,
                        onComplete: () => completeHabit(index),
                        onDelete: () => deleteHabit(index),
                      );
                    },
                    childCount: habits.length,
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 90),
              ),
            ],
          ),

          ConfettiWidget(
            confettiController: confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 35,
            gravity: 0.25,
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddHabitDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Habit'),
      ),
    );
  }
}

class SummaryHeader extends StatelessWidget {
  final int bestStreak;
  final int completedToday;
  final int totalHabits;

  const SummaryHeader({
    super.key,
    required this.bestStreak,
    required this.completedToday,
    required this.totalHabits,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [
              Colors.deepOrange,
              Colors.orangeAccent,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.local_fire_department,
              color: Colors.white,
              size: 50,
            ),
            const SizedBox(height: 12),
            const Text(
              'Keep your momentum alive',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SummaryBox(
                    title: 'Best Streak',
                    value: '$bestStreak',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryBox(
                    title: 'Done Today',
                    value: '$completedToday/$totalHabits',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryBox extends StatelessWidget {
  final String title;
  final String value;

  const SummaryBox({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class HabitCard extends StatelessWidget {
  final Habit habit;
  final bool completed;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const HabitCard({
    super.key,
    required this.habit,
    required this.completed,
    required this.onComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: completed
                    ? Colors.green.withOpacity(0.15)
                    : Colors.orange.withOpacity(0.15),
                child: Icon(
                  completed ? Icons.check_circle : Icons.local_fire_department,
                  color: completed ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        '${habit.streak} day streak',
                        key: ValueKey<int>(habit.streak),
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: completed ? null : onComplete,
                icon: Icon(
                  completed ? Icons.done : Icons.add_task,
                ),
              ),

              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final VoidCallback onAddHabit;

  const EmptyState({
    super.key,
    required this.onAddHabit,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.track_changes,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            const Text(
              'No habits yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first habit and start building your streak.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAddHabit,
              icon: const Icon(Icons.add),
              label: const Text('Add Habit'),
            ),
          ],
        ),
      ),
    );
  }
}