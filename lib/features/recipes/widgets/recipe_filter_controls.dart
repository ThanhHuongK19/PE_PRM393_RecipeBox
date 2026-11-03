import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../providers/recipe_provider.dart';

class RecipeFilterControls extends StatefulWidget {
  const RecipeFilterControls({required this.provider, super.key});

  final RecipeProvider provider;

  @override
  State<RecipeFilterControls> createState() => _RecipeFilterControlsState();
}

class _RecipeFilterControlsState extends State<RecipeFilterControls> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.provider.searchQuery,
    );
  }

  @override
  void didUpdateWidget(covariant RecipeFilterControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    final query = widget.provider.searchQuery;
    if (_searchController.text != query) {
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: provider.setSearchQuery,
            decoration: InputDecoration(
              labelText: 'Search recipes',
              hintText: 'Name or notes',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchQuery('');
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  label: 'Category',
                  value: provider.categoryFilter ?? 'All',
                  values: const [
                    'All',
                    'Breakfast',
                    'Lunch',
                    'Dinner',
                    'Dessert',
                  ],
                  onChanged: (value) => provider.setCategoryFilter(
                    value == 'All' ? null : value,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _FilterDropdown(
                  label: 'Difficulty',
                  value: provider.difficultyFilter ?? 'All',
                  values: const ['All', 'Easy', 'Medium', 'Hard'],
                  onChanged: (value) => provider.setDifficultyFilter(
                    value == 'All' ? null : value,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Favorites only'),
                  value: provider.favoritesOnly,
                  onChanged: provider.setFavoritesOnly,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  provider.clearFilters();
                  setState(() {});
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}
