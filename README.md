# osaka

Blog-aware static code generator for Jekyll-style Markdown posts with Flutter.

## Getting Started

This project is a starting point for a Dart
[package](https://flutter.dev/developing-packages/),
a library module containing code that can be shared easily across
multiple Flutter or Dart projects.

For help getting started with Flutter, view our 
[online documentation](https://flutter.dev/docs), which offers tutorials, 
samples, guidance on mobile development, and a full API reference.

## Usage

Add `build_runner: any` and `osaka: any` to `dev_dependencies`, have some posts under `assets/posts`, run `flutter pub run build_runner build --delete-conflicting-outputs`, build with `flutter build web` and run `flutter pub run tool/osaka.dart`.
