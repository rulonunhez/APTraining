import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/logging/app_error_reporter.dart';
import '../../../core/widgets/app_loader.dart';
import '../data/exercise_remote_data_source.dart';
import '../models/exercise.dart';
import '../models/exercise_catalogs.dart';
import '../models/exercise_video_source.dart';
import '../models/exercise_write_request.dart';
import '../providers/catalogs_provider.dart';
import '../providers/exercises_provider.dart';
import '../utils/exercise_video_playback_coordinator.dart';
import '../utils/video_lifecycle_playback.dart';
import '../utils/youtube_video_id.dart';
import '../widgets/exercise_form_fields.dart';
import '../widgets/youtube_exercise_player.dart';

final exerciseVideoControllerFactoryProvider =
    Provider<VideoPlayerController Function(Uri)>(
  (ref) => (uri) => VideoPlayerController.networkUrl(uri),
);

typedef YoutubePlayerBuilder = Widget Function({
  required String videoId,
  required bool vertical,
  required bool autoPlay,
});

final exerciseYoutubePlayerBuilderProvider = Provider<YoutubePlayerBuilder>(
  (ref) => ({required videoId, required vertical, required autoPlay}) =>
      YoutubeExercisePlayer(
        videoId: videoId,
        vertical: vertical,
        autoPlay: autoPlay,
      ),
);

/// Creates a new exercise or edits an existing one when [exerciseId] is set.
class ExerciseEditorScreen extends ConsumerStatefulWidget {
  const ExerciseEditorScreen({super.key, this.exerciseId});

  final String? exerciseId;

  @override
  ConsumerState<ExerciseEditorScreen> createState() =>
      _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends ConsumerState<ExerciseEditorScreen>
    with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  final _explanationController = TextEditingController();
  final _tipsController = TextEditingController();
  final _commonMistakesController = TextEditingController();
  final _youtubeUrlController = TextEditingController();

  VideoPlayerController? _videoPreviewController;
  final VideoLifecyclePlayback _videoLifecyclePlayback =
      VideoLifecyclePlayback();
  Timer? _hideControlsTimer;
  bool isLoadingVideo = false;
  bool _videoError = false;
  bool _showControls = false;
  double _currentSpeed = 1.0;
  final List<double> _speeds = [0.5, 1.0, 1.5, 2.0];
  File? selectedVideo;
  ExerciseVideoSource _videoSource = ExerciseVideoSource.none;
  int _videoLoadGeneration = 0;
  final Set<VideoPlayerController> _releasingVideoControllers = {};

  // Vídeo ya guardado en el backend (subido) y vídeo de YouTube a autoreproducir.
  String? _existingUploadUrl;
  String? _autoPlayYoutubeId;

  String? _exerciseTypeId;
  String? _movementPatternId;
  final Set<String> _primaryMuscleGroupIds = {};
  final Set<String> _secondaryMuscleGroupIds = {};
  final Set<String> _equipmentIds = {};

  bool _loading = false;
  String? _loadError;
  bool isSaving = false;

  bool get _isEditing => widget.exerciseId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isEditing) {
      _loading = true;
      unawaited(_loadExercise());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoLoadGeneration++;
    _hideControlsTimer?.cancel();
    _nameController.dispose();
    _explanationController.dispose();
    _tipsController.dispose();
    _commonMistakesController.dispose();
    _youtubeUrlController.dispose();
    final controller = _videoPreviewController;
    _videoPreviewController = null;
    if (controller != null) unawaited(_disposePreviewController(controller));
    ExerciseVideoPlaybackCoordinator.release(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _videoPreviewController;
    if (controller == null) return;
    final action = _videoLifecyclePlayback.handle(
      state,
      controller.value.isPlaying,
    );
    switch (action) {
      case VideoLifecycleAction.pause:
        controller.pause();
      case VideoLifecycleAction.resume:
        controller.play();
      case VideoLifecycleAction.none:
        break;
    }
  }

  // ── Carga del ejercicio ───────────────────────────────────────

  Future<void> _loadExercise() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final exercise = await ref
          .read(exercisesProvider.notifier)
          .getExercise(widget.exerciseId!);
      if (!mounted) return;
      _applyExercise(exercise);
      setState(() => _loading = false);
      if (_existingUploadUrl != null) {
        unawaited(_loadPreview(url: _existingUploadUrl));
      }
    } catch (error, stackTrace) {
      AppErrorReporter.recordHandled(
        error,
        stackTrace,
        context: 'Loading exercise',
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'No se pudo cargar el ejercicio';
        });
      }
    }
  }

  void _applyExercise(Exercise exercise) {
    _nameController.text = exercise.name;
    _explanationController.text = exercise.explanation ?? '';
    _tipsController.text = exercise.tips ?? '';
    _commonMistakesController.text = exercise.commonMistakes ?? '';
    _exerciseTypeId = exercise.exerciseTypeId;
    _movementPatternId = exercise.movementPatternId;
    _primaryMuscleGroupIds.addAll(exercise.primaryMuscleGroupIds);
    _secondaryMuscleGroupIds.addAll(exercise.secondaryMuscleGroupIds);
    _equipmentIds.addAll(exercise.equipmentIds);

    final videoUrl = exercise.videoUrl;
    final youtubeId = youtubeVideoIdFromUrl(videoUrl);
    if (youtubeId != null) {
      _videoSource = ExerciseVideoSource.youtube;
      _youtubeUrlController.text = videoUrl!;
      _autoPlayYoutubeId = youtubeId;
    } else if (videoUrl != null) {
      _videoSource = ExerciseVideoSource.upload;
      _existingUploadUrl = videoUrl;
      isLoadingVideo = true;
    }
  }

  // ── Vídeo ─────────────────────────────────────────────────────

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    if (await file.length() > maxVideoSizeBytes) {
      _showMessage(const VideoTooLargeException(maxVideoSizeBytes).message);
      return;
    }
    if (!mounted) return;
    setState(() {
      selectedVideo = file;
      _videoSource = ExerciseVideoSource.upload;
    });
    await _loadPreview(file: file);
  }

  Future<void> _loadPreview({File? file, String? url}) async {
    final generation = ++_videoLoadGeneration;
    setState(() {
      isLoadingVideo = true;
      _videoError = false;
    });

    final oldController = _videoPreviewController;
    _videoPreviewController = null;
    if (oldController != null) await _disposePreviewController(oldController);
    if (!mounted || generation != _videoLoadGeneration) return;

    final controller = file != null
        ? VideoPlayerController.file(file)
        : ref.read(exerciseVideoControllerFactoryProvider)(Uri.parse(url!));
    _videoPreviewController = controller;

    try {
      await controller.initialize();
      if (!mounted || generation != _videoLoadGeneration) {
        await _disposePreviewController(controller);
        return;
      }
      await controller.setLooping(true);
      if (!mounted || generation != _videoLoadGeneration) {
        await _disposePreviewController(controller);
        return;
      }
      await controller.play();
      if (!mounted || generation != _videoLoadGeneration) {
        await _disposePreviewController(controller);
        return;
      }
      unawaited(
        ExerciseVideoPlaybackCoordinator.claim(this, controller.pause),
      );
      _toggleControls();
    } catch (_) {
      if (identical(_videoPreviewController, controller)) {
        _videoPreviewController = null;
      }
      await _disposePreviewController(controller);
      if (mounted && generation == _videoLoadGeneration) {
        setState(() {
          isLoadingVideo = false;
          _videoError = true;
        });
      }
      return;
    }

    if (mounted && generation == _videoLoadGeneration) {
      setState(() => isLoadingVideo = false);
    }
  }

  void _retryVideo() {
    final file = selectedVideo;
    if (file != null) {
      unawaited(_loadPreview(file: file));
    } else if (_existingUploadUrl != null) {
      unawaited(_loadPreview(url: _existingUploadUrl));
    }
  }

  void _clearPreview() {
    final controller = _videoPreviewController;
    _videoPreviewController = null;
    _videoLoadGeneration++;
    _hideControlsTimer?.cancel();
    if (controller != null) unawaited(_disposePreviewController(controller));
    ExerciseVideoPlaybackCoordinator.release(this);
    selectedVideo = null;
    isLoadingVideo = false;
    _videoError = false;
    _showControls = false;
    _currentSpeed = 1.0;
  }

  void _removeVideo() {
    setState(() {
      _clearPreview();
      _videoSource = ExerciseVideoSource.none;
    });
  }

  void _onVideoSourceChanged(ExerciseVideoSource? source) {
    if (source == null || source == _videoSource) return;
    setState(() {
      if (source != ExerciseVideoSource.upload) _clearPreview();
      _videoSource = source;
    });
    if (source == ExerciseVideoSource.upload &&
        selectedVideo == null &&
        _existingUploadUrl != null) {
      unawaited(_loadPreview(url: _existingUploadUrl));
    }
  }

  Future<void> _disposePreviewController(
    VideoPlayerController controller,
  ) async {
    if (!_releasingVideoControllers.add(controller)) return;
    try {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        await controller.pause();
      }
    } catch (error) {
      debugPrint('Could not pause exercise preview: $error');
    }
    try {
      await controller.dispose();
    } catch (error) {
      debugPrint('Could not dispose exercise preview: $error');
    }
  }

  void _toggleControls() {
    if (!mounted) return;
    setState(() => _showControls = true);
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  Future<void> _togglePlayPause() async {
    final controller = _videoPreviewController;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      ExerciseVideoPlaybackCoordinator.release(this);
    } else {
      await ExerciseVideoPlaybackCoordinator.claim(this, controller.pause);
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  void _seek(int seconds) {
    final controller = _videoPreviewController;
    if (controller == null) return;
    final target = controller.value.position + Duration(seconds: seconds);
    final duration = controller.value.duration;
    final clamped = target.isNegative
        ? Duration.zero
        : target > duration
            ? duration
            : target;
    controller.seekTo(clamped);
  }

  void _cycleSpeed() {
    final next = (_speeds.indexOf(_currentSpeed) + 1) % _speeds.length;
    setState(() => _currentSpeed = _speeds[next]);
    _videoPreviewController?.setPlaybackSpeed(_currentSpeed);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Guardar ───────────────────────────────────────────────────

  Future<void> _saveExercise() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('El nombre es obligatorio');
      return;
    }
    if (_videoSource == ExerciseVideoSource.youtube &&
        youtubeVideoIdFromUrl(_youtubeUrlController.text) == null) {
      _showMessage('Introduce una URL válida de YouTube');
      return;
    }
    if (_videoSource == ExerciseVideoSource.upload &&
        selectedVideo == null &&
        _existingUploadUrl == null) {
      _showMessage('Selecciona el archivo de video');
      return;
    }

    setState(() => isSaving = true);

    final request = ExerciseWriteRequest(
      name: name,
      exerciseTypeId: int.tryParse(_exerciseTypeId ?? ''),
      movementPatternId: int.tryParse(_movementPatternId ?? ''),
      primaryMuscleGroupIds: _primaryMuscleGroupIds.map(int.parse).toList(),
      secondaryMuscleGroupIds: _secondaryMuscleGroupIds.map(int.parse).toList(),
      equipmentIds: _equipmentIds.map(int.parse).toList(),
      explanation: _optionalText(_explanationController.text),
      tips: _optionalText(_tipsController.text),
      commonMistakes: _optionalText(_commonMistakesController.text),
      videoSource: _videoSource,
      youtubeUrl: _videoSource == ExerciseVideoSource.youtube
          ? _optionalText(_youtubeUrlController.text)
          : null,
    );

    try {
      final notifier = ref.read(exercisesProvider.notifier);
      if (_isEditing) {
        await notifier.updateExercise(
          widget.exerciseId!,
          request,
          video: selectedVideo,
        );
      } else {
        await notifier.createExercise(request, video: selectedVideo);
      }
      if (!mounted) return;
      _showMessage(_isEditing ? 'Ejercicio actualizado' : 'Ejercicio creado');
      context.pop(true);
    } catch (error, stackTrace) {
      AppErrorReporter.recordHandled(
        error,
        stackTrace,
        context: _isEditing ? 'Updating exercise' : 'Creating exercise',
      );
      if (mounted) {
        _showMessage(
          _exerciseSaveErrorMessage(error),
          duration: const Duration(seconds: 6),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showMessage(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(milliseconds: 4000),
      ),
    );
  }

  String _exerciseSaveErrorMessage(Object error) {
    final action = _isEditing ? 'actualizar' : 'guardar';
    if (error is VideoTooLargeException) return error.message;
    if (error is TimeoutException) {
      return 'La subida tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.';
    }
    if (error is ExerciseApiException) {
      final requestId = error.requestId;
      final serverMessage = error.message;
      if (requestId != null) {
        return 'No se pudo $action el ejercicio. Referencia: $requestId'
            '${serverMessage == null ? '' : ' · $serverMessage'}';
      }
      if (serverMessage != null) return serverMessage;
    }
    return 'Error al $action el ejercicio. Consulta los logs de la app.';
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  // ── Secciones ─────────────────────────────────────────────────

  Widget _buildSingleSelect({
    required List<CatalogItem> items,
    required String? selectedId,
    required String hint,
    required ValueChanged<CatalogItem?> onChanged,
  }) {
    final selected = items.where((item) => item.id == selectedId).firstOrNull;
    return DropdownButtonFormField<CatalogItem>(
      initialValue: selected,
      hint: Text(hint),
      isExpanded: true,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item.name)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildPlayerArea() {
    switch (_videoSource) {
      case ExerciseVideoSource.youtube:
        final url = _youtubeUrlController.text;
        final videoId = youtubeVideoIdFromUrl(url);
        if (videoId == null) return const SizedBox.shrink();
        return ref.watch(exerciseYoutubePlayerBuilderProvider)(
          videoId: videoId,
          vertical: isYoutubeShortsUrl(url),
          autoPlay: videoId == _autoPlayYoutubeId,
        );
      case ExerciseVideoSource.upload:
        if (selectedVideo == null && _existingUploadUrl == null) {
          return const SizedBox.shrink();
        }
        return _buildUploadPlayer();
      case ExerciseVideoSource.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildUploadPlayer() {
    final controller = _videoPreviewController;

    if (isLoadingVideo) {
      return Container(
        width: double.infinity,
        height: 240,
        color: Colors.black,
        child: const Center(child: AppLoader(size: 64, color: Colors.white)),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return Container(
        width: double.infinity,
        height: 240,
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
            const SizedBox(height: 8),
            Text(
              _videoError ? 'No se pudo cargar el vídeo' : 'Sin vídeo',
              style: const TextStyle(color: Colors.white54),
            ),
            if (_videoError)
              TextButton.icon(
                onPressed: _retryVideo,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
          ],
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;

    return Container(
      width: double.infinity,
      color: Colors.black,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: GestureDetector(
            onTap: _toggleControls,
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(controller),
                  AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: controller,
                            builder: (_, val, __) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_fmt(val.position),
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11)),
                                  Text(_fmt(val.duration),
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                          VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            colors: VideoProgressColors(
                              playedColor: scheme.primary,
                              bufferedColor: Colors.white30,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Row(
                              children: [
                                _ControlButton(
                                    icon: Icons.replay_5,
                                    onTap: () => _seek(-5)),
                                _ControlButton(
                                  icon: controller.value.isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  onTap: _togglePlayPause,
                                  size: 40,
                                ),
                                _ControlButton(
                                    icon: Icons.forward_5,
                                    onTap: () => _seek(5)),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _cycleSpeed,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_currentSpeed}x',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _ControlButton(
                                    icon: Icons.video_library,
                                    onTap: _pickVideo,
                                    tooltip: 'Cambiar vídeo'),
                                _ControlButton(
                                    icon: Icons.delete_outline,
                                    onTap: _removeVideo,
                                    tooltip: 'Quitar vídeo'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard() {
    final youtubeVideoId = youtubeVideoIdFromUrl(_youtubeUrlController.text);
    final scheme = Theme.of(context).colorScheme;

    return ExerciseSectionCard(
      icon: Icons.videocam_outlined,
      title: 'Vídeo',
      subtitle: 'Sube un archivo o enlaza un vídeo de YouTube',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<ExerciseVideoSource>(
            initialValue: _videoSource,
            decoration: const InputDecoration(
              labelText: 'Forma de registrar el video',
            ),
            items: const [
              DropdownMenuItem(
                value: ExerciseVideoSource.none,
                child: Text('Sin video'),
              ),
              DropdownMenuItem(
                value: ExerciseVideoSource.upload,
                child: Text('Subir un archivo'),
              ),
              DropdownMenuItem(
                value: ExerciseVideoSource.youtube,
                child: Text('Enlace de YouTube'),
              ),
            ],
            onChanged: _onVideoSourceChanged,
          ),
          if (_videoSource == ExerciseVideoSource.youtube) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _youtubeUrlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'URL de YouTube',
                hintText: 'https://www.youtube.com/watch?v=...',
                errorText: _youtubeUrlController.text.trim().isEmpty ||
                        youtubeVideoId != null
                    ? null
                    : 'Introduce una URL válida de YouTube',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ] else if (_videoSource == ExerciseVideoSource.upload &&
              selectedVideo == null &&
              _existingUploadUrl == null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('Elegir vídeo de la galería'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: scheme.primary,
                side: BorderSide(color: scheme.outline),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<ExerciseCatalogs> catalogsAsync) {
    if (_loading) return const Center(child: AppLoader());

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadExercise,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPlayerArea(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExerciseSectionCard(
                  icon: Icons.fitness_center,
                  title: 'Nombre del ejercicio',
                  required: true,
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    maxLength: 255,
                    decoration: const InputDecoration(
                      hintText: 'Ej: Press de banca',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildVideoCard(),
                const SizedBox(height: 12),
                ...catalogsAsync.when(
                  loading: () => const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: AppLoader()),
                    ),
                  ],
                  error: (e, _) => [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.cloud_off,
                              size: 48, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          const Text(
                            'No se pudieron cargar los catálogos.\nComprueba tu conexión.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () =>
                                ref.read(catalogsProvider.notifier).refresh(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  data: _buildCatalogSections,
                ),
                FilledButton.icon(
                  onPressed: isSaving || _loading ? null : _saveExercise,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                      _isEditing ? 'Guardar cambios' : 'Crear ejercicio'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCatalogSections(ExerciseCatalogs catalogs) {
    return [
      ExerciseSectionCard(
        icon: Icons.category_outlined,
        title: 'Tipo de ejercicio',
        child: _buildSingleSelect(
          items: catalogs.exerciseTypes,
          selectedId: _exerciseTypeId,
          hint: 'Selecciona un tipo',
          onChanged: (v) => setState(() => _exerciseTypeId = v?.id),
        ),
      ),
      const SizedBox(height: 12),
      ExerciseSectionCard(
        icon: Icons.swap_vert_outlined,
        title: 'Patrón de movimiento',
        child: _buildSingleSelect(
          items: catalogs.movementPatterns,
          selectedId: _movementPatternId,
          hint: 'Selecciona un patrón',
          onChanged: (v) => setState(() => _movementPatternId = v?.id),
        ),
      ),
      const SizedBox(height: 12),
      ExerciseSectionCard(
        icon: Icons.sports_gymnastics,
        title: 'Músculos primarios',
        subtitle: 'Músculos principales trabajados',
        child: ExerciseMultiSelectChips(
          items: catalogs.muscleGroups,
          selectedIds: _primaryMuscleGroupIds,
          onToggle: (id, selected) => setState(() {
            if (_primaryMuscleGroupIds.contains(id)) {
              _primaryMuscleGroupIds.remove(id);
            } else {
              _primaryMuscleGroupIds.add(id);
              _secondaryMuscleGroupIds.remove(id);
            }
          }),
        ),
      ),
      const SizedBox(height: 12),
      ExerciseSectionCard(
        icon: Icons.sports_gymnastics_outlined,
        title: 'Músculos secundarios',
        subtitle: 'Músculos de apoyo o sinérgicos',
        child: ExerciseMultiSelectChips(
          items: catalogs.muscleGroups,
          selectedIds: _secondaryMuscleGroupIds,
          onToggle: (id, selected) => setState(() {
            if (_secondaryMuscleGroupIds.contains(id)) {
              _secondaryMuscleGroupIds.remove(id);
            } else if (!_primaryMuscleGroupIds.contains(id)) {
              _secondaryMuscleGroupIds.add(id);
            } else {
              _showMessage(
                'Este músculo ya está como primario',
                duration: const Duration(seconds: 2),
              );
            }
          }),
        ),
      ),
      const SizedBox(height: 12),
      ExerciseSectionCard(
        icon: Icons.hardware_outlined,
        title: 'Equipamiento',
        subtitle: 'Material necesario para el ejercicio',
        child: ExerciseMultiSelectChips(
          items: catalogs.equipment,
          selectedIds: _equipmentIds,
          onToggle: (id, selected) => setState(() {
            if (!_equipmentIds.remove(id)) _equipmentIds.add(id);
          }),
        ),
      ),
      const SizedBox(height: 12),
      ExerciseSectionCard(
        icon: Icons.description_outlined,
        title: 'Explicación',
        subtitle: 'Descripción detallada de la ejecución',
        child: ExerciseTextArea(
          controller: _explanationController,
          hint: 'Describe paso a paso cómo realizar el ejercicio...',
          maxLines: 5,
        ),
      ),
      const SizedBox(height: 12),
      ExerciseSectionCard(
        icon: Icons.lightbulb_outline,
        title: 'Consejos',
        subtitle: 'Tips para mejorar la técnica',
        child: ExerciseTextArea(
          controller: _tipsController,
          hint: 'Ej: Mantén los pies apoyados en el suelo...',
        ),
      ),
      const SizedBox(height: 12),
      ExerciseSectionCard(
        icon: Icons.warning_amber_outlined,
        title: 'Errores comunes',
        subtitle: 'Fallos frecuentes que evitar',
        child: ExerciseTextArea(
          controller: _commonMistakesController,
          hint: 'Ej: Arquear la zona lumbar...',
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final catalogsAsync = ref.watch(catalogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar ejercicio' : 'Nuevo ejercicio'),
        actions: [
          if (catalogsAsync.hasError)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reintentar carga de catálogos',
              onPressed: () => ref.read(catalogsProvider.notifier).refresh(),
            ),
          IconButton(
            tooltip: 'Guardar',
            onPressed: isSaving || _loading || _loadError != null
                ? null
                : _saveExercise,
            icon: isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: AppLoader(size: 20, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: _buildBody(catalogsAsync),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.size = 28,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: size),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child:
          tooltip != null ? Tooltip(message: tooltip!, child: button) : button,
    );
  }
}
