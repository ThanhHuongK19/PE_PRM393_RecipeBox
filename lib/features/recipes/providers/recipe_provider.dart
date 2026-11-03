import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/recipe.dart';
import '../models/recipe_summary.dart';
import '../repositories/recipe_repository.dart';

/// Application state for the signed-in user's live recipe list.
class RecipeProvider extends ChangeNotifier {
  RecipeProvider({required this._repository});

  final RecipeRepository _repository;
  StreamSubscription<List<Recipe>>? _subscription;
  Future<void>? _cancelFuture;
  int _listenerGeneration = 0;
  bool _shouldListen = false;
  bool _disposed = false;

  List<Recipe> _recipes = const [];
  final Set<String> _favoriteUpdates = {};
  bool _isLoading = false;
  String? _errorMessage;
  String? _operationError;
  String? _categoryFilter;
  String? _difficultyFilter;
  bool _favoritesOnly = false;
  String _searchQuery = '';

  List<Recipe> get recipes => List.unmodifiable(_recipes);
  List<Recipe> get visibleRecipes {
    final query = _searchQuery.trim().toLowerCase();
    return List.unmodifiable(
      _recipes.where((recipe) {
        if (_categoryFilter != null && recipe.category != _categoryFilter) {
          return false;
        }
        if (_difficultyFilter != null &&
            recipe.difficulty != _difficultyFilter) {
          return false;
        }
        if (_favoritesOnly && !recipe.favorite) return false;
        if (query.isNotEmpty &&
            !recipe.name.toLowerCase().contains(query) &&
            !recipe.notes.toLowerCase().contains(query)) {
          return false;
        }
        return true;
      }),
    );
  }

  RecipeSummary get summary => RecipeSummary.fromRecipes(visibleRecipes);

  Set<String> get favoriteUpdates => Set.unmodifiable(_favoriteUpdates);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get operationError => _operationError;
  String? get categoryFilter => _categoryFilter;
  String? get difficultyFilter => _difficultyFilter;
  bool get favoritesOnly => _favoritesOnly;
  String get searchQuery => _searchQuery;
  bool get hasActiveFilters =>
      _categoryFilter != null ||
      _difficultyFilter != null ||
      _favoritesOnly ||
      _searchQuery.trim().isNotEmpty;

  void setCategoryFilter(String? category) {
    if (_categoryFilter == category) return;
    _categoryFilter = category;
    _notify();
  }

  void setDifficultyFilter(String? difficulty) {
    if (_difficultyFilter == difficulty) return;
    _difficultyFilter = difficulty;
    _notify();
  }

  void setFavoritesOnly(bool value) {
    if (_favoritesOnly == value) return;
    _favoritesOnly = value;
    _notify();
  }

  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    _notify();
  }

  void clearFilters() {
    if (_categoryFilter == null &&
        _difficultyFilter == null &&
        !_favoritesOnly &&
        _searchQuery.isEmpty) {
      return;
    }
    _categoryFilter = null;
    _difficultyFilter = null;
    _favoritesOnly = false;
    _searchQuery = '';
    _notify();
  }

  Future<Recipe> addRecipe(Recipe recipe) async {
    final generation = _listenerGeneration;
    final saved = await _repository.addRecipe(recipe);
    if (_disposed || generation != _listenerGeneration) return saved;
    _insertRecipe(saved);
    _operationError = null;
    _notify();
    return saved;
  }

  Future<Recipe> updateRecipe(Recipe recipe) async {
    final generation = _listenerGeneration;
    final previousId = recipe.id;
    final saved = await _repository.updateRecipe(recipe);
    if (_disposed || generation != _listenerGeneration) return saved;
    final updated = _recipes.where((item) => item.id != previousId).toList()
      ..removeWhere((item) => item.id == saved.id)
      ..add(saved);
    _sortRecipes(updated);
    _recipes = List.unmodifiable(updated);
    _notify();
    return saved;
  }

  Future<void> deleteRecipe(String recipeId) async {
    final generation = _listenerGeneration;
    await _repository.deleteRecipe(recipeId);
    if (_disposed || generation != _listenerGeneration) return;
    _recipes = List.unmodifiable(
      _recipes.where((recipe) => recipe.id != recipeId),
    );
    _notify();
  }

  void startListening() {
    if (_disposed) return;
    _shouldListen = true;
    if (_subscription != null) return;

    _isLoading = true;
    _errorMessage = null;
    _operationError = null;
    _notify();
    final generation = ++_listenerGeneration;
    unawaited(_startAfterCancellation(generation));
  }

  Future<void> _startAfterCancellation(int generation) async {
    await _cancelFuture;
    if (_disposed || !_shouldListen || generation != _listenerGeneration) {
      return;
    }
    _subscription = _repository.watchRecipes().listen(
      (recipes) {
        if (_disposed || generation != _listenerGeneration) return;
        _recipes = recipes;
        _isLoading = false;
        _errorMessage = null;
        _notify();
      },
      onError: (Object error) {
        if (_disposed || generation != _listenerGeneration) return;
        _isLoading = false;
        _errorMessage = _friendlyError(error);
        _notify();
      },
    );
  }

  void retry() {
    stopListening();
    startListening();
  }

  void stopListening() {
    _shouldListen = false;
    _listenerGeneration++;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      final cancelFuture = subscription.cancel();
      _cancelFuture = cancelFuture;
      unawaited(
        cancelFuture.whenComplete(() {
          if (identical(_cancelFuture, cancelFuture)) _cancelFuture = null;
        }),
      );
    }

    final hadSessionData =
        _recipes.isNotEmpty ||
        _favoriteUpdates.isNotEmpty ||
        _isLoading ||
        _errorMessage != null ||
        _operationError != null;
    _recipes = const [];
    _favoriteUpdates.clear();
    _isLoading = false;
    _errorMessage = null;
    _operationError = null;
    if (hadSessionData) _notify();
  }

  Future<void> toggleFavorite(Recipe recipe) async {
    if (_disposed) return;
    if (!_favoriteUpdates.add(recipe.id)) return;
    final generation = _listenerGeneration;

    final previousFavorite = recipe.favorite;
    _operationError = null;
    _replaceRecipe(recipe.copyWith(favorite: !previousFavorite));
    _notify();

    try {
      final saved = await _repository.toggleFavorite(recipe.id);
      if (_disposed || generation != _listenerGeneration) return;
      _replaceRecipe(saved);
    } catch (error) {
      if (_disposed || generation != _listenerGeneration) return;
      final current = _recipes.where((item) => item.id == recipe.id);
      if (current.isNotEmpty) {
        _replaceRecipe(current.first.copyWith(favorite: previousFavorite));
      }
      _operationError = _friendlyError(error);
    } finally {
      _favoriteUpdates.remove(recipe.id);
      _notify();
    }
  }

  void clearOperationError() {
    if (_operationError == null) return;
    _operationError = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _replaceRecipe(Recipe replacement) {
    _recipes = List.unmodifiable(
      _recipes.map(
        (recipe) => recipe.id == replacement.id ? replacement : recipe,
      ),
    );
  }

  void _insertRecipe(Recipe recipe) {
    final updated = _recipes.where((item) => item.id != recipe.id).toList()
      ..add(recipe);
    _sortRecipes(updated);
    _recipes = List.unmodifiable(updated);
  }

  void _sortRecipes(List<Recipe> recipes) {
    recipes.sort((first, second) {
      final cookTimeOrder = first.cookTime.compareTo(second.cookTime);
      if (cookTimeOrder != 0) return cookTimeOrder;
      final nameOrder = first.name.toLowerCase().compareTo(
        second.name.toLowerCase(),
      );
      if (nameOrder != 0) return nameOrder;
      return first.name.compareTo(second.name);
    });
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  @override
  void dispose() {
    _disposed = true;
    _shouldListen = false;
    _listenerGeneration++;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }
}
