import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gallery_saver/gallery_saver.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen Recorder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ScreenRecorderPage(),
    );
  }
}

class ScreenRecorderPage extends StatefulWidget {
  const ScreenRecorderPage({super.key});

  @override
  State<ScreenRecorderPage> createState() => _ScreenRecorderPageState();
}

class _ScreenRecorderPageState extends State<ScreenRecorderPage> {
  bool _isRecording = false;
  String _selectedResolution = '720p';
  String _recordingStatus = 'Stopped';
  String _recordingDuration = '00:00:00';

  Timer? _durationTimer;
  Duration _elapsedTime = Duration.zero;

  // Countdown specific state variables
  bool _enableCountdown = true;
  final int _countdownSeconds = 3;
  int _currentCountdown = 0;
  bool _isCountingDown = false;
  Timer? _countdownTimer;

  final List<String> _resolutions = ['480p', '720p', '1080p', '2K', '4K'];

  Map<String, Map<String, int>> get _resolutionValues => {
        '480p': {'width': 854, 'height': 480},
        '720p': {'width': 1280, 'height': 720},
        '1080p': {'width': 1920, 'height': 1080},
        '2K': {'width': 2048, 'height': 1080},
        '4K': {'width': 3840, 'height': 2160},
      };

  @override
  void dispose() {
    _durationTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.storage,
      Permission.photos,
    ].request();

    bool permissionsGranted = statuses.values.every((status) => status.isGranted);

    if (!permissionsGranted && mounted) {
      String deniedPermissions = '';
      statuses.forEach((permission, status) {
        if (status.isDenied || status.isPermanentlyDenied) {
          String permissionName = permission.toString().split('.').last;
          deniedPermissions += '$permissionName, ';
        }
      });
      if (deniedPermissions.isNotEmpty) {
        deniedPermissions = deniedPermissions.substring(0, deniedPermissions.length - 2);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permissions required: $deniedPermissions. Please grant access.')),
      );
    }
    return permissionsGranted;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _startRecordingFlow() async {
    if (_isRecording || _isCountingDown) return; // Prevent multiple triggers

    if (_enableCountdown) {
      setState(() {
        _isCountingDown = true;
        _currentCountdown = _countdownSeconds;
        _recordingStatus = 'Countdown...'; // Update status for countdown
      });
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _currentCountdown--;
          if (_currentCountdown <= 0) {
            timer.cancel();
            _isCountingDown = false;
            _proceedWithActualRecording();
          }
        });
      });
    } else {
      _proceedWithActualRecording();
    }
  }

  Future<void> _proceedWithActualRecording() async {
    if (!await _requestPermissions()) {
      setState(() { // Reset status if permissions denied
        _recordingStatus = 'Stopped';
      });
      return;
    }

    final int width = _resolutionValues[_selectedResolution]!['width']!;
    final int height = _resolutionValues[_selectedResolution]!['height']!;

    try {
      bool recordStarted = await FlutterScreenRecording.startRecordScreenAndAudio(
        _selectedResolution,
        title: "Screen Recording Notification",
        message: "Screen recording in progress...",
        width: width,
        height: height,
      );

      if (recordStarted) {
        setState(() {
          _isRecording = true;
          _recordingStatus = 'Recording...';
          _elapsedTime = Duration.zero;
          _recordingDuration = _formatDuration(_elapsedTime);
        });

        _durationTimer?.cancel();
        _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _elapsedTime += const Duration(seconds: 1);
            _recordingDuration = _formatDuration(_elapsedTime);
          });
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start recording. Plugin returned false.')),
          );
        }
        setState(() { // Reset status if failed to start
          _recordingStatus = 'Stopped';
        });
      }
    } catch (e) {
      print('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
      setState(() { // Reset status on error
         _recordingStatus = 'Stopped';
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_isCountingDown) { // If countdown is active, cancel it
      _countdownTimer?.cancel();
      setState(() {
        _isCountingDown = false;
        _currentCountdown = 0;
        _recordingStatus = 'Stopped';
      });
      return;
    }

    if (!_isRecording) return; // Only stop if actually recording

    String? filePath;
    try {
      filePath = await FlutterScreenRecording.stopRecordScreen;
    } catch (e) {
      print('Error stopping recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    } finally { // Ensure state is always reset
      setState(() {
        _isRecording = false;
        _recordingStatus = 'Stopped';
      });
      _durationTimer?.cancel();
      _elapsedTime = Duration.zero;
      setState(() {
        _recordingDuration = _formatDuration(_elapsedTime);
      });
    }

    if (filePath != null) {
      print('Recording stopped. File saved at: $filePath');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Processing video... Temp path: $filePath')),
        );
      }
      try {
        final bool? saved = await GallerySaver.saveVideo(filePath);
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          if (saved == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video saved to Gallery successfully!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save video to Gallery.')),
            );
          }
        }
      } catch (e) {
        print('Error saving video to gallery: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving video to Gallery: $e')),
          );
        }
      }
    } else {
      if (mounted && filePath == null && _isRecording) { // Only show if it was recording and path is null
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording stopped, but no file was created.')),
        );
      }
    }
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SwitchListTile(
            title: const Text('Enable 3s Countdown'),
            value: _enableCountdown,
            onChanged: (bool value) {
              if (_isRecording || _isCountingDown) return; // Don't change during recording/countdown
              setState(() {
                _enableCountdown = value;
              });
            },
            activeColor: Colors.blueAccent,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Select Resolution: ', style: TextStyle(fontSize: 16)),
              DropdownButton<String>(
                value: _selectedResolution,
                items: _resolutions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (_isRecording || _isCountingDown) ? null : (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedResolution = newValue;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            _isCountingDown ? 'Starting in $_currentCountdown...' : _recordingStatus,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isRecording ? Colors.red : (_isCountingDown ? Colors.orangeAccent : Colors.green)),
          ),
          const SizedBox(height: 10),
          Text(
            _recordingDuration,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          IconButton(
            icon: Icon((_isRecording || _isCountingDown) ? Icons.stop_circle_outlined : Icons.play_circle_filled),
            iconSize: 72,
            color: (_isRecording || _isCountingDown) ? Colors.red : Colors.green,
            onPressed: (_isRecording || _isCountingDown) ? _stopRecording : _startRecordingFlow,
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    if (!_isCountingDown) {
      return const SizedBox.shrink();
    }
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Text(
          '$_currentCountdown',
          style: const TextStyle(fontSize: 120, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Recorder'),
      ),
      body: Stack(
        children: <Widget>[
          _buildControls(),
          _buildCountdownOverlay(),
        ],
      ),
    );
  }
}
