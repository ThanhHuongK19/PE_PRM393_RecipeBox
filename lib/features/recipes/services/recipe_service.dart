import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/recipe.dart';

abstract interface class RecipeService {
  Stream<List<Recipe>> watchRecipes();

  Future<List<Recipe>> getRecipes();

  Future<Recipe> addRecipe(Recipe recipe);

  Future<Recipe> updateRecipe(Recipe recipe);

  Future<void> deleteRecipe(String recipeId);

  Future<Recipe> toggleFavorite(String recipeId);
}

/// Firebase-backed recipe operations. Every collection query is scoped to the
/// authenticated UID; caller-supplied ownership fields are never trusted.
class FirestoreRecipeService implements RecipeService {
  FirestoreRecipeService({
    required FirebaseFirestore database,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = database,
       _auth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  // Legacy documents need a companion uniqueness claim once. Remember claims
  // checked in this service instance so routine snapshot emissions don't
  // launch another transaction per recipe.
  final Set<String> _verifiedClaimPaths = {};

  CollectionReference<Map<String, dynamic>> get _recipes =>
      _firestore.collection('recipes');
  CollectionReference<Map<String, dynamic>> _nameClaimsFor(String uid) =>
      _firestore.collection('users').doc(uid).collection('recipeNameClaims');

  @override
  Stream<List<Recipe>> watchRecipes() async* {
    final uid = _requireUid();
    try {
      final query = _recipes.where('userId', isEqualTo: uid);
      await for (final snapshot in query.snapshots()) {
        final recipes = snapshot.docs
            .map(Recipe.fromFirestore)
            .toList(growable: false);
        await _ensureNameClaims(recipes, uid);
        yield recipes;
      }
    } on FirebaseException catch (error) {
      throw RecipeServiceException.fromFirebase(error);
    }
  }

  @override
  Future<List<Recipe>> getRecipes() async {
    final uid = _requireUid();
    try {
      final snapshot = await _recipes.where('userId', isEqualTo: uid).get();
      final recipes = snapshot.docs
          .map(Recipe.fromFirestore)
          .toList(growable: false);
      await _ensureNameClaims(recipes, uid);
      return recipes;
    } on FirebaseException catch (error) {
      throw RecipeServiceException.fromFirebase(error);
    }
  }

  @override
  Future<Recipe> addRecipe(Recipe recipe) async {
    final uid = _requireUid();
    final id = _recipes.doc().id;
    final reference = _recipes.doc(id);
    final claimReference = _nameClaimsFor(uid)
        .doc(recipeNameClaimId(recipe.name));

    try {
      await _firestore.runTransaction<void>((transaction) async {
        final claim = await transaction.get(claimReference);
        if (claim.exists) {
          throw DuplicateRecipeException(recipe.name);
        }

        transaction.set(
          reference,
          _toDocumentData(
            recipe,
            id: id,
            userId: uid,
            createdAt: FieldValue.serverTimestamp(),
          ),
        );
        transaction.set(
          claimReference,
          _toNameClaimData(uid: uid, name: recipe.name, recipeId: id),
        );
      });
      _verifiedClaimPaths.add(claimReference.path);
      return await _readSavedRecipe(reference);
    } on FirebaseException catch (error) {
      throw RecipeServiceException.fromFirebase(error);
    }
  }

  @override
  Future<Recipe> updateRecipe(Recipe recipe) async {
    final uid = _requireUid();
    final reference = _recipes.doc(recipe.id);
    final newClaimReference = _nameClaimsFor(uid)
        .doc(recipeNameClaimId(recipe.name));

    try {
      await _firestore.runTransaction<void>((transaction) async {
        final oldSnapshot = await transaction.get(reference);
        final oldData = oldSnapshot.data();
        if (!oldSnapshot.exists ||
            oldData == null ||
            oldData['userId'] != uid) {
          throw RecipeNotFoundException(recipe.id);
        }

        final oldName = oldData['name'] as String;
        final oldClaimReference = _nameClaimsFor(uid)
            .doc(recipeNameClaimId(oldName));
        _verifiedClaimPaths.remove(oldClaimReference.path);
        final sameClaim = oldClaimReference.path == newClaimReference.path;
        final oldClaim = await transaction.get(oldClaimReference);
        final newClaim = sameClaim
            ? oldClaim
            : await transaction.get(newClaimReference);

        if (newClaim.exists && newClaim.data()?['recipeId'] != recipe.id) {
          throw DuplicateRecipeException(recipe.name);
        }
        if (oldClaim.exists && oldClaim.data()?['recipeId'] != recipe.id) {
          throw RecipeServiceException(
            'Recipe name ownership is inconsistent.',
          );
        }

        final createdAt =
            oldData['createdAt'] as Timestamp? ?? recipe.createdAt;
        transaction.set(
          reference,
          _toDocumentData(
            recipe,
            id: recipe.id,
            userId: uid,
            createdAt: createdAt,
          ),
        );
        if (!newClaim.exists) {
          transaction.set(
            newClaimReference,
            _toNameClaimData(uid: uid, name: recipe.name, recipeId: recipe.id),
          );
        }
        if (!sameClaim && oldClaim.exists) {
          transaction.delete(oldClaimReference);
        }
      });
      _verifiedClaimPaths.add(newClaimReference.path);
      return await _readSavedRecipe(reference);
    } on FirebaseException catch (error) {
      throw RecipeServiceException.fromFirebase(error);
    }
  }

  @override
  Future<void> deleteRecipe(String recipeId) async {
    final uid = _requireUid();
    final reference = _recipes.doc(recipeId);

    try {
      await _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(reference);
        final data = snapshot.data();
        if (!snapshot.exists || data == null || data['userId'] != uid) {
          throw RecipeNotFoundException(recipeId);
        }
        final claimReference = _nameClaimsFor(uid)
            .doc(recipeNameClaimId(data['name'] as String));
        final claim = await transaction.get(claimReference);
        if (claim.exists && claim.data()?['recipeId'] != recipeId) {
          throw RecipeServiceException(
            'Recipe name ownership is inconsistent.',
          );
        }
        transaction.delete(reference);
        if (claim.exists) transaction.delete(claimReference);
        _verifiedClaimPaths.remove(claimReference.path);
      });
    } on FirebaseException catch (error) {
      throw RecipeServiceException.fromFirebase(error);
    }
  }

  @override
  Future<Recipe> toggleFavorite(String recipeId) async {
    final uid = _requireUid();
    final reference = _recipes.doc(recipeId);
    String? verifiedClaimPath;

    try {
      await _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(reference);
        final data = snapshot.data();
        if (!snapshot.exists || data == null || data['userId'] != uid) {
          throw RecipeNotFoundException(recipeId);
        }

        final name = data['name'] as String;
        final claimReference = _nameClaimsFor(uid).doc(recipeNameClaimId(name));
        verifiedClaimPath = claimReference.path;
        final claim = await transaction.get(claimReference);
        if (claim.exists && claim.data()?['recipeId'] != recipeId) {
          throw RecipeServiceException(
            'Recipe name ownership is inconsistent.',
          );
        }
        if (!claim.exists) {
          transaction.set(
            claimReference,
            _toNameClaimData(uid: uid, name: name, recipeId: recipeId),
          );
        }
        transaction.update(reference, {
          'favorite': !(data['favorite'] as bool? ?? false),
        });
      });
      if (verifiedClaimPath != null) {
        _verifiedClaimPaths.add(verifiedClaimPath!);
      }
      return await _readSavedRecipe(reference);
    } on FirebaseException catch (error) {
      throw RecipeServiceException.fromFirebase(error);
    }
  }

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const RecipeServiceException('Sign in before accessing recipes.');
    }
    return uid;
  }

  Future<Recipe> _readSavedRecipe(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    return Recipe.fromFirestore(snapshot);
  }

  Map<String, dynamic> _toDocumentData(
    Recipe recipe, {
    required String id,
    required String userId,
    required Object createdAt,
  }) => {
    'id': id,
    'userId': userId,
    'name': recipe.name,
    'category': recipe.category,
    'difficulty': recipe.difficulty,
    'cookTime': recipe.cookTime,
    if (recipe.servings != null) 'servings': recipe.servings,
    'favorite': recipe.favorite,
    'notes': recipe.notes,
    'createdAt': createdAt,
  };

  Map<String, dynamic> _toNameClaimData({
    required String uid,
    required String name,
    required String recipeId,
  }) => {
    'userId': uid,
    'normalizedName': name.trim().toLowerCase(),
    'recipeId': recipeId,
  };

  Future<void> _ensureNameClaims(List<Recipe> recipes, String uid) async {
    for (final recipe in recipes) {
      final reference = _nameClaimsFor(uid).doc(recipeNameClaimId(recipe.name));
      if (_verifiedClaimPaths.contains(reference.path)) continue;
      await _firestore.runTransaction<void>((transaction) async {
        final claim = await transaction.get(reference);
        if (claim.exists) {
          if (claim.data()?['recipeId'] != recipe.id) {
            throw DuplicateRecipeException(recipe.name);
          }
          return;
        }
        transaction.set(
          reference,
          _toNameClaimData(uid: uid, name: recipe.name, recipeId: recipe.id),
        );
      });
      _verifiedClaimPaths.add(reference.path);
    }
  }

  /// Normalized per-user name key used by the companion uniqueness claim.
  static String recipeNameClaimId(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll('%', '%25')
        .replaceAll('/', '%2F');
  }
}

class DuplicateRecipeException implements Exception {
  const DuplicateRecipeException(this.name);

  final String name;

  @override
  String toString() => 'A recipe named "$name" already exists.';
}

class RecipeNotFoundException implements Exception {
  const RecipeNotFoundException(this.recipeId);

  final String recipeId;

  @override
  String toString() => 'Recipe $recipeId was not found.';
}

class RecipeServiceException implements Exception {
  const RecipeServiceException(this.message);

  factory RecipeServiceException.fromFirebase(FirebaseException error) =>
      RecipeServiceException(error.message ?? 'Firestore operation failed.');

  final String message;

  @override
  String toString() => message;
}
