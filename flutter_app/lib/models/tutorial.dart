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
    final stepsList = json['steps'];
    return Tutorial(
      id: json['id'] ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      difficultyLevel: json['difficulty_level']?.toString() ?? 'beginner',
      steps: stepsList is List
          ? stepsList.map((s) => TutorialStep.fromJson(s)).toList()
          : <TutorialStep>[],
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
      step: json['step'] ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}
