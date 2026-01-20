import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import 'study_screen.dart';
import 'day_screen.dart';
import 'quiz_screen.dart';
import 'calendar_screen.dart'; // Added import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentDay = 1;
  int _tokens = 0;
  bool _isLoading = true;

  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh stats when returning to screen (but not on first build)
    if (_hasLoadedOnce && !_isLoading && mounted) {
      _loadStats();
    }
    _hasLoadedOnce = true;
  }

  Future<void> _loadStats() async {
    final stats = await DatabaseHelper.instance.getUserStats();
    setState(() {
      _currentDay = stats['current_day'];
      _tokens = stats['tokens'];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEFF3FF), // Light indigo
            Color(0xFFF5F8FF),
            Color(0xFFFAFAFC),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        title: const Text('Zhyar Spelling'),
        centerTitle: true,
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    _buildStatsCard(),
                    const SizedBox(height: 30),
                    _buildMenuButton(
                      context,
                      icon: Icons.play_circle_outline,
                      title: 'Start Stage $_currentDay',
                      subtitle: 'Current Lesson',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DayScreen(day: _currentDay),
                          ),
                        );
                        _loadStats();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildMenuButton(
                      context,
                      icon: Icons.explore,
                      title: 'My Journey',
                      subtitle: 'View all stages',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CalendarScreen(),
                          ),
                        );
                        _loadStats();
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_currentDay > 1) ...[
                      _buildMenuButton(
                        context,
                        icon: Icons.emoji_events,
                        title: 'Ultimate Challenge',
                        subtitle: 'Test all stages',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizScreen(
                                mode: QuizMode.ultimate,
                                maxDay: _currentDay,
                              ),
                            ),
                          );
                          _loadStats();
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildMenuButton(
                      context,
                      icon: Icons.menu_book,
                      title: 'Word Library',
                      subtitle: 'Browse all words',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const StudyScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.explore, color: Colors.white70, size: 24),
                const SizedBox(height: 8),
                const Text(
                  'Current Stage',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_currentDay',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 60, width: 2, color: Colors.white30),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.stars, color: Colors.white70, size: 28),
                const SizedBox(height: 8),
                const Text(
                  'Tokens',
                  style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_tokens',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 320,
      height: 100,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}