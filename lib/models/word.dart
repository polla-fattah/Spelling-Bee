class Word {
  final int id;
  final String english;
  final String pos;
  final String kurdishSorani;
  final String arabic;
  final String hint;

  Word({
    required this.id,
    required this.english,
    required this.pos,
    required this.kurdishSorani,
    required this.arabic,
    required this.hint,
  });

  // Convert shorthand POS to full word
  String get posExpanded {
    switch (pos.toLowerCase().trim()) {
      case 'n':
      case 'noun':
        return 'Noun';
      case 'v':
      case 'verb':
        return 'Verb';
      case 'adj':
      case 'adjective':
        return 'Adjective';
      case 'adv':
      case 'adverb':
        return 'Adverb';
      case 'prep':
      case 'preposition':
        return 'Preposition';
      case 'pron':
      case 'pronoun':
        return 'Pronoun';
      case 'conj':
      case 'conjunction':
        return 'Conjunction';
      case 'interj':
      case 'interjection':
        return 'Interjection';
      case 'det':
      case 'determiner':
        return 'Determiner';
      case 'num':
      case 'numeral':
        return 'Numeral';
      default:
        return pos; // Return original if unknown
    }
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'],
      english: map['english'],
      pos: map['pos'],
      kurdishSorani: map['kurdish_sorani'],
      arabic: map['arabic'],
      hint: map['hint'] ?? '', // Default to empty if missing (backward compatibility)
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'english': english,
      'pos': pos,
      'kurdish_sorani': kurdishSorani,
      'arabic': arabic,
      'hint': hint,
    };
  }
}
