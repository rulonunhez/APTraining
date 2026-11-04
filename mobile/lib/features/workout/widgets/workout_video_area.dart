import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/widgets/app_loader.dart';
import '../../exercise/models/exercise_video_source.dart';
import '../../exercise/widgets/youtube_exercise_player.dart';
import '../models/workout_step.dart';
import '../utils/workout_video_pool.dart';
import 'workout_fullscreen_video.dart';

/// Muestra el vídeo del ejercicio sea subido o de YouTube.
class WorkoutVideoArea extends StatelessWidget {
  const WorkoutVideoArea({
    super.key,
    required this.step,
    required this.slot,
    required this.isActive,
    required this.onTogglePlayback,
    required this.onRetry,
    this.fullscreenOverlayBuilder,
  });

  final WorkoutStep step;
  final WorkoutVideoSlot? slot;
  final bool isActive;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRetry;

  /// Contenido extra sobre el vídeo en pantalla completa (botón "Datos").
  final WidgetBuilder? fullscreenOverlayBuilder;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: switch (step.videoSource) {
        ExerciseVideoSource.none => const _Message(
            icon: Icons.videocam_off_outlined,
            text: 'Sin vídeo',
          ),
        ExerciseVideoSource.youtube => _buildYoutube(),
        ExerciseVideoSource.upload => _buildUpload(context),
      },
    );
  }

  Widget _buildYoutube() {
    final id = step.youtubeVideoId!;
    if (isActive) {
      // Se ajusta al espacio disponible para no desbordar en horizontal.
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite && constraints.maxHeight.isFinite
              ? (constraints.maxHeight * 16 / 9).clamp(0.0, constraints.maxWidth)
              : constraints.maxWidth;
          return Center(
            child: SizedBox(
              width: width,
              child: YoutubeExercisePlayer(
                videoId: id,
                autoPlay: true,
                fullscreenOverlayBuilder: fullscreenOverlayBuilder,
              ),
            ),
          );
        },
      );
    }
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        Image.network(
          'https://img.youtube.com/vi/$id/hqdefault.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        const Icon(Icons.play_circle_outline, color: Colors.white70, size: 56),
      ],
    );
  }

  Widget _buildUpload(BuildContext context) {
    final current = slot;
    if (current == null || current.status == WorkoutVideoStatus.loading) {
      return const Center(child: AppLoader(size: 56, color: Colors.white));
    }
    final controller = current.controller;
    if (current.status == WorkoutVideoStatus.error || controller == null) {
      return _Message(
        icon: Icons.videocam_off_outlined,
        text: 'No se pudo cargar el vídeo',
        onRetry: onRetry,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTogglePlayback,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: 'Pantalla completa',
                  onPressed: () => openWorkoutFullscreenVideo(
                    context,
                    controller: controller,
                    onTogglePlayback: onTogglePlayback,
                    overlayBuilder: fullscreenOverlayBuilder,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.fullscreen),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.isPlaying
                ? const SizedBox.shrink()
                : const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white70,
                    size: 64,
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: false,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 40),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.white70)),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
    );
  }
}
