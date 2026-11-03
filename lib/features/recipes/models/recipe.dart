import 'package:cloud_firestore/cloud_firestore.dart';

/// Application model for a recipe document in the `recipes` collection.
class Recipe {
  Recipe({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.cookTime,
    this.servings,
    this.favorite = false,
    this.notes = '',
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  static const Object _unchanged = Object();

  final String id;
  final String userId;
  final String name;
  final String category;
  final String difficulty;
  final int cookTime;
  final int? servings;
  final bool favorite;
  final String notes;
  final Timestamp createdAt;

  factory Recipe.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Recipe document ${snapshot.id} has no data.');
    }

    return Recipe.fromFirestoreData(documentId: snapshot.id, data: data);
  }

  /// Deserializes document data separately to keep the mapping easy to test.
  factory Recipe.fromFirestoreData({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return Recipe(
      id: documentId,
      userId: data['userId'] as String,
      name: data['name'] as String,
      category: data['category'] as String,
      difficulty: data['difficulty'] as String,
      cookTime: data['cookTime'] as int,
      servings: data['servings'] as int?,
      favorite: data['favorite'] as bool? ?? false,
      notes: data['notes'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'userId': userId,
    'name': name,
    'category': category,
    'difficulty': difficulty,
    'cookTime': cookTime,
    if (servings != null) 'servings': servings,
    'favorite': favorite,
    'notes': notes,
    'createdAt': createdAt,
  };

  Recipe copyWith({
    String? id,
    String? userId,
    String? name,
    String? category,
    String? difficulty,
    int? cookTime,
    Object? servings = _unchanged,
    bool? favorite,
    String? notes,
    Timestamp? createdAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      cookTime: cookTime ?? this.cookTime,
      servings: identical(servings, _unchanged)
          ? this.servings
          : servings as int?,
      favorite: favorite ?? this.favorite,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
