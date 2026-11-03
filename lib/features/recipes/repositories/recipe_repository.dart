import '../models/recipe.dart';
import '../services/recipe_service.dart';

/// Recipe application data boundary with deterministic list ordering.
class RecipeRepository {
  RecipeRepository({required RecipeService recipeService})
    : _service = recipeService;

  final RecipeService _service;

  Stream<List<Recipe>> watchRecipes() =>
      _service.watchRecipes().map(_sortRecipes);

  Future<List<Recipe>> getRecipes() async =>
      _sortRecipes(await _service.getRecipes());

  Future<Recipe> addRecipe(Recipe recipe) => _service.addRecipe(recipe);

  Future<Recipe> updateRecipe(Recipe recipe) => _service.updateRecipe(recipe);

  Future<void> deleteRecipe(String recipeId) => _service.deleteRecipe(recipeId);

  Future<Recipe> toggleFavorite(String recipeId) =>
      _service.toggleFavorite(recipeId);

  List<Recipe> _sortRecipes(Iterable<Recipe> recipes) {
    final sorted = recipes.toList();
    sorted.sort((first, second) {
      final cookTimeOrder = first.cookTime.compareTo(second.cookTime);
      if (cookTimeOrder != 0) return cookTimeOrder;

      final nameOrder = first.name.toLowerCase().compareTo(
        second.name.toLowerCase(),
      );
      if (nameOrder != 0) return nameOrder;
      return first.name.compareTo(second.name);
    });
    return List.unmodifiable(sorted);
  }
}
