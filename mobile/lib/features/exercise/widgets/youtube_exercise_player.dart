import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../utils/exercise_video_playback_coordinator.dart';

class YoutubeExercisePlayer extends StatefulWidget {
  const YoutubeExercisePlayer({
    super.key,
    required this.videoId,
    this.active = true,
    this.vertical = false,
    this.autoPlay = false,
    this.fullscreenOverlayBuilder,
  });

  final String videoId;
  final bool active;
  final bool vertical;
  final bool autoPlay;

  /// Contenido extra que se muestra sobre el vídeo mientras el reproductor
  /// está en pantalla completa (por ejemplo, el botón "Datos" del workout).
  final WidgetBuilder? fullscreenOverlayBuilder;

  @override
  State<YoutubeExercisePlayer> createState() => _YoutubeExercisePlayerState();
}

class _YoutubeExercisePlayerState extends State<YoutubeExercisePlayer>
    with WidgetsBindingObserver {
  late YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerValue>? _subscription;
  bool _pauseWhenReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = _createController(widget.videoId);
    _listenToPlayback(_controller);
    _pauseWhenReady = !widget.active;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pauseWhenReady = false;
      return;
    }
    _pauseWhenReady = true;
    _pauseIfPlaying();
    ExerciseVideoPlaybackCoordinator.release(this);
  }

  @override
  void didUpdateWidget(covariant YoutubeExercisePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      unawaited(_replaceController(widget.videoId));
    } else if (oldWidget.active != widget.active && !widget.active) {
      _pauseWhenReady = true;
      _pauseIfPlaying();
      ExerciseVideoPlaybackCoordinator.release(this);
    } else if (!oldWidget.active && widget.active) {
      _pauseWhenReady = false;
    }
  }

  void _pauseIfPlaying() {
    final playerState = _controller.value.playerState;
    if (playerState == PlayerState.playing ||
        playerState == PlayerState.buffering) {
      unawaited(_controller.pauseVideo());
    }
  }

  Future<void> _replaceController(String videoId) async {
    final oldController = _controller;
    unawaited(_subscription?.cancel());
    ExerciseVideoPlaybackCoordinator.release(this);
    _controller = _createController(videoId);
    _pauseWhenReady = !widget.active;
    _listenToPlayback(_controller);
    if (mounted) setState(() {});
    unawaited(_closeController(oldController));
  }

  Future<void> _closeController(YoutubePlayerController controller) async {
    try {
      await controller.close();
    } catch (error) {
      debugPrint('Could not close YouTube exercise player: $error');
    }
  }

  void _listenToPlayback(YoutubePlayerController controller) {
    _subscription = controller.stream.listen((value) {
      if (!mounted || !identical(controller, _controller)) return;
      if (value.playerState == PlayerState.playing ||
          value.playerState == PlayerState.buffering) {
        if (_pauseWhenReady || !widget.active) {
          unawaited(controller.pauseVideo());
          return;
        }
        unawaited(
          ExerciseVideoPlaybackCoordinator.claim(this, controller.pauseVideo),
        );
      } else if (value.playerState == PlayerState.paused ||
          value.playerState == PlayerState.ended) {
        ExerciseVideoPlaybackCoordinator.release(this);
      }
    });
  }

  YoutubePlayerController _createController(String videoId) {
    return YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: widget.autoPlay && widget.active,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    ExerciseVideoPlaybackCoordinator.release(this);
    unawaited(_closeController(_controller));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlayBuilder = widget.fullscreenOverlayBuilder;
    final player = YoutubePlayer(
      key: ValueKey(widget.videoId),
      controller: _controller,
      aspectRatio: widget.vertical ? 9 / 16 : 16 / 9,
      // Evita que girar el dispositivo fuerce la pantalla completa del vídeo.
      autoFullScreen: false,
      // El overlay de pantalla completa del reproductor se dibuja por encima
      // del árbol de widgets de la app, así que el contenido extra (botón
      // "Datos") debe inyectarse dentro del propio overlay para no quedar
      // tapado por el vídeo.
      controlsBuilder: overlayBuilder == null
          ? null
          : (context, isFullscreen) => isFullscreen
              ? Positioned(
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    child: Builder(builder: overlayBuilder),
                  ),
                )
              : const SizedBox.shrink(),
    );

    return Offstage(
      offstage: !widget.active,
      child: widget.vertical
          ? LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = MediaQuery.sizeOf(context).height * 0.6;
                final height =
                    (constraints.maxWidth * 16 / 9).clamp(0.0, maxHeight);
                return Center(
                  child: SizedBox(width: height * 9 / 16, child: player),
                );
              },
            )
          : player,
    );
  }
}
