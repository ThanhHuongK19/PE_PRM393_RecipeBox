import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_box/features/recipes/models/recipe.dart';
import 'package:recipe_box/features/recipes/providers/recipe_provider.dart';
import 'package:recipe_box/features/recipes/repositories/recipe_repository.dart';
import 'package:recipe_box/features/recipes/services/recipe_service.dart';

void main() {
  late _MemoryRecipeService service;
  late RecipeProvider provider;

  setUp(() {
    service = _MemoryRecipeService();
    provider = RecipeProvider(
      repository: RecipeRepository(recipeService: service),
    );
  });

  tearDown(() {
    provider.dispose();
  });

  test('filters combine and search matches names and notes', () async {
    service.recipes = [
      _recipe('rice-lunch', 'Rice Bowl', 'Lunch', 'Easy', 20, true, 'lime'),
      _recipe('rice-dinner', 'Chicken Rice', 'Dinner', 'Easy', 30, true, 'spicy'),
      _recipe('soup-lunch', 'Soup', 'Lunch', 'Hard', 40, false, 'chicken broth'),
      _recipe('cake', 'Cake', 'Dessert', 'Easy', 50, true, 'vanilla'),
    ];
    await _loadProvider(provider);

    provider.setCategoryFilter('Lunch');
    expect(provider.visibleRecipes.map((recipe) => recipe.id), ['rice-lunch', 'soup-lunch']);
    provider.setDifficultyFilter('Hard');
    expect(provider.visibleRecipes.map((recipe) => recipe.id), ['soup-lunch']);
    provider.setFavoritesOnly(true);
    expect(provider.visibleRecipes, isEmpty);

    provider.clearFilters();
    provider.setSearchQuery('  CHICKEN  ');
    expect(
      provider.visibleRecipes.map((recipe) => recipe.id).toSet(),
      {'rice-dinner', 'soup-lunch'},
    );
    provider.setSearchQuery('  LIME ');
    expect(provider.visibleRecipes.single.id, 'rice-lunch');

    provider.setCategoryFilter('Lunch');
    provider.setDifficultyFilter('Easy');
    provider.setFavoritesOnly(true);
    provider.setSearchQuery('lime');
    expect(provider.visibleRecipes.single.id, 'rice-lunch');
    provider.clearFilters();
    expect(provider.hasActiveFilters, isFalse);
    expect(provider.visibleRecipes, hasLength(4));
  });

  test('summary uses visible data and category tie order', () async {
    service.recipes = [
      _recipe('b1', 'B1', 'Breakfast', 'Easy', 10, true),
      _recipe('b2', 'B2', 'Breakfast', 'Easy', 20, false),
      _recipe('l1', 'L1', 'Lunch', 'Medium', 30, true),
      _recipe('l2', 'L2', 'Lunch', 'Hard', 40, false),
      _recipe('d1', 'D1', 'Dinner', 'Easy', 50, false),
      _recipe('de1', 'DE1', 'Dessert', 'Easy', 60, true),
    ];
    await _loadProvider(provider);

    expect(provider.summary.recipeCount, 6);
    expect(provider.summary.favoriteCount, 3);
    expect(provider.summary.totalCookTime, 210);
    expect(
      provider.summary.categoryCounts.map((item) => item.category),
      ['Breakfast', 'Lunch', 'Dinner', 'Dessert'],
    );
    expect(
      provider.summary.categoryCounts.map((item) => item.count),
      [2, 2, 1, 1],
    );

    provider.setCategoryFilter('Dessert');
    expect(provider.summary.recipeCount, 1);
    expect(provider.summary.favoriteCount, 1);
    expect(provider.summary.totalCookTime, 60);
    expect(provider.summary.categoryCounts.single.category, 'Dessert');
  });

  test('add, edit, delete, and favorite changes update provider state', () async {
    service.recipes = [
      _recipe('first', 'First', 'Lunch', 'Easy', 40, false),
    ];
    await _loadProvider(provider);

    final added = await provider.addRecipe(
      _recipe('', 'Second', 'Dinner', 'Medium', 20, false),
    );
    expect(provider.recipes.map((recipe) => recipe.id), ['new-id', 'first']);

    final edited = await provider.updateRecipe(
      added.copyWith(name: 'Changed', cookTime: 60),
    );
    expect(edited.id, 'new-id');
    expect(provider.recipes.last.name, 'Changed');

    await provider.toggleFavorite(edited);
    expect(provider.recipes.last.favorite, isTrue);

    await provider.deleteRecipe('new-id');
    expect(provider.recipes.map((recipe) => recipe.id), ['first']);
  });
}

Future<void> _loadProvider(RecipeProvider provider) async {
  final loaded = Completer<void>();
  provider.addListener(() {
    if (!provider.isLoading && provider.recipes.isNotEmpty && !loaded.isCompleted) {
      loaded.complete();
    }
  });
  provider.startListening();
  await loaded.future.timeout(const Duration(seconds: 1));
}

Recipe _recipe(
  String id,
  String name,
  String category,
  String difficulty,
  int cookTime,
  bool favorite, [
  String notes = '',
]) =>
    Recipe(
      id: id,
      userId: 'test-user',
      name: name,
      category: category,
      difficulty: difficulty,
      cookTime: cookTime,
      favorite: favorite,
      notes: notes,
    );

class _MemoryRecipeService implements RecipeService {
  List<Recipe> recipes = [];

  @override
  Stream<List<Recipe>> watchRecipes() => Stream.value(recipes);

  @override
  Future<List<Recipe>> getRecipes() async => recipes;

  @override
  Future<Recipe> addRecipe(Recipe recipe) async {
    final saved = recipe.copyWith(id: 'new-id', userId: 'test-user');
    recipes = [...recipes, saved];
    return saved;
  }

  @override
  Future<Recipe> updateRecipe(Recipe recipe) async {
    recipes = recipes.map((item) => item.id == recipe.id ? recipe : item).toList();
    return recipe;
  }

  @override
  Future<void> deleteRecipe(String recipeId) async {
    recipes = recipes.where((item) => item.id != recipeId).toList();
  }

  @override
  Future<Recipe> toggleFavorite(String recipeId) async {
    final index = recipes.indexWhere((recipe) => recipe.id == recipeId);
    final updated = recipes[index].copyWith(favorite: !recipes[index].favorite);
    recipes[index] = updated;
    return updated;
  }
}
