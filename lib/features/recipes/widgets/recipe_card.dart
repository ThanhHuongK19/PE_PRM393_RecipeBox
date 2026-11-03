import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../models/recipe.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    required this.recipe,
    required this.onTap,
    required this.onFavoritePressed,
    this.isFavoriteUpdating = false,
    super.key,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onFavoritePressed;
  final bool isFavoriteUpdating;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('${recipe.category} · ${recipe.difficulty}'),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text('${recipe.cookTime} min'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: recipe.favorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                onPressed: isFavoriteUpdating ? null : onFavoritePressed,
                icon: isFavoriteUpdating
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        recipe.favorite ? Icons.star : Icons.star_border,
                        color: recipe.favorite ? colors.tertiary : null,
                      ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
