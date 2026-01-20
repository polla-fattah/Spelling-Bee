import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'quiz_menu_screen.dart';
import 'achievements_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 1; // Default to Quiz (Center)
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;
  Animation<double>? _rotationAnimation;
  
  late AnimationController _positionController;
  late Animation<double> _positionAnimation;

  final List<Widget> _screens = [
    const CalendarScreen(),
    const QuizMenuScreen(),
    const AchievementsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _positionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _positionAnimation = Tween<double>(
      begin: _getPositionForIndex(1),
      end: _getPositionForIndex(1),
    ).animate(CurvedAnimation(
      parent: _positionController,
      curve: Curves.easeInOutCubic,
    ));
  }

  void _initAnimations() {
    _animationController?.dispose();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeOutCubic,
      ),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOutCubic),
    );
    _animationController!.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _positionController.dispose();
    super.dispose();
  }

  double _getPositionForIndex(int index) {
    switch (index) {
      case 0:
        return 0.15; // Left position
      case 2:
        return 0.85; // Right position
      default:
        return 0.5; // Center position
    }
  }

  void _animateToPosition(int newIndex) {
    _positionAnimation = Tween<double>(
      begin: _positionAnimation.value,
      end: _getPositionForIndex(newIndex),
    ).animate(CurvedAnimation(
      parent: _positionController,
      curve: Curves.easeInOutCubic,
    ));
    
    _positionController.reset();
    _positionController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0.0, 0.02),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: offsetAnimation,
                  child: child,
                ),
              );
            },
            child: IndexedStack(
              key: ValueKey<int>(_currentIndex),
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 6.0,
              color: Colors.transparent,
              elevation: 0,
              height: 65,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (_currentIndex != 0)
                    _buildBarIcon(0, Icons.school_outlined, "Learn")
                  else
                    const SizedBox(width: 40),

                  if (_currentIndex != 1)
                    _buildBarIcon(1, Icons.psychology_outlined, "Practice")
                  else
                    const SizedBox(width: 40),

                  if (_currentIndex != 2)
                    _buildBarIcon(2, Icons.workspace_premium_outlined, "Rewards")
                  else
                    const SizedBox(width: 40),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: AnimatedBuilder(
              animation: _positionAnimation,
              builder: (context, child) {
                return Align(
                  alignment: Alignment(_positionAnimation.value * 2 - 1, 1),
                  child: _buildFab(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFab() {
    if (_animationController == null) {
      _initAnimations();
    }

    IconData icon;
    Color fabColor;
    switch (_currentIndex) {
      case 0:
        icon = Icons.school_rounded;
        fabColor = const Color(0xFF6366F1); // Indigo
        break;
      case 2:
        icon = Icons.workspace_premium_rounded;
        fabColor = const Color(0xFF6366F1); // Indigo
        break;
      default:
        icon = Icons.psychology_rounded;
        fabColor = const Color(0xFF6366F1); // Indigo
    }

    return AnimatedBuilder(
      animation: _animationController!,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation?.value ?? 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: fabColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: 'main_fab',
              backgroundColor: fabColor,
              elevation: 0,
              onPressed: () {},
              shape: const CircleBorder(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  icon,
                  key: ValueKey<IconData>(icon),
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarIcon(int index, IconData icon, String label) {
    final bool isSelected = _currentIndex == index;
    
    return InkWell(
      onTap: () {
        if (_currentIndex != index) {
          setState(() {
            _currentIndex = index;
            _animateToPosition(index);
            _animationController?.reset();
            _animationController?.forward();
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              tween: Tween(begin: 0.9, end: 1.0),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Icon(
                    icon,
                    color: Colors.grey.shade600,
                    size: 26,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}