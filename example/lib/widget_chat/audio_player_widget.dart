import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String uri;

  const AudioPlayerWidget({super.key, required this.uri});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _cachedPath;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    // Escucha duración total
    _player.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });

    // Escucha posición actual
    _player.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });

    // Escucha fin de reproducción
    _player.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  Future<void> _prepareAudio() async {
    setState(() => _isLoading = true);
    _cachedPath = await _getCachedAudio(widget.uri);
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      //await _player.play(UrlSource(widget.uri));
      // Usa el archivo cacheado (ya descargado)
      _cachedPath ??= await _getCachedAudio(widget.uri);

      await _player.play(DeviceFileSource(_cachedPath!));
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  Future<String> _getCachedAudio(String url) async {
    var file = await DefaultCacheManager().getSingleFile(url);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.blue,
                  size: 32,
                ),
                onPressed: _togglePlay,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Slider(
                      value: _position.inSeconds.toDouble().clamp(
                        0,
                        _duration.inSeconds.toDouble(),
                      ),
                      max: _duration.inSeconds.toDouble() == 0
                          ? 1
                          : _duration.inSeconds.toDouble(),
                      onChanged: (value) async {
                        final pos = Duration(seconds: value.toInt());
                        await _player.seek(pos);
                      },
                      activeColor: Colors.blueAccent,
                      inactiveColor: Colors.grey.shade300,
                    ),
                    Text(
                      '${_formatTime(_position)} / ${_formatTime(_duration)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
