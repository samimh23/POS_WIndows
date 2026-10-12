import 'dart:convert';
import 'dart:io';
import '../../models/pos_data.dart';

abstract class PosRepository {
  Future<PosData?> load();
  Future<void> save(PosData data);
  String? get warning;
}

/// Immutable generations: write + flush a temporary file, then publish by rename.
/// Keep the previous generation for crash/corruption recovery. Never overwrite it.
class JsonPosRepository implements PosRepository {
  JsonPosRepository(this.directory);
  final Directory directory;
  File? _lock;
  RandomAccessFile? _handle;
  int _generation = 0;
  @override
  String? warning;
  Future<void> initialize() async {
    await directory.create(recursive: true);
    _lock = File('${directory.path}/session.lock');
    _handle = await _lock!.open(mode: FileMode.append);
    try {
      await _handle!.lock(FileLock.exclusive);
    } catch (_) {
      await _handle!.close();
      _handle = null;
      throw StateError(
        'Smart POS is already running. Close the other instance first.',
      );
    }
  }

  Future<void> close() async {
    await _handle?.close();
    _handle = null;
  }

  Future<List<File>> _files() async =>
      (await directory.list().toList())
          .whereType<File>()
          .where((f) => RegExp(r'state-\d+\.json$').hasMatch(f.path))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
  @override
  Future<PosData?> load() async {
    final files = await _files();
    if (files.isEmpty) {
      return null;
    }
    for (final file in files) {
      final n = int.parse(
        RegExp(r'state-(\d+)\.json$').firstMatch(file.path)!.group(1)!,
      );
      if (n > _generation) {
        _generation = n;
      }
      try {
        return PosData.fromJson(jsonDecode(await file.readAsString()) as Json);
      } catch (_) {
        warning =
            'A damaged data file was skipped. Recovered the previous saved snapshot. Original files were preserved.';
      }
    }
    throw StateError(
      'No readable data snapshot. Your files were preserved at ${directory.path}. Restore a valid backup before starting.',
    );
  }

  @override
  Future<void> save(PosData data) async {
    data.validate();
    final filename =
        'state-${(++_generation).toString().padLeft(12, '0')}.json';
    final temporary = File('${directory.path}/$filename.tmp');
    await temporary.writeAsString(jsonEncode(data.toJson()), flush: true);
    await temporary.rename('${directory.path}/$filename');
    // Cleanup is best-effort after the commit. A cleanup failure cannot undo it.
    if (warning == null) {
      try {
        final files = await _files();
        for (final old in files.skip(2)) {
          await old.delete();
        }
      } catch (_) {
        /* Retaining extra backups is safe. */
      }
    }
  }
}
