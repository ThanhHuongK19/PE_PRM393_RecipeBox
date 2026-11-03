import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/screens/app_start_screen.dart';
import '../providers/recipe_provider.dart';
import '../widgets/recipe_card.dart';
import '../widgets/recipe_filter_controls.dart';
import '../widgets/recipe_summary_card.dart';
import 'add_recipe_screen.dart';
import 'recipe_detail_screen.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  late final RecipeProvider _recipeProvider;

  @override
  void initState() {
    super.initState();
    _recipeProvider = context.read<RecipeProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recipeProvider.startListening();
    });
  }

  @override
  void dispose() {
    _recipeProvider.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.checking) {
      return const Scaffold(body: LoadingView());
    }
    if (auth.status != AuthStatus.signedIn) {
      return const AppStartScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe List'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton.icon(
              onPressed: auth.isLoading ? null : () => auth.logout(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AddRecipeScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Recipe'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      auth.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (auth.errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  auth.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: Consumer<RecipeProvider>(
                builder: (context, recipes, _) => CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: RecipeFilterControls(provider: recipes),
                    ),
                    SliverToBoxAdapter(
                      child: RecipeSummaryCard(summary: recipes.summary),
                    ),
                    if (recipes.operationError != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            0,
                          ),
                          child: MaterialBanner(
                            content: Text(recipes.operationError!),
                            leading: const Icon(Icons.error_outline),
                            actions: [
                              TextButton(
                                onPressed: recipes.clearOperationError,
                                child: const Text('Dismiss'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (recipes.isLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: LoadingView(message: 'Loading recipes...'),
                      )
                    else if (recipes.errorMessage != null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: ErrorView(
                          message: recipes.errorMessage!,
                          onRetry: recipes.retry,
                        ),
                      )
                    else if (recipes.visibleRecipes.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('No recipes found')),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          96,
                        ),
                        sliver: SliverList.builder(
                          itemCount: recipes.visibleRecipes.length,
                          itemBuilder: (context, index) {
                            final recipe = recipes.visibleRecipes[index];
                            return RecipeCard(
                              recipe: recipe,
                              isFavoriteUpdating: recipes.favoriteUpdates
                                  .contains(recipe.id),
                              onFavoritePressed: () =>
                                  recipes.toggleFavorite(recipe),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      RecipeDetailScreen(recipe: recipe),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
