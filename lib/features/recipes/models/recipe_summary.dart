import 'recipe.dart';

class RecipeCategoryCount {
  const RecipeCategoryCount({required this.category, required this.count});

  final String category;
  final int count;
}

/// Statistics derived from exactly the recipe set supplied to [fromRecipes].
class RecipeSummary {
  const RecipeSummary({
    required this.recipeCount,
    required this.favoriteCount,
    required this.totalCookTime,
    required this.categoryCounts,
  });

  static const List<String> _categoryOrder = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Dessert',
  ];

  final int recipeCount;
  final int favoriteCount;
  final int totalCookTime;
  final List<RecipeCategoryCount> categoryCounts;

  factory RecipeSummary.fromRecipes(Iterable<Recipe> recipes) {
    var recipeCount = 0;
    var favoriteCount = 0;
    var totalCookTime = 0;
    final countsByCategory = <String, int>{};

    for (final recipe in recipes) {
      recipeCount++;
      if (recipe.favorite) favoriteCount++;
      totalCookTime += recipe.cookTime;
      countsByCategory.update(
        recipe.category,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final categories = _categoryOrder
        .where((category) => (countsByCategory[category] ?? 0) > 0)
        .map(
          (category) => RecipeCategoryCount(
            category: category,
            count: countsByCategory[category]!,
          ),
        )
        .toList();
    categories.sort((first, second) {
      final countOrder = second.count.compareTo(first.count);
      if (countOrder != 0) return countOrder;
      return _categoryOrder
          .indexOf(first.category)
          .compareTo(_categoryOrder.indexOf(second.category));
    });

    return RecipeSummary(
      recipeCount: recipeCount,
      favoriteCount: favoriteCount,
      totalCookTime: totalCookTime,
      categoryCounts: List.unmodifiable(categories),
    );
  }
}
