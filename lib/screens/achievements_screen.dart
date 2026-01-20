import 'dart:async';
import 'package:flutter/material.dart';
import '../services/db_helper.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  int _currentStage = 1;
  int _tokens = 0;
  bool _isLoading = true;
  String? _errorMessage;

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
    if (_hasLoadedOnce && !_isLoading) {
      _loadStats();
    }
    _hasLoadedOnce = true;
  }

  Future<void> _loadStats() async {
    try {
      // Add a 5-second timeout to prevent infinite loading
      final stats = await DatabaseHelper.instance.getUserStats().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Database took too long to respond.');
        },
      );
      
      if (mounted) {
        setState(() {
          _currentStage = stats['current_stage'] ?? 1;
          _tokens = stats['tokens'] ?? 0;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint("Error loading achievements: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Could not load data.\n(Error: $e)";
        });
      }
    }
  }

  Future<void> _handleReset() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await DatabaseHelper.instance.resetDatabase();
      await _loadStats(); // Reload after reset
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Reset failed: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0F4FF), // Very light indigo
            Color(0xFFF8F9FF),
            Color(0xFFFAFAFC),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded, size: 24),
            SizedBox(width: 8),
            Text('Rewards'),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 60),
                        const SizedBox(height: 20),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });
                            _loadStats();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _handleReset,
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Reset Data (Fixes Stuck Loading)'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.stars, size: 56, color: Colors.white),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Total Tokens',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$_tokens',
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildStatCard(
                        icon: Icons.school_rounded,
                        title: 'Current Stage',
                        value: 'Stage $_currentStage',
                        color: const Color(0xFF6366F1),
                      ),
                      const SizedBox(height: 16),
                      _buildStatCard(
                        icon: Icons.check_circle_rounded,
                        title: 'Completed Stages',
                        value: '${_currentStage - 1} / 20',
                        color: const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}