import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../models/recipe_summary.dart';

class RecipeSummaryCard extends StatelessWidget {
  const RecipeSummaryCard({required this.summary, super.key});

  final RecipeSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                RecipeSummaryMetric(
                  label: 'Recipes',
                  value: summary.recipeCount,
                ),
                RecipeSummaryMetric(
                  label: 'Favorites',
                  value: summary.favoriteCount,
                ),
                RecipeSummaryMetric(
                  label: 'Total time',
                  value: summary.totalCookTime,
                  suffix: 'min',
                ),
              ],
            ),
            if (summary.categoryCounts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'By category',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final item in summary.categoryCounts)
                RecipeSummaryCategoryRow(item: item),
            ],
          ],
        ),
      ),
    );
  }
}

class RecipeSummaryMetric extends StatelessWidget {
  const RecipeSummaryMetric({
    required this.label,
    required this.value,
    this.suffix,
    super.key,
  });

  final String label;
  final int value;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final valueText = suffix == null ? '$value' : '$value $suffix';
    return Text(
      '$label: $valueText',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class RecipeSummaryCategoryRow extends StatelessWidget {
  const RecipeSummaryCategoryRow({required this.item, super.key});

  final RecipeCategoryCount item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(item.category)),
          Text('${item.count}'),
        ],
      ),
    );
  }
}
