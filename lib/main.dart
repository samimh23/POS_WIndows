import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'core/navigation/app_shell.dart';
import 'core/storage/pos_repository.dart';
import 'core/theme/pos_theme.dart';
import 'features/orders/pos_controller.dart';
import 'models/pos_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final custom = Platform.environment['SMART_POS_DATA_DIR'];
    final support =
        custom ?? '${(await getApplicationSupportDirectory()).path}/SmartPOS';
    final repository = JsonPosRepository(Directory(support));
    await repository.initialize();
    var data = await repository.load();
    if (data == null) {
      data = PosData.seed();
      await repository.save(data);
    }
    final controller = PosController(repository, data);
    await controller.releaseEmptyBills();
    runApp(
      ProviderScope(
        overrides: [posProvider.overrideWith((ref) => controller)],
        child: const SmartPosApp(),
      ),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        theme: posTheme(false),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 620,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_off_outlined, size: 56),
                    const SizedBox(height: 24),
                    const Text(
                      'Local storage could not be opened',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 16),
                    Text('$error'),
                    const SizedBox(height: 16),
                    const Text(
                      'Close any other Smart POS instance, check folder permissions, or restore your backup. Restart the app to retry. Existing files have been preserved.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SmartPosApp extends ConsumerWidget {
  const SmartPosApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'Smart POS',
    debugShowCheckedModeBanner: false,
    theme: posTheme(ref.watch(posProvider).data.settings.dark),
    home: const AppShell(),
  );
}
