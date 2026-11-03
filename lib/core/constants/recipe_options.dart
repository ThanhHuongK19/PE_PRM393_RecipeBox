enum RecipeCategory {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  dessert('Dessert');

  const RecipeCategory(this.label);

  final String label;

  static List<String> get labels =>
      RecipeCategory.values.map((category) => category.label).toList();
}

enum RecipeDifficulty {
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  const RecipeDifficulty(this.label);

  final String label;

  static List<String> get labels =>
      RecipeDifficulty.values.map((difficulty) => difficulty.label).toList();
}
