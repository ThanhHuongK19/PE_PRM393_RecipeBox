import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_box/features/recipes/models/recipe.dart';

void main() {
  group('Recipe serialization', () {
    final createdAt = Timestamp.fromDate(DateTime.utc(2026, 11, 3, 12));

    test('toFirestore writes the assignment field names and values', () {
      final recipe = Recipe(
        id: 'recipe-1',
        userId: 'user-1',
        name: 'Vegetable soup',
        category: 'Dinner',
        difficulty: 'Easy',
        cookTime: 35,
        servings: 4,
        favorite: true,
        notes: 'Add fresh herbs.',
        createdAt: createdAt,
      );

      final data = recipe.toFirestore();

      expect(data.keys.toSet(), {
        'id',
        'userId',
        'name',
        'category',
        'difficulty',
        'cookTime',
        'servings',
        'favorite',
        'notes',
        'createdAt',
      });
      expect(data['id'], 'recipe-1');
      expect(data['userId'], 'user-1');
      expect(data['category'], 'Dinner');
      expect(data['difficulty'], 'Easy');
      expect(data['cookTime'], 35);
      expect(data['servings'], 4);
      expect(data['favorite'], isTrue);
      expect(data['notes'], 'Add fresh herbs.');
      expect(data['createdAt'], createdAt);
    });

    test('fromFirestore uses the document ID and preserves Timestamp', () {
      final recipe = Recipe.fromFirestoreData(
        documentId: 'firestore-id',
        data: {
          'id': 'different-data-id',
          'userId': 'user-1',
          'name': 'Vegetable soup',
          'category': 'Dinner',
          'difficulty': 'Easy',
          'cookTime': 35,
          'servings': 4,
          'favorite': true,
          'notes': 'Add fresh herbs.',
          'createdAt': createdAt,
        },
      );

      expect(recipe.id, 'firestore-id');
      expect(recipe.createdAt, createdAt);
      expect(recipe.toFirestore()['id'], 'firestore-id');
    });

    test('optional values receive safe defaults and servings is omitted', () {
      final recipe = Recipe(
        id: 'recipe-2',
        userId: 'user-1',
        name: 'Toast',
        category: 'Breakfast',
        difficulty: 'Easy',
        cookTime: 5,
        createdAt: createdAt,
      );

      expect(recipe.favorite, isFalse);
      expect(recipe.notes, isEmpty);
      expect(recipe.servings, isNull);
      expect(recipe.toFirestore().containsKey('servings'), isFalse);

      final restored = Recipe.fromFirestoreData(
        documentId: 'recipe-2',
        data: {
          'userId': 'user-1',
          'name': 'Toast',
          'category': 'Breakfast',
          'difficulty': 'Easy',
          'cookTime': 5,
          'servings': null,
          'createdAt': createdAt,
        },
      );
      expect(restored.servings, isNull);
      expect(restored.favorite, isFalse);
      expect(restored.notes, isEmpty);
      expect(restored.createdAt, createdAt);
    });

    test('copyWith preserves fields and can clear servings', () {
      final original = Recipe(
        id: 'recipe-3',
        userId: 'user-1',
        name: 'Pasta',
        category: 'Dinner',
        difficulty: 'Medium',
        cookTime: 20,
        servings: 2,
        favorite: false,
        notes: 'Original note',
        createdAt: createdAt,
      );

      final updated = original.copyWith(favorite: true, servings: null);

      expect(updated.favorite, isTrue);
      expect(updated.servings, isNull);
      expect(updated.createdAt, createdAt);
      expect(updated.id, original.id);
      expect(updated.name, original.name);
    });
  });
}
