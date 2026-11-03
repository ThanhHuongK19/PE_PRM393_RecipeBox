import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../services/recipe_service.dart';
import '../widgets/recipe_form.dart';

class AddRecipeScreen extends StatelessWidget {
  const AddRecipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Recipe')),
      body: SafeArea(
        child: RecipeForm(
          onSubmit: (formData) async {
            final uid = context.read<AuthProvider>().uid;
            if (uid == null) {
              throw const RecipeServiceException(
                'Sign in before adding recipes.',
              );
            }

            await context.read<RecipeProvider>().addRecipe(
              Recipe(
                id: '',
                userId: uid,
                name: formData.name,
                category: formData.category,
                difficulty: formData.difficulty,
                cookTime: formData.cookTime,
                servings: formData.servings,
                notes: formData.notes,
              ),
            );
          },
        ),
      ),
    );
  }
}
