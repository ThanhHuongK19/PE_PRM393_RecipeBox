import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:recipe_box/core/theme/app_theme.dart';
import 'package:recipe_box/features/auth/providers/auth_provider.dart';
import 'package:recipe_box/features/auth/screens/login_screen.dart';
import 'package:recipe_box/features/auth/screens/register_screen.dart';
import 'package:recipe_box/features/home/screens/home_screen.dart';
import 'package:recipe_box/features/recipes/models/recipe.dart';
import 'package:recipe_box/features/recipes/providers/recipe_provider.dart';
import 'package:recipe_box/features/recipes/repositories/recipe_repository.dart';
import 'package:recipe_box/features/recipes/screens/add_recipe_screen.dart';
import 'package:recipe_box/features/recipes/screens/recipe_detail_screen.dart';
import 'package:recipe_box/features/recipes/screens/recipe_list_screen.dart';
import 'package:recipe_box/features/recipes/services/recipe_service.dart';

void main() {
  const viewport = Size(360, 640);
  late _TestAuthProvider auth;
  late RecipeProvider recipes;

  setUp(() {
    auth = _TestAuthProvider();
    recipes = RecipeProvider(
      repository: RecipeRepository(recipeService: _TestRecipeService()),
    );
  });

  tearDown(() {
    recipes.dispose();
    auth.dispose();
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<RecipeProvider>.value(value: recipes),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Home fits a phone and shows its features', (tester) async {
    await pumpScreen(tester, const HomeScreen());

    expect(find.text('RecipeBox'), findsNWidgets(2));
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sort by cooking time'),
      300,
      scrollable: find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.text('Save your recipes'), findsOneWidget);
    expect(find.text('Sort by cooking time'), findsOneWidget);
    expect(find.text('Mark your favorites'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login and Register forms render and scroll on a phone', (
    tester,
  ) async {
    await pumpScreen(tester, const LoginScreen());
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await pumpScreen(tester, const RegisterScreen());
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Register'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Authentication fields validate only after submit', (
    tester,
  ) async {
    await pumpScreen(tester, const LoginScreen());
    expect(find.text('Email is required'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    await pumpScreen(tester, const RegisterScreen());
    expect(find.text('Email is required'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Confirm password is required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recipe List renders a recipe on a phone', (tester) async {
    auth.status = AuthStatus.signedIn;
    auth.uid = 'test-user';
    await pumpScreen(tester, const RecipeListScreen());
    await tester.pump();

    expect(find.text('Recipe List'), findsOneWidget);
    expect(find.text('Sample Dinner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Recipe form fits a phone and scrolls', (tester) async {
    await pumpScreen(tester, const AddRecipeScreen());

    expect(find.text('Add Recipe'), findsNWidgets(2));
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Difficulty'), findsOneWidget);
    expect(find.text('Cook time'), findsOneWidget);
    expect(find.text('Servings (optional)'), findsOneWidget);
    expect(find.text('Notes (optional)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Recipe validation reports exact invalid-field messages', (
    tester,
  ) async {
    await pumpScreen(tester, const AddRecipeScreen());
    expect(find.text('Name is required'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Please choose a category'), findsOneWidget);
    expect(find.text('Please choose a difficulty'), findsOneWidget);
    expect(find.text('Cook time is required'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'R' * 81);
    await tester.enterText(find.byType(TextFormField).at(1), '0');
    await tester.enterText(find.byType(TextFormField).at(2), '21');
    await tester.enterText(find.byType(TextFormField).at(3), 'x' * 301);
    await tester.pumpAndSettle();
    expect(find.text('Name must be at most 80 characters'), findsOneWidget);
    expect(
      find.text('Cook time must be a whole number from 1 to 600'),
      findsOneWidget,
    );
    expect(
      find.text('Servings must be a whole number from 1 to 20'),
      findsOneWidget,
    );
    expect(find.text('Notes must be at most 300 characters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Detail and Edit modes render without horizontal overflow', (
    tester,
  ) async {
    auth.status = AuthStatus.signedIn;
    auth.uid = 'test-user';
    recipes.startListening();
    await tester.pump();
    await pumpScreen(tester, RecipeDetailScreen(recipe: _sampleRecipe));

    expect(find.text('Sample Dinner'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Edit recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Recipe'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final Recipe _sampleRecipe = Recipe(
  id: 'sample-id',
  userId: 'test-user',
  name: 'Sample Dinner',
  category: 'Dinner',
  difficulty: 'Easy',
  cookTime: 25,
  servings: 2,
  notes: 'A simple meal',
);

class _TestAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  AuthStatus status = AuthStatus.signedOut;

  @override
  String? uid;

  @override
  String? email = 'cook@example.com';

  @override
  bool isLoading = false;

  @override
  String? errorMessage;

  @override
  User? get currentUser => null;

  @override
  bool get isAuthenticated => status == AuthStatus.signedIn;

  @override
  void clearError() => errorMessage = null;

  @override
  Future<bool> login({required String email, required String password}) async =>
      true;

  @override
  Future<bool> register({
    required String email,
    required String password,
  }) async => true;

  @override
  Future<bool> logout() async => true;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestRecipeService implements RecipeService {
  @override
  Stream<List<Recipe>> watchRecipes() => Stream.value([_sampleRecipe]);

  @override
  Future<List<Recipe>> getRecipes() async => [_sampleRecipe];

  @override
  Future<Recipe> addRecipe(Recipe recipe) async =>
      recipe.copyWith(id: 'new-id', userId: 'test-user');

  @override
  Future<Recipe> updateRecipe(Recipe recipe) async => recipe;

  @override
  Future<void> deleteRecipe(String recipeId) async {}

  @override
  Future<Recipe> toggleFavorite(String recipeId) async =>
      _sampleRecipe.copyWith(favorite: !_sampleRecipe.favorite);
}
