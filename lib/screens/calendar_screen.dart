import 'dart:async';
import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import 'stage_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  int _currentStage = 1;
  bool _isLoading = true;
  String? _errorMessage;

  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh progress when returning to screen (but not on first build)
    if (_hasLoadedOnce && !_isLoading && mounted) {
      _loadProgress();
    }
    _hasLoadedOnce = true;
  }

  Future<void> _loadProgress() async {
    try {
      final stats = await DatabaseHelper.instance.getUserStats().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Database timeout'),
      );
      
      if (mounted) {
        setState(() {
          _currentStage = stats['current_stage'] ?? 1;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint("Error loading journey: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Could not load map.\n$e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0F4FF), // Very light indigo
              Color(0xFFF5F7FF),
              Color(0xFFFAFAFC),
            ],
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded, size: 24),
            SizedBox(width: 8),
            Text('Learning Journey'),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 50),
                      const SizedBox(height: 10),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _loadProgress();
                        },
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: 20, 
                  itemBuilder: (context, index) {
                    int stage = index + 1;
                    bool isUnlocked = stage <= _currentStage;
                    bool isCurrent = stage == _currentStage;
                    bool isCompleted = stage < _currentStage;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isUnlocked
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => StageScreen(stage: stage),
                                  ),
                                ).then((_) => _loadProgress());
                              }
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: isUnlocked
                                ? (isCurrent 
                                    ? const LinearGradient(
                                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : const LinearGradient(
                                        colors: [Colors.white, Colors.white],
                                      ))
                                : LinearGradient(
                                    colors: [Colors.grey.shade200, Colors.grey.shade300],
                                  ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrent 
                                  ? const Color(0xFF6366F1)
                                  : (isUnlocked ? Colors.grey.shade300 : Colors.grey.shade400),
                              width: 2,
                            ),
                            boxShadow: isUnlocked
                                ? [
                                    BoxShadow(
                                      color: (isCurrent ? const Color(0xFF6366F1) : Colors.black).withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isUnlocked)
                                Icon(Icons.lock_outline, color: Colors.grey.shade600, size: 24)
                              else if (isCompleted)
                                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28)
                              else if (isCurrent)
                                const Icon(Icons.play_circle_outline, color: Colors.white, size: 28),
                              const SizedBox(height: 4),
                              Text(
                                'Stage',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isCurrent ? Colors.white70 : (isUnlocked ? Colors.grey.shade600 : Colors.grey.shade500),
                                ),
                              ),
                              Text(
                                '$stage',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.white : (isUnlocked ? Colors.grey.shade900 : Colors.grey.shade500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
