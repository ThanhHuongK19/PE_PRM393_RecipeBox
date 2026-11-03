import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recipe_box/features/recipes/models/recipe.dart';
import 'package:recipe_box/features/recipes/services/recipe_service.dart';

import 'package:recipe_box/firebase_options.dart';

const _authEmulator = String.fromEnvironment(
  'FIREBASE_AUTH_EMULATOR_HOST',
  defaultValue: '10.0.2.2:9099',
);
const _firestoreEmulator = String.fromEnvironment(
  'FIRESTORE_EMULATOR_HOST',
  defaultValue: '10.0.2.2:8080',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuth auth;
  late FirebaseFirestore firestore;
  late FirestoreRecipeService service;
  late String testSuffix;

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    auth = FirebaseAuth.instance;
    final authAddress = _parseAddress(_authEmulator);
    await auth.useAuthEmulator(authAddress.$1, authAddress.$2);

    firestore = FirebaseFirestore.instance;
    final firestoreAddress = _parseAddress(_firestoreEmulator);
    firestore.useFirestoreEmulator(firestoreAddress.$1, firestoreAddress.$2);

    testSuffix = DateTime.now().microsecondsSinceEpoch.toString();
    await auth.createUserWithEmailAndPassword(
      email: 'recipe-test-$testSuffix@example.test',
      password: 'test-password-$testSuffix',
    );

    service = FirestoreRecipeService(database: firestore, firebaseAuth: auth);
  });

  tearDownAll(() async {
    if (auth.currentUser != null) await auth.signOut();
  });

  testWidgets('Firestore CRUD operations and live snapshots work', (
    tester,
  ) async {
    final original = Recipe(
      id: 'ignored-ui-id',
      userId: 'untrusted-ui-user',
      name: 'CRUD Soup $testSuffix',
      category: 'Dinner',
      difficulty: 'Easy',
      cookTime: 20,
      servings: 2,
    );

    final added = await service.addRecipe(original);
    expect(added.id, isNotEmpty);
    expect(
      (await firestore.collection('recipes').doc(added.id).get()).data()?['id'],
      added.id,
    );
    expect(added.userId, auth.currentUser!.uid);
    expect(added.createdAt, isA<Timestamp>());
    expect((await service.getRecipes()).single.id, added.id);
    expect((await service.watchRecipes().first).single.id, added.id);

    final updated = await service.updateRecipe(
      added.copyWith(
        name: 'Updated Soup $testSuffix',
        cookTime: 30,
        servings: null,
      ),
    );
    expect(updated.id, added.id);
    expect(updated.name, 'Updated Soup $testSuffix');
    expect(updated.cookTime, 30);
    expect(updated.servings, isNull);
    expect(updated.createdAt, added.createdAt);

    final favorited = await service.toggleFavorite(updated.id);
    expect(favorited.favorite, isTrue);

    await service.deleteRecipe(favorited.id);
    expect(await service.getRecipes(), isEmpty);

    final recreated = await service.addRecipe(original);
    expect(recreated.name, original.name);
    expect(recreated.id, isNot(added.id));
    await service.deleteRecipe(recreated.id);
    expect(await service.getRecipes(), isEmpty);
  });

  testWidgets('case-insensitive duplicates are rejected', (tester) async {
    final name = 'Pho Bo $testSuffix';
    final added = await service.addRecipe(
      Recipe(
        id: 'ignored-id',
        userId: 'ignored-user',
        name: name,
        category: 'Dinner',
        difficulty: 'Medium',
        cookTime: 45,
      ),
    );

    expect(
      FirestoreRecipeService.recipeNameClaimId(name),
      FirestoreRecipeService.recipeNameClaimId(name.toLowerCase()),
    );
    await expectLater(
      service.addRecipe(
        Recipe(
          id: 'another-ignored-id',
          userId: auth.currentUser!.uid,
          name: name.toLowerCase(),
          category: 'Dinner',
          difficulty: 'Easy',
          cookTime: 10,
        ),
      ),
      throwsA(isA<DuplicateRecipeException>()),
    );

    // A direct write with a different document ID is rejected by the rules
    // rules, even if its userId and other fields look valid.
    await expectLater(
      _writeRecipeAndClaim(
        firestore,
        uid: auth.currentUser!.uid,
        recipeId: 'direct-$testSuffix',
        data: _validRecipeData(
          id: 'direct-$testSuffix',
          uid: auth.currentUser!.uid,
          name: name.toLowerCase(),
        )..['cookTime'] = 10,
      ),
      throwsA(isA<FirebaseException>()),
    );

    await service.deleteRecipe(added.id);
  });

  testWidgets('rename keeps the recipe ID and rejects a claimed name', (
    tester,
  ) async {
    final first = await service.addRecipe(
      Recipe(
        id: '',
        userId: '',
        name: 'First rename target $testSuffix',
        category: 'Lunch',
        difficulty: 'Easy',
        cookTime: 12,
      ),
    );
    final second = await service.addRecipe(
      Recipe(
        id: '',
        userId: '',
        name: 'Second rename target $testSuffix',
        category: 'Dinner',
        difficulty: 'Medium',
        cookTime: 35,
      ),
    );

    await expectLater(
      service.updateRecipe(first.copyWith(name: second.name.toUpperCase())),
      throwsA(isA<DuplicateRecipeException>()),
    );
    final updated = await service.updateRecipe(
      first.copyWith(name: 'Renamed target $testSuffix', cookTime: 50),
    );
    expect(updated.id, first.id);
    expect(updated.name, 'Renamed target $testSuffix');
    expect(updated.cookTime, 50);

    await service.deleteRecipe(updated.id);
    await service.deleteRecipe(second.id);
  });

  testWidgets('rules deny unauthenticated reads and writes', (tester) async {
    final name = 'Private $testSuffix';
    final recipe = await service.addRecipe(
      Recipe(
        id: '',
        userId: '',
        name: name,
        category: 'Dinner',
        difficulty: 'Easy',
        cookTime: 20,
      ),
    );
    final savedReference = firestore.collection('recipes').doc(recipe.id);
    await auth.signOut();

    await expectLater(savedReference.get(), throwsA(isA<FirebaseException>()));
    await expectLater(
      firestore.collection('recipes').get(),
      throwsA(isA<FirebaseException>()),
    );
    await expectLater(
      firestore.collection('recipes').doc('anonymous-$testSuffix').set(
        _validRecipeData(
          id: 'anonymous-$testSuffix',
          uid: 'anonymous',
          name: 'Anonymous $testSuffix',
        ),
      ),
      throwsA(isA<FirebaseException>()),
    );

    await auth.signInWithEmailAndPassword(
      email: 'recipe-test-$testSuffix@example.test',
      password: 'test-password-$testSuffix',
    );
    await service.deleteRecipe(recipe.id);
  });

  testWidgets('rules deny cross-user reads, updates, and deletes', (
    tester,
  ) async {
    final ownerUid = auth.currentUser!.uid;
    final ownerRecipe = await service.addRecipe(
      Recipe(
        id: '',
        userId: '',
        name: 'Owner recipe $testSuffix',
        category: 'Lunch',
        difficulty: 'Easy',
        cookTime: 15,
      ),
    );

    await auth.signOut();
    await auth.createUserWithEmailAndPassword(
      email: 'other-user-$testSuffix@example.test',
      password: 'other-password-$testSuffix',
    );
    final ownerReference = firestore.collection('recipes').doc(ownerRecipe.id);
    await expectLater(ownerReference.get(), throwsA(isA<FirebaseException>()));
    await expectLater(
      firestore
          .collection('recipes')
          .where('userId', isEqualTo: ownerUid)
          .get(),
      throwsA(isA<FirebaseException>()),
    );
    await expectLater(
      ownerReference.update({'name': 'Stolen $testSuffix'}),
      throwsA(isA<FirebaseException>()),
    );
    await expectLater(
      ownerReference.delete(),
      throwsA(isA<FirebaseException>()),
    );
    await expectLater(
      firestore.collection('recipes').doc(ownerRecipe.id).set(
        _validRecipeData(
          id: ownerRecipe.id,
          uid: auth.currentUser!.uid,
          name: ownerRecipe.name,
        ),
      ),
      throwsA(isA<FirebaseException>()),
    );

    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: 'recipe-test-$testSuffix@example.test',
      password: 'test-password-$testSuffix',
    );
    expect(auth.currentUser!.uid, ownerUid);
    await service.deleteRecipe(ownerRecipe.id);
  });

  testWidgets('rules reject invalid recipe fields', (tester) async {
    final uid = auth.currentUser!.uid;
    var serial = 0;

    Future<void> expectInvalid(Map<String, dynamic> overrides) async {
      serial++;
      final name = 'Rules test $testSuffix $serial';
      final id = 'invalid-$testSuffix-$serial';
      await expectLater(
        _writeRecipeAndClaim(
          firestore,
          uid: uid,
          recipeId: id,
          data: {
            ..._validRecipeData(id: id, uid: uid, name: name),
            ...overrides,
          },
        ),
        throwsA(isA<FirebaseException>()),
      );
    }

    await expectInvalid({'userId': 'somebody-else'});
    await expectInvalid({'category': 'Brunch'});
    await expectInvalid({'difficulty': 'Expert'});
    await expectInvalid({'cookTime': 0});
    await expectInvalid({'cookTime': 601});
    await expectInvalid({'cookTime': '20'});
    await expectInvalid({'servings': 0});
    await expectInvalid({'servings': 21});
    await expectInvalid({'servings': '2'});
    await expectInvalid({'notes': 'x' * 301});
    await expectInvalid({'notes': 42});
    await expectInvalid({'favorite': 'false'});
    await expectInvalid({'createdAt': 'not-a-timestamp'});
    await expectInvalid({'unapprovedField': true});
    final tooLongName = 'N' * 81;
    final tooLongId = 'too-long-$testSuffix';
    await expectLater(
      _writeRecipeAndClaim(
        firestore,
        uid: uid,
        recipeId: tooLongId,
        data: _validRecipeData(id: tooLongId, uid: uid, name: tooLongName),
      ),
      throwsA(isA<FirebaseException>()),
    );

    final missingFieldName = 'Missing field $testSuffix';
    final missingFieldId = 'missing-field-$testSuffix';
    final missingFieldData = _validRecipeData(
      id: missingFieldId,
      uid: uid,
      name: missingFieldName,
    )..remove('difficulty');
    await expectLater(
      _writeRecipeAndClaim(
        firestore,
        uid: uid,
        recipeId: missingFieldId,
        data: missingFieldData,
      ),
      throwsA(isA<FirebaseException>()),
    );

    final emptyNameId = 'empty-name-$testSuffix';
    await expectLater(
      _writeRecipeAndClaim(
        firestore,
        uid: uid,
        recipeId: emptyNameId,
        data: _validRecipeData(id: emptyNameId, uid: uid, name: ''),
      ),
      throwsA(isA<FirebaseException>()),
    );

    final whitespaceName = '   ';
    final whitespaceId = 'whitespace-name-$testSuffix';
    await expectLater(
      _writeRecipeAndClaim(
        firestore,
        uid: uid,
        recipeId: whitespaceId,
        data: _validRecipeData(id: whitespaceId, uid: uid, name: whitespaceName),
      ),
      throwsA(isA<FirebaseException>()),
    );
  });

  testWidgets('rules reject duplicate case variants at another document ID', (
    tester,
  ) async {
    final uid = auth.currentUser!.uid;
    final originalName = 'Case Sensitive $testSuffix';
    final original = await service.addRecipe(
      Recipe(
        id: '',
        userId: '',
        name: originalName,
        category: 'Dessert',
        difficulty: 'Medium',
        cookTime: 25,
      ),
    );
    final lowerName = originalName.toLowerCase();
    final nonCanonicalId = 'duplicate-$testSuffix';
    expect(
      FirestoreRecipeService.recipeNameClaimId(originalName),
      FirestoreRecipeService.recipeNameClaimId(lowerName),
    );

    await expectLater(
      _writeRecipeAndClaim(
        firestore,
        uid: uid,
        recipeId: nonCanonicalId,
        data: _validRecipeData(id: nonCanonicalId, uid: uid, name: lowerName),
      ),
      throwsA(isA<FirebaseException>()),
    );
    await service.deleteRecipe(original.id);
  });
}

Map<String, dynamic> _validRecipeData({
  required String id,
  required String uid,
  required String name,
}) => {
  'id': id,
  'userId': uid,
  'name': name,
  'category': 'Dinner',
  'difficulty': 'Easy',
  'cookTime': 20,
  'favorite': false,
  'notes': '',
  'createdAt': Timestamp.now(),
};

Future<void> _writeRecipeAndClaim(
  FirebaseFirestore firestore, {
  required String uid,
  required String recipeId,
  required Map<String, dynamic> data,
}) async {
  final name = data['name'] as String;
  final batch = firestore.batch();
  batch.set(firestore.collection('recipes').doc(recipeId), data);
  batch.set(
    firestore
        .collection('users')
        .doc(uid)
        .collection('recipeNameClaims')
        .doc(FirestoreRecipeService.recipeNameClaimId(name)),
    {
      'userId': uid,
      'normalizedName': name.trim().toLowerCase(),
      'recipeId': recipeId,
    },
  );
  await batch.commit();
}

(String, int) _parseAddress(String value) {
  final separator = value.lastIndexOf(':');
  if (separator < 1) throw FormatException('Expected host:port, got $value');
  return (
    value.substring(0, separator),
    int.parse(value.substring(separator + 1)),
  );
}
