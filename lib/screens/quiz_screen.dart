import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word.dart';
import '../services/db_helper.dart';

enum QuizMode { stage, reinforcement, ultimate }

class QuizScreen extends StatefulWidget {
  final QuizMode mode;
  final int? targetStage;
  final int? maxStage;

  const QuizScreen({super.key, this.mode = QuizMode.stage, this.targetStage, this.maxStage});

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
  List<bool> _letterUsed = []; // Track which letters are used
  
  bool _isAnswered = false;
  bool _isCorrect = false;
  String _feedbackMessage = '';
  bool _isHintVisible = false;
  
  bool _isSpellingQuestion = true;
  List<String> _mcOptions = [];
  int _tokens = 0;
  bool _isAudioMode = false; // Whether current question is audio-based
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
    await _flutterTts.setSpeechRate(0.4); // Slower for learning
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
    if (widget.mode == QuizMode.stage && widget.targetStage != null) {
      words = await DatabaseHelper.instance.getWordsForStage(widget.targetStage!);
    } else if (widget.mode == QuizMode.reinforcement && widget.targetStage != null) {
      words = await DatabaseHelper.instance.getWordsForStage(widget.targetStage!);
    } else if (widget.mode == QuizMode.ultimate && widget.maxStage != null) {
      words = await DatabaseHelper.instance.getWordsUpToStage(widget.maxStage!, 25);
    } else {
      words = await DatabaseHelper.instance.getRandomWords(10);
    }

    // Shuffle words for ALL modes to ensure variety
    words.shuffle();
    
    setState(() {
      _quizWords = words;
      _prepareQuestion(0);
    });
    return words;
  }

  void _prepareQuestion(int index) {
    if (index >= _quizWords.length) return;
    
    // Always use spelling/building mode
    _isSpellingQuestion = true; 
    
    final currentWord = _quizWords[index];
    
    // 50% chance for audio mode
    _isAudioMode = Random().nextBool();
    
    // Prepare Scrambled Letters
    _targetLetters = currentWord.english.toUpperCase().split('');
    _shuffledLetters = List.from(_targetLetters)..shuffle();
    _selectedLetters = [];
    _letterUsed = List.filled(_shuffledLetters.length, false);
    
    _isAnswered = false;
    _feedbackMessage = '';
    _isHintVisible = false;
    
    // Auto-play audio if in audio mode
    if (_isAudioMode) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _speakWord(currentWord.english);
      });
    }
  }

  Future<void> _speakWord(String word) async {
    await _flutterTts.speak(word);
  }

  void _generateMCOptions(Word correctWord) {
    final distractors = _quizWords.where((w) => w.id != correctWord.id).toList();
    distractors.shuffle();
    final options = distractors.take(3).map((w) => w.kurdishSorani).toList();
    options.add(correctWord.kurdishSorani);
    options.shuffle();
    _mcOptions = options;
  }

  void _onLetterTap(String letter, int index) {
    if (_isAnswered || _letterUsed[index]) return;
    
    setState(() {
      _selectedLetters.add(letter);
      _letterUsed[index] = true; // Mark as used
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
      
      // Find and re-enable the letter in the pool
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
      _letterUsed = List.filled(_shuffledLetters.length, false); // Re-enable all letters
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

  void _checkMC(String selectedOption) {
    if (_isAnswered) return;
    
    final correct = _quizWords[_currentIndex].kurdishSorani;
    if (selectedOption == correct) {
      _handleCorrect();
    } else {
      setState(() {
        _isAnswered = true;
        _isCorrect = false;
        _feedbackMessage = 'Incorrect! The answer was $correct';
      });
      Future.delayed(const Duration(seconds: 2), _nextQuestion);
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
      if (widget.mode == QuizMode.stage) {
        tokensEarned = 10;
        await DatabaseHelper.instance.advanceStage(widget.targetStage!);
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
    
    // Deduct token
    await DatabaseHelper.instance.updateTokens(-1);
    setState(() {
      _tokens--;
    });
    
    int nextIndex = _selectedLetters.length;
    String neededChar = _targetLetters[nextIndex];
    
    // Find the first unused instance of the needed character
    for (int i = 0; i < _shuffledLetters.length; i++) {
      if (_shuffledLetters[i] == neededChar && !_letterUsed[i]) {
        _onLetterTap(neededChar, i);
        
        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Hint used! $_tokens tokens remaining'),
              ],
            ),
            backgroundColor: const Color(0xFF6366F1),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
    }
    
    // If letter already used, refund the token
    await DatabaseHelper.instance.updateTokens(1);
    setState(() {
      _tokens++;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The letter you need is already used! Try clearing some slots.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEEF3FF), // Light indigo
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
          if (_isSpellingQuestion && !_isAnswered)
            IconButton(
              icon: const Icon(Icons.lightbulb_outline, color: Colors.white), 
              tooltip: _tokens > 0 ? 'Hint (1 token)' : 'No tokens',
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
             return const Center(child: Text('No words found for this quiz!'));
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
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isHintVisible ? const Color(0xFFFEF3C7) : Colors.transparent,
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
                          color: const Color(0xFFF59E0B),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _isHintVisible
                              ? Text(
                                  word.hint,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isHintVisible = true;
                                    });
                                  },
                                  child: const Text(
                                    'Tap to show hint',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                        ),
                        if (!_isHintVisible)
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 20),
                            color: Colors.grey,
                            onPressed: () {
                              setState(() {
                                _isHintVisible = true;
                              });
                            },
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),
                
                if (_isSpellingQuestion) 
                  _buildSpellingLayout(word, _isAudioMode)
                else 
                  _buildMCLayout(word),

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
                  if (!_isCorrect && _isSpellingQuestion)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: _resetCurrentQuestion,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Clear & Retry"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
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
      case QuizMode.stage: return 'Stage Quiz';
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
         if (isAudio)
           // Audio mode - show speaker button
           Container(
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
                   blurRadius: 12,
                   offset: const Offset(0, 4),
                 ),
               ],
             ),
             child: Column(
               children: [
                 const Icon(
                   Icons.hearing,
                   size: 48,
                   color: Colors.white,
                 ),
                 const SizedBox(height: 16),
                 ElevatedButton.icon(
                   onPressed: () => _speakWord(word.english),
                   icon: const Icon(Icons.volume_up, size: 28),
                   label: const Text(
                     'Play Word',
                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                   ),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.white,
                     foregroundColor: const Color(0xFF6366F1),
                     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                     elevation: 4,
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(12),
                     ),
                   ),
                 ),
                 const SizedBox(height: 12),
                 const Text(
                   'Tap to hear the word again',
                   style: TextStyle(
                     fontSize: 14,
                     color: Colors.white70,
                     fontStyle: FontStyle.italic,
                   ),
                 ),
               ],
             ),
           )
         else
           // Visual mode - show translations
           Container(
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
                   blurRadius: 12,
                   offset: const Offset(0, 4),
                 ),
               ],
             ),
             child: Column(
               children: [
                 Text(
                   word.kurdishSorani,
                   style: const TextStyle(
                     fontSize: 32,
                     fontWeight: FontWeight.bold,
                     color: Colors.white,
                   ),
                 ),
                 const SizedBox(height: 8),
                 Text(
                   word.arabic,
                   style: const TextStyle(
                     fontSize: 24,
                     color: Colors.white70,
                   ),
                 ),
               ],
             ),
           ),
         const SizedBox(height: 30),
         
         // Answer Slots
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
                   color: char.isNotEmpty ? Colors.white : Colors.transparent,
                 ),
                 child: Text(char, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
               ),
             );
           }),
         ),
         
         const SizedBox(height: 30),
         
         // Shuffled Letters Pool
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
                 borderRadius: BorderRadius.circular(12),
                 child: Container(
                   width: 50,
                   height: 50,
                   decoration: BoxDecoration(
                     color: isUsed ? Colors.grey.shade200 : Colors.white,
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(
                       color: isUsed ? Colors.grey.shade400 : const Color(0xFF6366F1),
                       width: 2,
                     ),
                   ),
                   child: Center(
                     child: Text(
                       _shuffledLetters[index],
                       style: TextStyle(
                         fontSize: 20,
                         fontWeight: FontWeight.bold,
                         color: isUsed ? Colors.grey.shade500 : const Color(0xFF6366F1),
                       ),
                     ),
                   ),
                 ),
               ),
             );
           }),
         ),
         
         const SizedBox(height: 20),
         if (_isAnswered)
            Text(
               'Answer: ${word.english}', 
               style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)
            ),
      ],
    );
  }

  Widget _buildMCLayout(Word word) {
    return Column(
      children: [
        const Text('Select the Meaning:', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 10),
        Text(word.english, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        ..._mcOptions.map((option) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAnswered 
                    ? (option == word.kurdishSorani ? Colors.green : (option == word.kurdishSorani ? Colors.red : Colors.blue.shade100))
                    : Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: _isAnswered ? null : () => _checkMC(option),
              child: Text(option, style: const TextStyle(fontSize: 20)),
            ),
          ),
        )).toList(),
      ],
    );
  }
}
