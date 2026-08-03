class CalendarEvent {
  final int? id;
  final String title;
  final String? description;
  final String startTime; // "HH:mm"
  final String? endTime; // "HH:mm"
  final DateTime date; // fecha ancla
  final String recurrence; // none, daily, weekly, monthly
  final String category;
  final int? linkedHabitId;
  final DateTime createdAt;

  CalendarEvent({
    this.id,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    required this.date,
    this.recurrence = 'none',
    this.category = 'general',
    this.linkedHabitId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'startTime': startTime,
        'endTime': endTime,
        'date': date.toIso8601String(),
        'recurrence': recurrence,
        'category': category,
        'linkedHabitId': linkedHabitId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CalendarEvent.fromMap(Map<String, dynamic> map) => CalendarEvent(
        id: map['id'],
        title: map['title'],
        description: map['description'],
        startTime: map['startTime'],
        endTime: map['endTime'],
        date: DateTime.parse(map['date']),
        recurrence: map['recurrence'] ?? 'none',
        category: map['category'] ?? 'general',
        linkedHabitId: map['linkedHabitId'],
        createdAt: DateTime.parse(map['createdAt']),
      );

  CalendarEvent copyWith({
    String? title,
    String? description,
    String? startTime,
    String? endTime,
    String? recurrence,
    String? category,
    int? linkedHabitId,
    bool clearLink = false,
  }) =>
      CalendarEvent(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        date: date,
        recurrence: recurrence ?? this.recurrence,
        category: category ?? this.category,
        linkedHabitId: clearLink ? null : (linkedHabitId ?? this.linkedHabitId),
        createdAt: createdAt,
      );
}