import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/recipe_options.dart';
import '../../../core/validators/form_validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../models/recipe.dart';

class RecipeFormData {
  const RecipeFormData({
    required this.name,
    required this.category,
    required this.difficulty,
    required this.cookTime,
    required this.servings,
    required this.notes,
  });

  final String name;
  final String category;
  final String difficulty;
  final int cookTime;
  final int? servings;
  final String notes;
}

/// Reusable recipe editor form. Supply [initialRecipe] to populate it for edits.
class RecipeForm extends StatefulWidget {
  const RecipeForm({
    required this.onSubmit,
    this.initialRecipe,
    this.successMessage = 'Recipe added',
    this.clearAfterSubmit = true,
    this.submitLabel,
    this.cancelLabel = 'Cancel',
    this.onCancel,
    super.key,
  });

  final Future<void> Function(RecipeFormData data) onSubmit;
  final Recipe? initialRecipe;
  final String successMessage;
  final bool clearAfterSubmit;
  final String? submitLabel;
  final String cancelLabel;
  final VoidCallback? onCancel;

  @override
  State<RecipeForm> createState() => _RecipeFormState();
}

class _RecipeFormState extends State<RecipeForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cookTimeController;
  late final TextEditingController _servingsController;
  late final TextEditingController _notesController;

  String? _category;
  String? _difficulty;
  bool _hasSubmitted = false;
  bool _isSubmitting = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    final recipe = widget.initialRecipe;
    _nameController = TextEditingController(text: recipe?.name ?? '');
    _cookTimeController = TextEditingController(
      text: recipe == null ? '' : '${recipe.cookTime}',
    );
    _servingsController = TextEditingController(
      text: recipe?.servings == null ? '' : '${recipe!.servings}',
    );
    _notesController = TextEditingController(text: recipe?.notes ?? '');
    _category = recipe?.category;
    _difficulty = recipe?.difficulty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _fieldChanged(String _) {
    if (_serverError != null) setState(() => _serverError = null);
    if (_hasSubmitted) _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() {
      _hasSubmitted = true;
      _serverError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final data = RecipeFormData(
      name: _nameController.text.trim(),
      category: _category!,
      difficulty: _difficulty!,
      cookTime: int.parse(_cookTimeController.text.trim()),
      servings: _servingsController.text.trim().isEmpty
          ? null
          : int.parse(_servingsController.text.trim()),
      notes: _notesController.text,
    );

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(data);
      if (!mounted) return;
      if (widget.clearAfterSubmit) {
        _formKey.currentState?.reset();
        _nameController.clear();
        _cookTimeController.clear();
        _servingsController.clear();
        _notesController.clear();
        setState(() {
          _category = null;
          _difficulty = null;
          _hasSubmitted = false;
          _serverError = null;
        });
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.successMessage)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _serverError = _errorText(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _errorText(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _hasSubmitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  label: 'Name',
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: FormValidators.recipeName,
                  onChanged: _fieldChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  hint: const Text('Choose category'),
                  items: RecipeCategory.values
                      .map(
                        (category) => DropdownMenuItem<String>(
                          value: category.label,
                          child: Text(category.label),
                        ),
                      )
                      .toList(growable: false),
                  validator: FormValidators.category,
                  onChanged: (value) {
                    setState(() {
                      _category = value;
                      _serverError = null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _difficulty,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  hint: const Text('Choose difficulty'),
                  items: RecipeDifficulty.values
                      .map(
                        (difficulty) => DropdownMenuItem<String>(
                          value: difficulty.label,
                          child: Text(difficulty.label),
                        ),
                      )
                      .toList(growable: false),
                  validator: FormValidators.difficulty,
                  onChanged: (value) {
                    setState(() {
                      _difficulty = value;
                      _serverError = null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Cook time',
                  controller: _cookTimeController,
                  validator: FormValidators.cookTime,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onChanged: _fieldChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Servings (optional)',
                  controller: _servingsController,
                  validator: FormValidators.servings,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onChanged: _fieldChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Notes (optional)',
                  controller: _notesController,
                  validator: FormValidators.notes,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  onChanged: _fieldChanged,
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final submitButton = AppButton(
                      label:
                          widget.submitLabel ??
                          (widget.initialRecipe == null
                              ? 'Add Recipe'
                              : 'Save Recipe'),
                      icon: widget.initialRecipe == null
                          ? Icons.add_rounded
                          : Icons.save_outlined,
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    );
                    final cancelButton = OutlinedButton(
                      onPressed: _isSubmitting ? null : widget.onCancel,
                      child: Text(widget.cancelLabel),
                    );

                    if (widget.onCancel == null) return submitButton;
                    if (constraints.maxWidth < 400) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          submitButton,
                          const SizedBox(height: AppSpacing.sm),
                          cancelButton,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: submitButton),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: cancelButton),
                      ],
                    );
                  },
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _serverError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
