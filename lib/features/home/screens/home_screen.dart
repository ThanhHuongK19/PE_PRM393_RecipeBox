import 'package:flutter/material.dart';

import '../../auth/screens/login_screen.dart';
import '../../auth/screens/register_screen.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../widgets/home_feature_card.dart';

/// Public welcome screen shown while no Firebase user is signed in.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RecipeBox'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: AppSpacing.screenPadding,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 40,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'RecipeBox',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your personal space to save, organize, and revisit the meals you love.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Login',
                  icon: Icons.login_rounded,
                  onPressed: () => _open(context, const LoginScreen()),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _open(context, const RegisterScreen()),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Register'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Made for the way you cook',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const HomeFeatureCard(
                  icon: Icons.bookmark_add_outlined,
                  title: 'Save your recipes',
                  description: 'Keep your go-to dishes together in one place.',
                ),
                const HomeFeatureCard(
                  icon: Icons.timer_outlined,
                  title: 'Sort by cooking time',
                  description: 'Find a meal that fits the time you have.',
                ),
                const HomeFeatureCard(
                  icon: Icons.favorite_border_rounded,
                  title: 'Mark your favorites',
                  description: 'Make the recipes you love easy to find again.',
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}
