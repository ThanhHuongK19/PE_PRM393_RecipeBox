# RecipeBox

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase setup

The Android client configuration in `android/app/google-services.json` and the
generated options in `lib/firebase_options.dart` target Firebase project
`prm393-final`. Keep these files in sync with the same Firebase app when
replacing client configuration.

In Firebase Console, open **Authentication → Sign-in method** and enable
**Email/Password** for this project. Create the Firestore database for the
project before using recipe data features. These project settings cannot be
enabled from the Flutter client.

Recipe documents use generated IDs that remain unchanged when a recipe is
edited. Case-insensitive name uniqueness is enforced with a companion claim at
`users/{uid}/recipeNameClaims/{lowercased-name}`. Recipe and claim changes must
be written atomically; `firestore.rules` checks the paired post-write state, so
direct-write tests should batch the recipe and claim writes together. Rules do
not scan the recipes collection for duplicates.

## Firestore repository integration test

The real Firestore CRUD test runs against Firebase emulators (it does not use
the production project):

1. Start Auth and Firestore emulators with
   `firebase emulators:start --only auth,firestore --project prm393-final` so
   the emulator rules and client Firebase configuration use the same project ID.
2. Run `flutter test integration_test/recipe_firestore_test.dart -d <device-id>`
   on an Android emulator. The default emulator hosts are `10.0.2.2:9099` for
   Auth and `10.0.2.2:8080` for Firestore; override them with Dart defines when
   needed.
