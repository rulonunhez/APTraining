import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Pantalla completa para vídeos subidos. Reutiliza el controlador ya
/// inicializado del pool, así que no hay nueva carga.
Future<void> openWorkoutFullscreenVideo(
  BuildContext context, {
  required VideoPlayerController controller,
  required VoidCallback onTogglePlayback,
  WidgetBuilder? overlayBuilder,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FullscreenVideo(
        controller: controller,
        onTogglePlayback: onTogglePlayback,
        overlayBuilder: overlayBuilder,
      ),
    ),
  );
}

class _FullscreenVideo extends StatefulWidget {
  const _FullscreenVideo({
    required this.controller,
    required this.onTogglePlayback,
    this.overlayBuilder,
  });

  final VideoPlayerController controller;
  final VoidCallback onTogglePlayback;

  /// Contenido extra sobre el vídeo (botón "Datos" del workout).
  final WidgetBuilder? overlayBuilder;

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTogglePlayback,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: IconButton.filled(
                tooltip: 'Salir de pantalla completa',
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.fullscreen_exit),
              ),
            ),
          ),
          if (widget.overlayBuilder != null)
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Builder(builder: widget.overlayBuilder!),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
