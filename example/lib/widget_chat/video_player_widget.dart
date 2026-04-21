import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String uri;

  const VideoPlayerWidget({super.key, required this.uri});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.uri))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isInitialized = true;
        });
      })
      ..addListener(() {
        final isFinished = _controller.value.position >= _controller.value.duration;
        if (isFinished && mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isFinished =>
      _controller.value.position >= _controller.value.duration;

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Video',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.2),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
              ),
              onPressed: () {
                if (_isFinished) {
                  _controller.seekTo(Duration.zero);
                  _controller.play();
                  return;
                }

                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              icon: Icon(
                _isFinished
                    ? Icons.replay
                    : _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
