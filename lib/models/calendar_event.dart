class CalendarEvent {
  final int? id;
  final String title;
  final String? description;
  final String startTime; // "HH:mm"
  final String? endTime; // "HH:mm"
  final DateTime date; // fecha ancla (la primera ocurrencia)
  final String recurrence; // 'none' | 'weekly'
  final List<int> weekdays; // 1=lunes ... 7=domingo (solo si recurrence == weekly)
  final DateTime? repeatUntil; // null = se repite para siempre
  final String category;
  final List<int> linkedHabitIds; // hábitos y/o tareas vinculados (0, 1 o varios)
  final DateTime createdAt;
  final String? color; // hex elegido por el usuario, ej "#60A5FA". null = usa el color de la categoría.

  const CalendarEvent({
    this.id,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    required this.date,
    this.recurrence = 'none',
    this.weekdays = const [],
    this.repeatUntil,
    this.category = 'general',
    this.linkedHabitIds = const [],
    required this.createdAt,
    this.color,
  });

  bool get isRecurring => recurrence == 'weekly' && weekdays.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'startTime': startTime,
        'endTime': endTime,
        'date': date.toIso8601String(),
        'recurrence': recurrence,
        'weekdays': weekdays.isEmpty ? null : weekdays.join(','),
        'repeatUntil': repeatUntil?.toIso8601String(),
        'category': category,
        'createdAt': createdAt.toIso8601String(),
        'color': color,
      };

  factory CalendarEvent.fromMap(Map<String, dynamic> map) => CalendarEvent(
        id: map['id'],
        title: map['title'],
        description: map['description'],
        startTime: map['startTime'],
        endTime: map['endTime'],
        date: DateTime.parse(map['date']),
        recurrence: map['recurrence'] ?? 'none',
        weekdays: (map['weekdays'] as String?)?.isNotEmpty == true
            ? (map['weekdays'] as String).split(',').map((s) => int.parse(s)).toList()
            : const [],
        repeatUntil: map['repeatUntil'] != null ? DateTime.parse(map['repeatUntil']) : null,
        category: map['category'] ?? 'general',
        createdAt: DateTime.parse(map['createdAt']),
        color: map['color'],
      );

  CalendarEvent copyWith({
    String? title,
    String? description,
    String? startTime,
    String? endTime,
    String? recurrence,
    List<int>? weekdays,
    DateTime? repeatUntil,
    String? category,
    List<int>? linkedHabitIds,
    DateTime? date,
    bool clearRepeatUntil = false,
    String? color,
    bool clearColor = false,
  }) =>
      CalendarEvent(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        date: date ?? this.date,
        recurrence: recurrence ?? this.recurrence,
        weekdays: weekdays ?? this.weekdays,
        repeatUntil: clearRepeatUntil ? null : (repeatUntil ?? this.repeatUntil),
        category: category ?? this.category,
        linkedHabitIds: linkedHabitIds ?? this.linkedHabitIds,
        createdAt: createdAt,
        color: clearColor ? null : (color ?? this.color),
      );
}