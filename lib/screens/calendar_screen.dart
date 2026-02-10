import 'dart:async';
import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import 'stage_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  int _currentGrade = 1;
  int _currentStep = 1;
  int? _selectedGrade;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final stats = await DatabaseHelper.instance.getUserStats().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Database timeout'),
      );
      
      if (mounted) {
        setState(() {
          _currentGrade = stats['current_grade'] ?? 1;
          _currentStep = stats['current_step'] ?? 1;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
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
      appBar: AppBar(
        title: Text(_selectedGrade == null ? 'Select Grade' : 'Grade $_selectedGrade Steps'),
        leading: _selectedGrade != null 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _selectedGrade = null),
            )
          : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedGrade == null 
              ? _buildGradeSelection() 
              : _buildStepSelection(),
    );
  }

  Widget _buildGradeSelection() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        int grade = index + 1;
        bool isUnlocked = grade <= _currentGrade;
        return _buildSelectableCard(
          title: 'Grade',
          value: grade,
          isUnlocked: isUnlocked,
          isCurrent: grade == _currentGrade,
          onTap: () {
            if (isUnlocked) {
              setState(() => _selectedGrade = grade);
            }
          },
        );
      },
    );
  }

  Widget _buildStepSelection() {
    return FutureBuilder<int>(
      future: DatabaseHelper.instance.getTotalStepsForGrade(_selectedGrade!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        int totalSteps = snapshot.data!;
        
        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: totalSteps,
          itemBuilder: (context, index) {
            int step = index + 1;
            bool isUnlocked = (_selectedGrade! < _currentGrade) || (_selectedGrade! == _currentGrade && step <= _currentStep);
            bool isCurrent = _selectedGrade! == _currentGrade && step == _currentStep;
            
            return _buildSelectableCard(
              title: 'Step',
              value: step,
              isUnlocked: isUnlocked,
              isCurrent: isCurrent,
              onTap: () {
                if (isUnlocked) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StepScreen(grade: _selectedGrade!, step: step),
                    ),
                  ).then((_) => _loadProgress());
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSelectableCard({
    required String title,
    required int value,
    required bool isUnlocked,
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isUnlocked ? (isCurrent ? const Color(0xFF6366F1) : Colors.white) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent ? const Color(0xFF6366F1) : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              if (isUnlocked) BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isUnlocked)
                const Icon(Icons.lock_outline, color: Colors.grey, size: 24)
              else if (isCurrent)
                const Icon(Icons.play_circle_outline, color: Colors.white, size: 28)
              else
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isCurrent ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? Colors.white : Colors.grey.shade900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
}
