import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vellum_app/app.dart';
import 'package:vellum_app/core/db/vellum_db.dart';
import 'package:vellum_app/core/storage/app_storage.dart';
import 'package:vellum_app/data/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final storage = AppStorage(prefs);
  final db = await VellumDb.open();

  final container = ProviderContainer(
    overrides: [
      appStorageProvider.overrideWithValue(storage),
      vellumDbProvider.overrideWithValue(db),
    ],
  );

  await container.read(authProvider.notifier).bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VellumApp(),
    ),
  );
}
