import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit_flutter_min.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // Import share_plus

class TrimmingScreen extends StatefulWidget {
  final String filePath;
  const TrimmingScreen({super.key, required this.filePath});

  @override
  State<TrimmingScreen> createState() => _TrimmingScreenState();
}

class _TrimmingScreenState extends State<TrimmingScreen> {
  late VideoEditorController _controller;
  bool _isLoading = true; // For initial video loading and for export
  bool _isExporting = false;
  Duration? _videoDuration;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    // First, get the video duration
    final VideoPlayerController tempVideoController = VideoPlayerController.file(File(widget.filePath));
    await tempVideoController.initialize();
    _videoDuration = tempVideoController.value.duration;
    await tempVideoController.dispose(); // Dispose temporary controller

    if (_videoDuration == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Could not load video duration.')),
        );
        Navigator.pop(context); // Go back if duration can't be loaded
      }
      return;
    }

    _controller = VideoEditorController.file(
      File(widget.filePath),
      minDuration: const Duration(seconds: 1),
      maxDuration: _videoDuration!,
      // Default trim is usually 0 to videoDuration, can adjust if needed
      // trimStyle: TrimSliderStyle(), // Customize style if needed
    );

    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing video editor: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _exportVideo() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
    });

    try {
      final config = VideoFFmpegVideoEditorConfig(_controller, format: 'mp4');
      // The execute.outputPath is a temporary path. We need to save it to gallery after.
      final FFmpegVideoEditorExecute execute = await config.getExecuteConfig();
      
      final tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      // Ensure unique output path if original name is kept by config or ensure config creates unique names
      final outputPath = "${tempDir.path}/trimmed_video_$timestamp.mp4"; 
      
      // Modify command to use the new output path if library does not handle it well
      // Default config.getExecuteConfig() should provide a unique path.
      // Forcing one here for clarity if issues arise with the library's default.
      // final String command = execute.command.replaceAll(execute.outputPath, outputPath);
      // Forcing output path for safety, as direct execute.outputPath might be overwritten or not unique enough.
      final String command = config.getFFmpegCommand(outputPath: outputPath);


      print("FFmpeg command: $command");

      await FFmpegKit.executeAsync(command, (session) async {
        final returnCode = await session.getReturnCode();
        if (mounted) {
          setState(() { _isExporting = false; });
        }

        if (ReturnCode.isSuccess(returnCode)) {
          // GallerySaver.saveVideo returns bool? but path is what we used (outputPath)
          bool? saved = await GallerySaver.saveVideo(outputPath);
          if (mounted) {
            if (saved == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Trimmed video saved to Gallery!'),
                  action: SnackBarAction(
                    label: 'SHARE',
                    onPressed: () async {
                      final box = context.findRenderObject() as RenderBox?;
                      final result = await SharePlus.instance.share(
                        ShareParams(
                          files: [XFile(outputPath)], // outputPath is the path of the saved trimmed video
                          text: 'Check out this trimmed screen recording!',
                          sharePositionOrigin: box?.localToGlobal(Offset.zero) & box?.size,
                        )
                      );
                      if (result.status == ShareResultStatus.success) {
                        print('Successfully shared trimmed video!');
                      } else if (result.status == ShareResultStatus.dismissed) {
                        print('User dismissed the share sheet for trimmed video.');
                      } else {
                        print('Sharing trimmed video failed: ${result.status}, Raw: ${result.raw}');
                      }
                    },
                  ),
                ),
              );
            } else {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to save trimmed video to gallery.')),
              );
            }
            Navigator.pop(context); // Go back after saving or attempting to save
          }
        } else if (ReturnCode.isCancel(returnCode)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video trimming cancelled.')),
            );
          }
        } else {
          final logs = await session.getLogsAsString();
          print("FFmpeg Error Logs: $logs");
          final failStackTrace = await session.getFailStackTrace();
          print("FFmpeg StackTrace: $failStackTrace");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error trimming video. Code: $returnCode. Log: $logs')),
            );
          }
        }
      });
    } catch (e) {
        if (mounted) {
            setState(() { _isExporting = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error preparing trim: $e')),
            );
        }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trim Video'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isExporting ? null : _exportVideo,
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                // Video Player Preview
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CropGridViewer.preview(controller: _controller),
                      AnimatedBuilder(
                        animation: _controller.video,
                        builder: (_, __) => Opacity(
                          opacity: _controller.isPlaying ? 0 : 1,
                          child: GestureDetector(
                            onTap: _controller.video.play,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow, color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Trim Controls
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                       Row( // Playback controls
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(_controller.isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: () {
                              if (_controller.isPlaying) {
                                _controller.video.pause();
                              } else {
                                _controller.video.play();
                              }
                              setState(() {}); // To update the icon
                            },
                          ),
                          // Optional: Display current trim values
                          // Text('${_controller.startTrim.toStringAsFixed(1)}s - ${_controller.endTrim.toStringAsFixed(1)}s'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TrimSlider(
                        controller: _controller,
                        height: 40, // Adjust height as needed
                        // style: TrimSliderStyle(), // Optional: Customize
                        onChangeStart: (value) {
                           // Callback when the start trim point changes
                           setState(() {}); // Update UI if displaying trim values
                        },
                        onChangeEnd: (value) {
                           // Callback when the end trim point changes
                           setState(() {}); // Update UI if displaying trim values
                        },
                        onChangePlaybackState: (isPlaying) {
                          // Callback when playback state changes (from TrimSlider interaction)
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 20),
                      if (_isExporting)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: CircularProgressIndicator(),
                        ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.content_cut),
                        label: const Text('Trim and Save'),
                        onPressed: _isExporting ? null : _exportVideo,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
