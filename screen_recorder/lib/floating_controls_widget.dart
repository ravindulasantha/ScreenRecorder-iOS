import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// This is the entry point for the overlay.
@pragma("vm:entry-point")
void overlayMain() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FloatingControlsWidget(),
    ),
  );
}

class FloatingControlsWidget extends StatefulWidget {
  const FloatingControlsWidget({super.key});

  @override
  State<FloatingControlsWidget> createState() => _FloatingControlsWidgetState();
}

class _FloatingControlsWidgetState extends State<FloatingControlsWidget> {
  String _recordingState = "recording"; // Possible states: "recording", "paused"
  String _currentDuration = "00:00"; // Placeholder for duration

  @override
  void initState() {
    super.initState();
    // Listen for data from the main app
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map<String, dynamic>) {
        setState(() {
          _recordingState = data['state'] ?? _recordingState;
          _currentDuration = data['duration'] ?? _currentDuration;
        });
      }
    });
  }

  void _handlePauseResume() {
    if (_recordingState == "recording") {
      print("Overlay: Pause button pressed");
      FlutterOverlayWindow.shareData({'action': 'pause'});
      // setState(() { _recordingState = "paused"; }); // Optimistic update, or wait for app
    } else if (_recordingState == "paused") {
      print("Overlay: Resume button pressed");
      FlutterOverlayWindow.shareData({'action': 'resume'});
      // setState(() { _recordingState = "recording"; }); // Optimistic update
    }
  }

  void _handleStop() {
    print("Overlay: Stop button pressed");
    FlutterOverlayWindow.shareData({'action': 'stop'});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Card(
        color: Colors.black.withOpacity(0.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                icon: Icon(
                  _recordingState == "recording" ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Colors.white,
                ),
                onPressed: _handlePauseResume,
                tooltip: _recordingState == "recording" ? 'Pause' : 'Resume',
              ),
              const SizedBox(width: 8),
              Text(
                _currentDuration,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
                onPressed: _handleStop,
                tooltip: 'Stop',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
