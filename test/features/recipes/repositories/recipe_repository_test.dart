import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_box/features/recipes/models/recipe.dart';
import 'package:recipe_box/features/recipes/repositories/recipe_repository.dart';
import 'package:recipe_box/features/recipes/services/recipe_service.dart';

void main() {
  group('RecipeRepository', () {
    late _RecordingRecipeService service;
    late RecipeRepository repository;

    setUp(() {
      service = _RecordingRecipeService();
      repository = RecipeRepository(recipeService: service);
    });

    test(
      'sorts fetched recipes by cook time and case-insensitive name',
      () async {
        service.recipes = [
          _recipe(id: 'late', name: 'Ziti', cookTime: 20),
          _recipe(id: 'same-b', name: 'bagel', cookTime: 10),
          _recipe(id: 'same-a', name: 'Apple', cookTime: 10),
        ];

        final result = await repository.getRecipes();

        expect(result.map((recipe) => recipe.id), ['same-a', 'same-b', 'late']);
        expect(service.calls, ['getRecipes']);
      },
    );

    test('sorts live recipe snapshots the same way', () async {
      service.recipes = [
        _recipe(id: 'second', name: 'Berry', cookTime: 8),
        _recipe(id: 'first', name: 'apple', cookTime: 8),
      ];

      final result = await repository.watchRecipes().first;

      expect(result.map((recipe) => recipe.id), ['first', 'second']);
      expect(service.calls, ['watchRecipes']);
    });

    test('delegates add, update, delete, and favorite operations', () async {
      final recipe = _recipe(id: 'r1', name: 'Soup', cookTime: 15);
      await repository.addRecipe(recipe);
      await repository.updateRecipe(recipe.copyWith(name: 'Stew'));
      await repository.toggleFavorite(recipe.id);
      await repository.deleteRecipe(recipe.id);

      expect(service.calls, [
        'addRecipe',
        'updateRecipe',
        'toggleFavorite',
        'deleteRecipe',
      ]);
    });

    test('does not swallow duplicate-name failures from Firestore service', () {
      service.addError = const DuplicateRecipeException('Pho Bo');

      expect(
        repository.addRecipe(
          _recipe(id: 'unused', name: 'pho bo', cookTime: 1),
        ),
        throwsA(isA<DuplicateRecipeException>()),
      );
    });
  });

  group('Recipe name claim IDs', () {
    test('case-insensitive names produce the same normalized claim ID', () {
      expect(
        FirestoreRecipeService.recipeNameClaimId('Pho Bo'),
        FirestoreRecipeService.recipeNameClaimId('pho bo'),
      );
    });

    test('slashes are escaped in the per-user claim document ID', () {
      final claimId = FirestoreRecipeService.recipeNameClaimId('A/B');

      expect(claimId, contains('%2F'));
      expect(claimId, isNot(contains('/')));
    });
  });
}

Recipe _recipe({
  required String id,
  required String name,
  required int cookTime,
}) => Recipe(
  id: id,
  userId: 'test-user',
  name: name,
  category: 'Dinner',
  difficulty: 'Easy',
  cookTime: cookTime,
  createdAt: Timestamp.fromDate(DateTime.utc(2026, 11, 3)),
);

class _RecordingRecipeService implements RecipeService {
  final List<String> calls = [];
  List<Recipe> recipes = [];
  Object? addError;

  @override
  Stream<List<Recipe>> watchRecipes() {
    calls.add('watchRecipes');
    return Stream.value(recipes);
  }

  @override
  Future<List<Recipe>> getRecipes() async {
    calls.add('getRecipes');
    return recipes;
  }

  @override
  Future<Recipe> addRecipe(Recipe recipe) async {
    calls.add('addRecipe');
    final error = addError;
    if (error != null) throw error;
    return recipe;
  }

  @override
  Future<Recipe> updateRecipe(Recipe recipe) async {
    calls.add('updateRecipe');
    return recipe;
  }

  @override
  Future<void> deleteRecipe(String recipeId) async {
    calls.add('deleteRecipe');
  }

  @override
  Future<Recipe> toggleFavorite(String recipeId) async {
    calls.add('toggleFavorite');
    return _recipe(id: recipeId, name: 'Soup', cookTime: 15);
  }
}
