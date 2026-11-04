import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise_catalogs.dart';
import 'exercises_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER  (keepAlive = true → vive mientras la app esté en memoria)
// ─────────────────────────────────────────────────────────────────────────────

final catalogsProvider = AsyncNotifierProvider<CatalogsNotifier, ExerciseCatalogs>(
  CatalogsNotifier.new,
);

class CatalogsNotifier extends AsyncNotifier<ExerciseCatalogs> {
  @override
  Future<ExerciseCatalogs> build() =>
      ref.watch(exerciseRepositoryProvider).getCatalogs();

  /// Llama a este método si necesitas forzar una recarga desde el servidor
  /// (por ejemplo, tras crear un nuevo item de catálogo desde un panel de admin).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(exerciseRepositoryProvider).getCatalogs(),
    );
  }
}