class Tutorial {
  final int id;
  final String title;
  final String description;
  final String category;
  final String difficultyLevel;
  final List<TutorialStep> steps;

  Tutorial({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficultyLevel,
    required this.steps,
  });

  factory Tutorial.fromJson(Map<String, dynamic> json) {
    return Tutorial(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      category: json['category'],
      difficultyLevel: json['difficulty_level'] ?? 'beginner',
      steps: (json['steps'] as List).map((s) => TutorialStep.fromJson(s)).toList(),
    );
  }
}

class TutorialStep {
  final int step;
  final String title;
  final String description;

  TutorialStep({
    required this.step,
    required this.title,
    required this.description,
  });

  factory TutorialStep.fromJson(Map<String, dynamic> json) {
    return TutorialStep(
      step: json['step'],
      title: json['title'],
      description: json['description'],
    );
  }
}
