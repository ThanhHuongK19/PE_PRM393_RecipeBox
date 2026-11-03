import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_spacing.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../widgets/recipe_form.dart';

/// Recipe detail destination with view, edit, favorite, and delete actions.
class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({required this.recipe, super.key});

  final Recipe recipe;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late final RecipeProvider _recipeProvider;
  late Recipe _recipe;
  bool _isEditing = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _recipeProvider = context.read<RecipeProvider>();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.status != AuthStatus.signedIn || auth.uid != _recipe.userId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe Details')),
        body: const Center(child: Text('Recipe not found')),
      );
    }

    return Consumer<RecipeProvider>(
      builder: (context, recipes, _) {
        final currentRecipe = _findCurrentRecipe(recipes);
        if (currentRecipe == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Recipe Details')),
            body: const Center(child: Text('Recipe no longer available')),
          );
        }

        if (_isEditing) return _buildEditMode(currentRecipe);
        return _buildViewMode(context, currentRecipe, recipes);
      },
    );
  }

  Recipe? _findCurrentRecipe(RecipeProvider provider) {
    for (final recipe in provider.recipes) {
      if (recipe.id == _recipe.id) return recipe;
    }
    return null;
  }

  Widget _buildViewMode(
    BuildContext context,
    Recipe recipe,
    RecipeProvider provider,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Details'),
        actions: [
          IconButton(
            tooltip: 'Edit recipe',
            onPressed: () => setState(() => _isEditing = true),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete recipe',
            onPressed: _isDeleting ? null : () => _confirmDelete(recipe),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            Text(
              recipe.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            _detailRow('Category', recipe.category),
            _detailRow('Difficulty', recipe.difficulty),
            _detailRow('Cook time', '${recipe.cookTime} min'),
            _detailRow('Servings', recipe.servings?.toString() ?? 'Not specified'),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: ListTile(
                title: const Text('Notes'),
                subtitle: Text(
                  recipe.notes.isEmpty ? 'No notes' : recipe.notes,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: SwitchListTile.adaptive(
                title: const Text('Favorite'),
                value: recipe.favorite,
                onChanged: provider.favoriteUpdates.contains(recipe.id)
                    ? null
                    : (_) => provider.toggleFavorite(recipe),
                secondary: Icon(
                  recipe.favorite ? Icons.star : Icons.star_border,
                  color: recipe.favorite
                      ? Theme.of(context).colorScheme.tertiary
                      : null,
                ),
              ),
            ),
            if (provider.operationError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                provider.operationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditMode(Recipe recipe) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Recipe')),
      body: SafeArea(
        child: RecipeForm(
          key: ValueKey('edit-${recipe.id}'),
          initialRecipe: recipe,
          submitLabel: 'Save',
          cancelLabel: 'Cancel',
          successMessage: 'Recipe updated',
          clearAfterSubmit: false,
          onCancel: () => setState(() => _isEditing = false),
          onSubmit: (formData) async {
            final updated = await _recipeProvider.updateRecipe(
              recipe.copyWith(
                name: formData.name,
                category: formData.category,
                difficulty: formData.difficulty,
                cookTime: formData.cookTime,
                servings: formData.servings,
                notes: formData.notes,
              ),
            );
            if (!mounted) return;
            setState(() {
              _recipe = updated;
              _isEditing = false;
            });
          },
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Delete "${recipe.name}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _recipeProvider.deleteRecipe(recipe.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      setState(() => _isDeleting = false);
    }
  }
}
