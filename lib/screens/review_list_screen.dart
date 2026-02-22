import 'package:flutter/material.dart';
import '../models/word.dart';
import '../services/db_helper.dart';

class ReviewListScreen extends StatefulWidget {
  const ReviewListScreen({super.key});

  @override
  State<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> {
  bool _isLoading = true;
  List<Word> _words = [];
  int _currentGrade = 1;
  Map<int, List<Word>> _wordsByGrade = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. Get User Progress
      final stats = await DatabaseHelper.instance.getUserStats();
      int grade = stats['current_grade'] ?? 1;

      // 2. Fetch all words up to this grade
      final words = await DatabaseHelper.instance.getAllUnlockedWords(grade);

      // 3. Group words by grade
      Map<int, List<Word>> grouped = {};
      for (final word in words) {
        grouped.putIfAbsent(word.grade, () => []);
        grouped[word.grade]!.add(word);
      }

      if (mounted) {
        setState(() {
          _currentGrade = grade;
          _words = words;
          _wordsByGrade = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading review list: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            Color(0xFFF0F4FF), // Light indigo
            Color(0xFFF5F8FF),
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
            Icon(Icons.library_books, size: 24),
            SizedBox(width: 8),
            Text('Learned Words'),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? const Center(child: Text('No words learned yet! Start Grade 1.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _wordsByGrade.length,
                  itemBuilder: (context, index) {
                    final gradeNum = _wordsByGrade.keys.toList()[index];
                    final gradeWords = _wordsByGrade[gradeNum] ?? [];
                    
                    if (gradeWords.isEmpty) return const SizedBox.shrink();

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: gradeNum == _currentGrade,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          childrenPadding: const EdgeInsets.only(bottom: 8),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.bookmark, color: Colors.white, size: 24),
                          ),
                          title: Text(
                            'Grade $gradeNum',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          subtitle: Text(
                            '${gradeWords.length} words',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          children: gradeWords.asMap().entries.map((entry) {
                            final wordIndex = entry.key;
                            final word = entry.value;
                            
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  leading: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${wordIndex + 1}',
                                        style: const TextStyle(
                                          color: Color(0xFF6366F1),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    word.english,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  subtitle:                                   Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      word.posExpanded,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.all(12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          _buildDetailRow(
                                            Icons.translate,
                                            'Kurdish',
                                            word.kurdishSorani,
                                            const Color(0xFF6366F1),
                                          ),
                                          const SizedBox(height: 12),
                                          _buildDetailRow(
                                            Icons.language,
                                            'Arabic',
                                            word.arabic,
                                            const Color(0xFF10B981),
                                          ),
                                          if (word.hint.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.lightbulb,
                                                    size: 16,
                                                    color: Color(0xFFF59E0B),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      word.hint,
                                                      style: const TextStyle(
                                                        color: Color(0xFF92400E),
                                                        fontSize: 12,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
