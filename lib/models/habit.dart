class Habit {
  final int? id;
  final String name;
  final String frequency;
  final String? timeLimit;
  final DateTime? dueDate;
  final String? description;
  final bool isPaused;
  final bool isTask;
  final int points;
  final DateTime createdAt;
  final String category;
  final int currentStreak;
  final int bestStreak;
  final String? color; // hex elegido por el usuario, ej "#F87171". null = usa el color de la categoría.

  Habit({
    this.id,
    required this.name,
    required this.frequency,
    this.timeLimit,
    this.dueDate,
    this.description,
    this.isPaused = false,
    this.isTask = false,
    this.points = 0,
    required this.createdAt,
    this.category = 'general',
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'timeLimit': timeLimit,
      'dueDate': dueDate?.toIso8601String(),
      'description': description,
      'isPaused': isPaused ? 1 : 0,
      'isTask': isTask ? 1 : 0,
      'points': points,
      'createdAt': createdAt.toIso8601String(),
      'category': category,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'color': color,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'],
      name: map['name'],
      frequency: map['frequency'],
      timeLimit: map['timeLimit'],
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      description: map['description'],
      isPaused: map['isPaused'] == 1,
      isTask: map['isTask'] == 1,
      points: map['points'],
      createdAt: DateTime.parse(map['createdAt']),
      category: map['category'] ?? 'general',
      currentStreak: map['currentStreak'] ?? 0,
      bestStreak: map['bestStreak'] ?? 0,
      color: map['color'],
    );
  }

  Habit copyWith({
    String? name,
    String? category,
    String? timeLimit,
    DateTime? dueDate,
    String? description,
    bool? isPaused,
    bool? isTask,
    int? points,
    int? currentStreak,
    int? bestStreak,
    bool clearTimeLimit = false,
    bool clearDueDate = false,
    String? color,
    bool clearColor = false,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      frequency: frequency,
      timeLimit: clearTimeLimit ? null : (timeLimit ?? this.timeLimit),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      description: description ?? this.description,
      isPaused: isPaused ?? this.isPaused,
      isTask: isTask ?? this.isTask,
      points: points ?? this.points,
      createdAt: createdAt,
      category: category ?? this.category,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      color: clearColor ? null : (color ?? this.color),
    );
  }
}