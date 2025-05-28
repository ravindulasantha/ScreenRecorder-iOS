// ignore_for_file: subtype_of_sealed_class

import 'dart:io';

import 'package:mockito/annotations.dart';
import 'package:ed_screen_recorder/ed_screen_recorder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit_flutter_min.dart';
import 'package:ffmpeg_kit_flutter_min/session.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_editor/video_editor.dart';
import 'package:flutter_test/flutter_test.dart'; // For Fake
import 'package:video_player/video_player.dart';


// --- Official Mocking Setup (Preferred) ---
// For SharedPreferences: Use SharedPreferences.setMockInitialValues in test setup.

// --- Mockito Generated Mocks (Ideal - requires build_runner) ---
// This is where @GenerateMocks would output, but we can't run it.
// So, we'll define manual mocks below for key interfaces.

// --- Manual Mocks ---

// Mock for EdScreenRecorder
class MockEdScreenRecorder extends Mock implements EdScreenRecorder {
  // Default responses or use Mockito's `when(...).thenAnswer(...)` in tests
  Future<RecordOutput> startRecordScreenResult = Future.value(RecordOutput(
    success: true,
    file: FakeFile('dummy/path/to/video.mp4'),
    isProgress: false, // Or true if it should represent recording in progress
    eventName: 'startRecordScreen',
    message: 'Mock success',
    videoHash: 'mock_hash',
    startDate: DateTime.now().millisecondsSinceEpoch,
  ));

  Future<RecordOutput> stopRecordScreenResult = Future.value(RecordOutput(
    success: true,
    file: FakeFile('dummy/path/to/video.mp4'),
    isProgress: false,
    eventName: 'stopRecordScreen',
    message: 'Mock success',
    videoHash: 'mock_hash',
    startDate: DateTime.now().millisecondsSinceEpoch,
    endDate: DateTime.now().millisecondsSinceEpoch,
  ));
  
  Future<RecordOutput> pauseRecordScreenResult = Future.value(RecordOutput(
    success: true,
    file: FakeFile('dummy/path/to/video.mp4'),
    isProgress: true, // Reflects that it's paused, but still "in progress"
    eventName: 'pauseRecordScreen',
    message: 'Mock success',
    videoHash: 'mock_hash',
    startDate: DateTime.now().millisecondsSinceEpoch,
  ));

  Future<RecordOutput> resumeRecordScreenResult = Future.value(RecordOutput(
    success: true,
    file: FakeFile('dummy/path/to/video.mp4'),
    isProgress: true,
    eventName: 'resumeRecordScreen',
    message: 'Mock success',
    videoHash: 'mock_hash',
    startDate: DateTime.now().millisecondsSinceEpoch,
  ));


  @override
  Future<RecordOutput> startRecordScreen({
    required String fileName,
    String? dirPathToSave,
    bool? addTimeCode = true,
    String? fileOutputFormat = "MPEG_4",
    String? fileExtension = "mp4",
    int? videoBitrate = 3000000,
    int? videoFrame = 30,
    required int width,
    required int height,
    required bool audioEnable,
  }) {
    return startRecordScreenResult;
  }

  @override
  Future<RecordOutput> stopRecord() { // Corrected method name from plugin
    return stopRecordScreenResult;
  }

  @override
  Future<RecordOutput> pauseRecordScreen() {
     return pauseRecordScreenResult;
  }

  @override
  Future<RecordOutput> resumeRecordScreen() {
    return resumeRecordScreenResult;
  }
}

// Fake File implementation for RecordOutput
class FakeFile extends Fake implements File {
  final String _path;
  FakeFile(this._path);

  @override
  String get path => _path;

  @override
  Future<File> create({bool recursive = false}) async => this;
  @override
  Future<bool> exists() async => true; // Assume file exists for tests
  // Add other methods if they are called by the code under test
}

// Mock for FilePicker
// FilePicker.platform.getDirectoryPath() is a static method.
// Mocking static methods is tricky. We'll need to handle this in the test itself,
// possibly by setting up a mock for FilePicker.platform if the plugin allows it,
// or by wrapping the call in a service that can be mocked.
// For now, we'll assume we can control the return value in the test setup.
// A full mock class might look like this if it were instance-based:
class MockFilePicker extends Mock implements FilePicker {
  String? mockPath;

  MockFilePicker({this.mockPath});

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool? lockParentWindow,
    String? initialDirectory,
  }) async {
    return mockPath;
  }
}


// Mock for VideoEditorController
class MockVideoEditorController extends Mock implements VideoEditorController {
  final Duration _mockDuration;
  final VideoPlayerController _mockVideoPlayerController;

  MockVideoEditorController(File file, {Duration? minDuration, Duration? maxDuration})
      : _mockDuration = maxDuration ?? const Duration(seconds: 10), // Default if not provided
        _mockVideoPlayerController = MockVideoPlayerController(maxDuration ?? const Duration(seconds: 10)) {
    // Initialize values that would normally be set by the controller
    // You might need to expose setters or methods to control these from tests
  }
  
  bool _isDisposed = false;

  @override
  Future<void> initialize({Duration? minDuration, Duration? maxDuration}) async {
    // Simulate initialization
    return Future.value();
  }
  
  @override
  VideoPlayerController get video => _mockVideoPlayerController;
  
  @override
  Duration get videoDuration => _mockDuration;

  @override
  bool get isPlaying => _mockVideoPlayerController.value.isPlaying;


  @override
  double get startTrim => 0.0; // Mock value
  @override
  double get endTrim => _mockDuration.inMilliseconds.toDouble() / 1000.0; // Mock value

  @override
  FixedCropRatio? get preferredCropAspectRatio => null;
  
  @override
  bool get isTrimming => false; // Mock value
  @override
  bool get isCropping => false; // Mock value

  @override
  void dispose() {
    _isDisposed = true;
    _mockVideoPlayerController.dispose();
    super.dispose();
  }

  @override
  bool get isDisposed => _isDisposed;

  // Add other methods/getters as needed by TrimmingScreen tests
  // For example, if you access `controller.value.isInitialized`, etc.
  // For `minDuration` and `maxDuration` used in initialization:
  @override
  Duration get minDuration => const Duration(seconds: 1);
  @override
  Duration get maxDuration => _mockDuration;

  // Mock for updateSelectedCropPath if needed
  @override
  void updateSelectedCropPath(String? path) {}

}

// Mock for VideoPlayerController (simplified)
class MockVideoPlayerController extends Mock implements VideoPlayerController {
  final Duration _duration;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  MockVideoPlayerController(this._duration) {
     // Simulate initialization for value getter
    _isInitialized = true;
  }


  @override
  Future<void> initialize() async {
    _isInitialized = true;
    return Future.value();
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
  }

  @override
  VideoPlayerValue get value => VideoPlayerValue(
        duration: _duration,
        isInitialized: _isInitialized,
        isPlaying: _isPlaying,
        // Add other VideoPlayerValue properties if needed
      );
  
  @override
  bool get isDisposed => _isDisposed;


  @override
  Future<void> dispose() async {
    _isPlaying = false;
    _isInitialized = false;
    _isDisposed = true;
    super.dispose(); // Important for Mockito bookkeeping
  }
}


// Mock for FFmpegKit (static methods are hard to mock directly)
// We will assume FFmpegKit.executeAsync can be stubbed or we test around it.
// For tests needing its callback, we might need a more complex setup or wrapper.
class MockFFmpegSession extends Mock implements Session {
  final bool _isSuccess;
  final String _logs;

  MockFFmpegSession(this._isSuccess, {String logs = ""}) : _logs = logs;

  @override
  Future<ReturnCode?> getReturnCode() async {
    return _isSuccess ? ReturnCode.success() : ReturnCode.error(1);
  }
  
  @override
  Future<String> getLogsAsString() async {
    return _logs;
  }

  @override
  Future<String?> getFailStackTrace() async {
    return _isSuccess ? null : "Mocked FFmpeg stack trace";
  }
}

// Mock for FlutterLocalNotificationsPlugin
class MockFlutterLocalNotificationsPlugin extends Mock implements FlutterLocalNotificationsPlugin {
    Future<void> initializeResult = Future.value();
    Future<bool?> requestPermissionsResultIOS = Future.value(true);
    Future<void> showResult = Future.value();
    Future<void> cancelResult = Future.value();

    @override
    Future<void> initialize(
        InitializationSettings initializationSettings, {
        DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
        DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
    }) {
        // Store callbacks if needed for testing
        return initializeResult;
    }

    @override
    Future<bool?> requestPermissions({
        bool alert = false,
        bool badge = false,
        bool sound = false,
        bool critical = false, // If using a newer version of the plugin
        bool provisional = false, // If using a newer version
    }) async { // For iOS
        return requestPermissionsResultIOS;
    }
    
    // This is a simplified mock. The actual method might differ slightly based on plugin version.
    Future<bool?> requestIOSPermissions() async {
        return requestPermissionsResultIOS;
    }


    @override
    Future<void> show(
        int id,
        String? title,
        String? body,
        NotificationDetails? notificationDetails, {
        String? payload,
    }) {
        return showResult;
    }

    @override
    Future<void> cancel(int id, {String? tag}) {
        return cancelResult;
    }
}


// Mock for GallerySaver - static methods, so this is a conceptual placeholder.
// Tests will likely assume GallerySaver.saveVideo works and verify calls if possible,
// or test the logic that *would* call it.
// class MockGallerySaver {
//   static Future<bool?> saveVideo(String path, {String? albumName, bool? toDcim}) async {
//     print("MockGallerySaver: saveVideo called with $path");
//     return true; // Simulate success
//   }
// }

// Mock for SharePlus - instance based now
class MockSharePlus extends Mock implements SharePlus {
  Future<ShareResult> shareResult = Future.value(ShareResult(ShareResultStatus.success.toString(), ShareResultStatus.success));

  @override
  Future<ShareResult> share(ShareParams params) {
    return shareResult;
  }
}


// Note: FlutterOverlayWindow and PermissionHandler have static methods.
// These will be challenging to mock directly.
// - For PermissionHandler, you can often mock specific permission status responses if the plugin
//   allows for testing handlers (rare) or by wrapping permission checks.
// - For FlutterOverlayWindow, testing the overlay UI itself is complex. Focus on the logic
//   in the main app that *would* show/hide/communicate with the overlay.

// It's good practice to also generate mocks for interfaces used by these plugins if needed,
// e.g., MethodChannel for testing platform communication directly.
// However, for widget tests, mocking the plugin's Dart API surface is usually sufficient.

void main() {} // Keep this if you were to use @GenerateMocks
