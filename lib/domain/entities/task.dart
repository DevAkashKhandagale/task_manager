import 'package:equatable/equatable.dart';

class Task extends Equatable {
  final int? id;
  final String title;
  final bool completed;
  final int userId;
  final DateTime? createdAt;
  final bool isSynced;
  final bool isDeleted;

  const Task({
    this.id,
    required this.title,
    required this.completed,
    this.userId = 1,
    this.createdAt,
    this.isSynced = true,
    this.isDeleted = false,
  });

  Task copyWith({
    int? id,
    String? title,
    bool? completed,
    int? userId,
    DateTime? createdAt,
    bool? isSynced,
    bool? isDeleted,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'completed': completed,
      'userId': userId,
      'createdAt': createdAt?.toIso8601String(),
      'isSynced': isSynced,
      'isDeleted': isDeleted,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      title: json['title'],
      completed: json['completed'] is bool
          ? json['completed']
          : (json['completed'] == 1 || json['completed'] == true),
      userId: json['userId'] ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isSynced: json['isSynced'] is bool
          ? json['isSynced']
          : (json['isSynced'] == 1 || json['isSynced'] == true),
      isDeleted: json['isDeleted'] is bool
          ? json['isDeleted']
          : (json['isDeleted'] == 1 || json['isDeleted'] == true),
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    completed,
    userId,
    createdAt,
    isSynced,
    isDeleted,
  ];
}