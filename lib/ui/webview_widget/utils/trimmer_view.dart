import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:path/path.dart' as p;
class TrimmerView extends StatefulWidget {
  final File file;

  const TrimmerView(this.file, {super.key});

  @override
  State<TrimmerView> createState() => _TrimmerViewState();
}

class _TrimmerViewState extends State<TrimmerView> {
  final Trimmer _trimmer = Trimmer();

  double _startValue = 0.0;
  double _endValue = 0.0;

  bool _isPlaying = false;
  bool _progressVisibility = false;

  @override
  void initState() {
    super.initState();

    _loadVideo();
  }

  void _loadVideo() {
    // Log original file size (before trimming)
    final originalSizeBytes = widget.file.lengthSync();
    final originalSizeMB = (originalSizeBytes / (1024 * 1024)).toStringAsFixed(2);
    debugPrint('Original video size: $originalSizeMB MB');
    _trimmer.loadVideo(videoFile: widget.file);
  }

  _saveVideo() {
    setState(() {
      _progressVisibility = true;
    });

    _trimmer.saveTrimmedVideo(
      startValue: _startValue,
      endValue: _endValue,
        onSave: (outputPath) async {
          setState(() => _progressVisibility = false);
          debugPrint('OUTPUT PATH: $outputPath');
          if (outputPath != null) {
            final originalFile = File(outputPath);
            final dir = p.dirname(outputPath);
            // Replace colons and spaces with underscores for a safe filename
            String safeName = p.basename(outputPath).replaceAll(RegExp(r'[:\\s]'), '_');
            final safeFile = File(p.join(dir, safeName));
            await originalFile.copy(safeFile.path);
            // Log trimmed file size in MB
            final trimmedSizeBytes = safeFile.lengthSync();
            final trimmedSizeMB = (trimmedSizeBytes / (1024 * 1024)).toStringAsFixed(2);
            debugPrint('Trimmed video size: $trimmedSizeMB MB');
            Navigator.pop(context, safeFile.path);
          } else {
            Navigator.pop(context, null);
          }
        },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !Navigator.of(context).userGestureInProgress,
      child: Scaffold(
        backgroundColor: theme.surface,
        appBar: AppBar(
          title: Text('Video Trimmer', style: TextStyle(color: theme.tertiary)),
          backgroundColor: theme.surface,
          foregroundColor: theme.onSurface,
          surfaceTintColor: theme.surface,
        ),
        body: Center(
          child: Container(
            padding: const EdgeInsets.only(bottom: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                Visibility(
                  visible: _progressVisibility,
                  child: const LinearProgressIndicator(
                    backgroundColor: Colors.red,
                  ),
                ),
                Expanded(
                  child: VideoViewer(trimmer: _trimmer),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TrimViewer(
                      trimmer: _trimmer,
                      viewerHeight: 50.0,
                      viewerWidth: MediaQuery.of(context).size.width,
                      durationStyle: DurationStyle.FORMAT_MM_SS,
                      maxVideoLength: const Duration(seconds: 30),
                      editorProperties: TrimEditorProperties(
                        borderPaintColor: Colors.yellow,
                        borderWidth: 4,
                        borderRadius: 5,
                        circlePaintColor: Colors.yellow.shade800,
                      ),
                      areaProperties: TrimAreaProperties.edgeBlur(
                        thumbnailQuality: 50,
                      ),
                      onChangeStart: (value) => _startValue = value,
                      onChangeEnd: (value) => _endValue = value,
                      onChangePlaybackState: (value) =>
                          setState(() => _isPlaying = value),
                    ),
                  ),
                ),
                TextButton(
                  child: _isPlaying
                      ? const Icon(
                          Icons.pause,
                          size: 80.0,
                          color: Colors.white,
                        )
                      : const Icon(
                          Icons.play_arrow,
                          size: 80.0,
                          color: Colors.white,
                        ),
                  onPressed: () async {
                    bool playbackState = await _trimmer.videoPlaybackControl(
                      startValue: _startValue,
                      endValue: _endValue,
                    );
                    setState(() => _isPlaying = playbackState);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: _progressVisibility ? null : () => _saveVideo(),
                        child: const Text('Continuar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
