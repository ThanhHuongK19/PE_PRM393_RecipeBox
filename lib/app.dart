import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/firebase/firebase_services.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/services/auth_service.dart';
import 'features/home/screens/home_screen.dart';
import 'features/recipes/screens/recipe_list_screen.dart';
import 'core/widgets/loading_view.dart';
import 'features/recipes/providers/recipe_provider.dart';
import 'features/recipes/repositories/recipe_repository.dart';
import 'features/recipes/services/recipe_service.dart';

class RecipeBoxApp extends StatelessWidget {
  const RecipeBoxApp({required this.firebaseApp, super.key});

  final FirebaseApp firebaseApp;

  @override
  Widget build(BuildContext context) {
    return Provider<FirebaseServices>(
      create: (_) => FirebaseServices.forApp(firebaseApp),
      child: MultiProvider(
        providers: [
          Provider<AuthService>(
            create: (context) =>
                AuthService(context.read<FirebaseServices>().auth),
          ),
          Provider<AuthRepository>(
            create: (context) => AuthRepository(context.read<AuthService>()),
          ),
          Provider<RecipeService>(
            create: (context) => FirestoreRecipeService(
              database: context.read<FirebaseServices>().firestore,
              firebaseAuth: context.read<FirebaseServices>().auth,
            ),
          ),
          Provider<RecipeRepository>(
            create: (context) =>
                RecipeRepository(recipeService: context.read<RecipeService>()),
          ),
          ChangeNotifierProvider<RecipeProvider>(
            create: (context) => RecipeProvider(
              repository: context.read<RecipeRepository>(),
            ),
          ),
          ChangeNotifierProvider<AuthProvider>(
            lazy: false,
            create: (context) =>
                AuthProvider(repository: context.read<AuthRepository>()),
          ),
        ],
        child: MaterialApp(
          title: 'RecipeBox',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return switch (auth.status) {
          AuthStatus.checking => const Scaffold(body: LoadingView()),
          AuthStatus.signedOut => const HomeScreen(),
          AuthStatus.signedIn => const RecipeListScreen(),
        };
      },
    );
  }
}
