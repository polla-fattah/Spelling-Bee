import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word.dart';
import '../services/db_helper.dart';

enum QuizMode { step, reinforcement, ultimate }

class QuizScreen extends StatefulWidget {
  final QuizMode mode;
  final int? targetGrade;
  final int? targetStep;
  final int? maxGrade;

  const QuizScreen({
    super.key, 
    this.mode = QuizMode.step, 
    this.targetGrade, 
    this.targetStep, 
    this.maxGrade
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<List<Word>> _quizWordsFuture;
  List<Word> _quizWords = [];
  int _currentIndex = 0;
  int _score = 0;
  
  List<String> _shuffledLetters = [];
  List<String> _selectedLetters = [];
  List<String> _targetLetters = [];
  List<bool> _letterUsed = []; 
  
  bool _isAnswered = false;
  bool _isCorrect = false;
  String _feedbackMessage = '';
  bool _isHintVisible = false;
  
  bool _isSpellingQuestion = true;
  List<String> _mcOptions = [];
  int _tokens = 0;
  bool _isAudioMode = false; 
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadTokens();
    _quizWordsFuture = _loadWords();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.4); 
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadTokens() async {
    final stats = await DatabaseHelper.instance.getUserStats();
    if (mounted) {
      setState(() {
        _tokens = stats['tokens'] ?? 0;
      });
    }
  }

  Future<List<Word>> _loadWords() async {
    List<Word> words = [];
    if (widget.mode == QuizMode.step && widget.targetGrade != null && widget.targetStep != null) {
      words = await DatabaseHelper.instance.getWordsForStep(widget.targetGrade!, widget.targetStep!);
    } else if (widget.mode == QuizMode.reinforcement && widget.targetGrade != null && widget.targetStep != null) {
      words = await DatabaseHelper.instance.getWordsForStep(widget.targetGrade!, widget.targetStep!);
    } else {
      words = await DatabaseHelper.instance.getRandomWords(10);
    }

    words.shuffle();
    
    setState(() {
      _quizWords = words;
      _prepareQuestion(0);
    });
    return words;
  }

  void _prepareQuestion(int index) {
    if (index >= _quizWords.length) return;
    
    _isSpellingQuestion = true; 
    final currentWord = _quizWords[index];
    _isAudioMode = Random().nextBool();
    
    _targetLetters = currentWord.english.toUpperCase().split('');
    _shuffledLetters = List.from(_targetLetters)..shuffle();
    _selectedLetters = [];
    _letterUsed = List.filled(_shuffledLetters.length, false);
    
    _isAnswered = false;
    _feedbackMessage = '';
    _isHintVisible = false;
    
    if (_isAudioMode) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _speakWord(currentWord.english);
      });
    }
  }

  Future<void> _speakWord(String word) async {
    await _flutterTts.speak(word);
  }

  void _onLetterTap(String letter, int index) {
    if (_isAnswered || _letterUsed[index]) return;
    
    setState(() {
      _selectedLetters.add(letter);
      _letterUsed[index] = true; 
    });

    if (_selectedLetters.length == _targetLetters.length) {
       _checkSpelling();
    }
  }

  void _onSlotTap(int slotIndex) {
    if (_isAnswered || slotIndex >= _selectedLetters.length) return;
    
    setState(() {
      String letter = _selectedLetters[slotIndex];
      _selectedLetters.removeAt(slotIndex);
      
      for (int i = 0; i < _shuffledLetters.length; i++) {
        if (_shuffledLetters[i] == letter && _letterUsed[i]) {
          _letterUsed[i] = false;
          break;
        }
      }
    });
  }

  void _resetCurrentQuestion() {
    setState(() {
      _selectedLetters.clear();
      _letterUsed = List.filled(_shuffledLetters.length, false); 
      _feedbackMessage = '';
      _isCorrect = false;
      _isAnswered = false;
    });
  }

  void _checkSpelling() {
    final input = _selectedLetters.join('');
    final correct = _targetLetters.join('');
    
    if (input == correct) {
      _handleCorrect();
    } else {
      setState(() {
        _feedbackMessage = 'Incorrect! Try Reset?';
        _isCorrect = false;
      });
    }
  }

  void _handleCorrect() {
    setState(() {
      _isAnswered = true;
      _isCorrect = true;
      _score++;
      _feedbackMessage = 'Correct!';
    });
    Future.delayed(const Duration(seconds: 1), _nextQuestion);
  }

  void _nextQuestion() {
    if (_currentIndex < _quizWords.length - 1) {
      setState(() {
        _currentIndex++;
        _prepareQuestion(_currentIndex);
      });
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    int tokensEarned = 0;
    bool isWin = _score >= (_quizWords.length * 0.7);
    
    if (isWin) {
      if (widget.mode == QuizMode.step) {
        tokensEarned = 10;
        await DatabaseHelper.instance.advanceStep(widget.targetGrade!, widget.targetStep!);
      } else if (widget.mode == QuizMode.reinforcement) {
        tokensEarned = 5;
      } else if (widget.mode == QuizMode.ultimate) {
        tokensEarned = 50;
      }
      await DatabaseHelper.instance.updateTokens(tokensEarned);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isWin ? Icons.emoji_events : Icons.psychology,
              color: isWin ? const Color(0xFFF59E0B) : const Color(0xFF6366F1),
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(isWin ? 'Quiz Complete!' : 'Keep Practicing!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You scored $_score out of ${_quizWords.length}',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (tokensEarned > 0)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stars, color: Color(0xFFF59E0B), size: 32),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        const Text(
                          'You earned',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '+$tokensEarned tokens',
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context); 
            },
            child: const Text('Back to Menu'),
          ),
        ],
      ),
    );
  }

  Future<void> _useHint() async {
    if (_isAnswered || _tokens <= 0) return;
    if (_selectedLetters.length >= _targetLetters.length) return;
    
    await DatabaseHelper.instance.updateTokens(-1);
    setState(() {
      _tokens--;
    });
    
    int nextIndex = _selectedLetters.length;
    String neededChar = _targetLetters[nextIndex];
    
    for (int i = 0; i < _shuffledLetters.length; i++) {
      if (_shuffledLetters[i] == neededChar && !_letterUsed[i]) {
        _onLetterTap(neededChar, i);
        return;
      }
    }
    
    await DatabaseHelper.instance.updateTokens(1);
    setState(() {
      _tokens++;
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
            Color(0xFFEEF3FF), 
            Color(0xFFF6F8FF),
            Color(0xFFFAFAFC),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '$_tokens',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_isAnswered)
            IconButton(
              icon: const Icon(Icons.lightbulb_outline, color: Colors.white), 
              onPressed: _tokens > 0 ? _useHint : null,
            ),
        ],
      ),
      body: FutureBuilder<List<Word>>(
        future: _quizWordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_quizWords.isEmpty) {
             return const Center(child: Text('No words found!'));
          }

          final word = _quizWords[_currentIndex];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / _quizWords.length,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Question ${_currentIndex + 1}/${_quizWords.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                
                if (!_isAnswered && word.hint.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      if (!_isHintVisible) {
                        setState(() {
                          _isHintVisible = true;
                        });
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isHintVisible ? const Color(0xFFFEF3C7) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isHintVisible ? const Color(0xFFF59E0B) : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isHintVisible ? Icons.lightbulb : Icons.lightbulb_outline,
                            color: _isHintVisible ? const Color(0xFFF59E0B) : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isHintVisible ? word.hint : 'Tap to show hint',
                              style: TextStyle(
                                fontSize: 15,
                                color: _isHintVisible ? const Color(0xFF92400E) : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 10),
                _buildSpellingLayout(word, _isAudioMode),

                if (_feedbackMessage.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    _feedbackMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isCorrect ? Colors.green : Colors.red,
                    ),
                  ),
                  if (!_isCorrect)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: _resetCurrentQuestion,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Clear & Retry"),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (widget.mode) {
      case QuizMode.step: return 'Step Quiz';
      case QuizMode.reinforcement: return 'Review';
      case QuizMode.ultimate: return 'Ultimate Challenge';
    }
  }

  Widget _buildSpellingLayout(Word word, bool isAudio) {
    return Column(
      children: [
         Text(
           isAudio ? 'Listen and Spell:' : 'Build the English Word:',
           style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
         ),
         const SizedBox(height: 10),
         Container(
           padding: const EdgeInsets.all(20),
           decoration: BoxDecoration(
             gradient: const LinearGradient(
               colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
               begin: Alignment.topLeft,
               end: Alignment.bottomRight,
             ),
             borderRadius: BorderRadius.circular(20),
           ),
           child: Column(
             children: [
               Container(
                 decoration: BoxDecoration(
                   color: Colors.white.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: IconButton(
                   onPressed: () => _speakWord(word.english),
                   icon: const Icon(Icons.volume_up_rounded),
                   color: Colors.white,
                   iconSize: 32,
                 ),
               ),
               const SizedBox(height: 16),
               Text(
                 word.kurdishSorani,
                 style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 8),
               Text(
                 word.arabic,
                 style: const TextStyle(fontSize: 22, color: Colors.white70),
                 textAlign: TextAlign.center,
               ),
             ],
           ),
         ),
         const SizedBox(height: 30),
         Wrap(
           alignment: WrapAlignment.center,
           spacing: 8,
           children: List.generate(_targetLetters.length, (index) {
             String char = index < _selectedLetters.length ? _selectedLetters[index] : '';
             return GestureDetector(
               onTap: () => _onSlotTap(index),
               child: Container(
                 width: 40,
                 height: 40,
                 alignment: Alignment.center,
                 decoration: BoxDecoration(
                   border: Border(bottom: BorderSide(width: 2, color: Colors.grey.shade400)),
                 ),
                 child: Text(char, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
               ),
             );
           }),
         ),
         const SizedBox(height: 30),
         Wrap(
           alignment: WrapAlignment.center,
           spacing: 10,
           runSpacing: 10,
           children: List.generate(_shuffledLetters.length, (index) {
             final isUsed = _letterUsed[index];
             return Material(
               elevation: isUsed ? 0 : 2,
               borderRadius: BorderRadius.circular(12),
               child: InkWell(
                 onTap: isUsed ? null : () => _onLetterTap(_shuffledLetters[index], index),
                 child: Container(
                   width: 50,
                   height: 50,
                   decoration: BoxDecoration(
                     color: isUsed ? Colors.grey.shade200 : Colors.white,
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: isUsed ? Colors.grey.shade400 : const Color(0xFF6366F1), width: 2),
                   ),
                   child: Center(
                     child: Text(
                       _shuffledLetters[index],
                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isUsed ? Colors.grey.shade500 : const Color(0xFF6366F1)),
                     ),
                   ),
                 ),
               ),
             );
           }),
         ),
         if (_isAnswered)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text('Answer: ${word.english}', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
            ),
      ],
    );
  }
}
