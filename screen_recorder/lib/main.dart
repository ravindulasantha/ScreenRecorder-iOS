import 'dart:async';
import 'dart:convert'; // Required for json.decode
import 'package:flutter/material.dart';
import 'package:ed_screen_recorder/ed_screen_recorder.dart'; // Updated import
import 'package:permission_handler/permission_handler.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:share_plus/share_plus.dart'; // Import share_plus
import 'trimming_screen.dart'; // Import the TrimmingScreen


// --- Notification specific setup ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Background notification action handler
// Needs to be a top-level or static function
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle a notification tap event when the app is in the background or terminated
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    print(
        'notification action tapped with input: ${notificationResponse.input}');
  }
  // IMPORTANT: This background handler CANNOT update UI or call Flutter app state directly.
  // It's intended for background tasks or for plugins that can operate headlessly.
  // For screen recording controls, the main app instance needs to handle these when it's active.
  // The main app will re-show notification on start if recording is active.
}


void main() async { // main needs to be async for notification initialization
  WidgetsFlutterBinding.ensureInitialized(); // Required for plugins before runApp

  if (Platform.isIOS) {
    await _configureLocalNotifications();
  }

  runApp(const MyApp());
}

Future<void> _configureLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // Default icon

  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true, // Request permission directly
    requestBadgePermission: true,
    requestSoundPermission: false, // Screen recording notifications likely don't need sound
    onDidReceiveLocalNotification:
        (int id, String? title, String? body, String? payload) async {
      // Handle foreground notification for older iOS versions (deprecated)
    },
    notificationCategories: [ // Define categories to match AppDelegate
      const DarwinNotificationCategory(
        'RECORDING_CONTROLS',
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain('PAUSE_ACTION', 'Pause'),
          DarwinNotificationAction.destructive('STOP_ACTION', 'Stop'),
        ],
      ),
      const DarwinNotificationCategory(
        'PAUSED_CONTROLS',
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain('RESUME_ACTION', 'Resume'),
          DarwinNotificationAction.destructive('STOP_ACTION', 'Stop'),
        ],
      ),
    ]
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) async {
      // This is called when the app is in the foreground or background (but not terminated for some plugins)
      // We will handle this in the _ScreenRecorderPageState
      print("Notification tapped: ${notificationResponse.actionId}");
      // Action handling will be centralized in _ScreenRecorderPageState's listener
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  // Request permission for iOS 10+
   final bool? result = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: false, // Usually false for this type of notification
        );
    print("iOS Notification permission granted: $result");
}


class MyApp extends StatelessWidget {
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

// Placeholder for the actual overlay widget UI - will be defined in FloatingControlsWidget.dart
class FloatingControlsWidgetOverlay extends StatelessWidget {
  const FloatingControlsWidgetOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    // This is the UI that will be shown in the overlay.
    // It should be simple and communicate back to the main app.
    // For now, a simple container. Will be replaced by actual controls.
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: const Text("Overlay Active", style: TextStyle(color: Colors.white, fontSize: 10)),
          // Actual buttons will be added later.
        ),
      ),
    );
  }
}


class _ScreenRecorderPageState extends State<ScreenRecorderPage> {
  bool _isRecording = false;
  bool _isPaused = false; // New state for pause/resume
  String _selectedResolution = '720p';
  String _recordingStatus = 'Stopped';
  String _recordingDuration = '00:00:00';

  Timer? _durationTimer;
  Duration _elapsedTime = Duration.zero;

  bool _enableCountdown = true;
  int _countdownSeconds = 3; // Made mutable
  final List<int> _availableCountdownDurations = [3, 5, 10]; // Added available durations
  int _currentCountdown = 0;
  bool _isCountingDown = false;
  Timer? _countdownTimer;

  final List<String> _resolutions = ['480p', '720p', '1080p', '2K', '4K'];

  EdScreenRecorder? _screenRecorder; // Instance of the new plugin

  Map<String, Map<String, int>> get _resolutionValues => {
        '480p': {'width': 854, 'height': 480},
        '720p': {'width': 1280, 'height': 720},
        '1080p': {'width': 1920, 'height': 1080},
        '2K': {'width': 2048, 'height': 1080}, // Common 2K, adjust if needed
        '4K': {'width': 3840, 'height': 2160},
      };

  bool _showFloatingControls = true; // User preference for Android
  bool _showNotificationControls = true; // User preference for iOS
  String? _customOutputPath; // For custom output directory

  @override
  void initState() {
    super.initState();
    _screenRecorder = EdScreenRecorder();
    _requestPermissions(); // General media permissions
    _loadCustomOutputPath(); // Load saved output path
    
    if (Platform.isAndroid) {
      _initOverlayListener();
    } else if (Platform.isIOS) {
      _initNotificationActionListener();
    }
  }

  Future<void> _saveCustomOutputPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customOutputPath', path);
    print("Saved custom output path: $path");
  }

  Future<void> _loadCustomOutputPath() async {
    final prefs = await SharedPreferences.getInstance();
    final String? path = prefs.getString('customOutputPath');
    if (path != null && path.isNotEmpty) {
      setState(() {
        _customOutputPath = path;
        print("Loaded custom output path: $path");
      });
    }
  }

  Future<void> _clearCustomOutputPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customOutputPath');
    setState(() {
      _customOutputPath = null;
      print("Cleared custom output path.");
    });
  }

  void _initOverlayListener() { // Android
    if (mounted) {
      FlutterOverlayWindow.overlayListener.listen((data) {
        if (data is Map<String, dynamic>) {
          String? action = data['action'];
          _handleControlAction(action);
        }
      });
    }
  }

  void _initNotificationActionListener() { // iOS
    // Re-initialize the plugin within the widget's context if needed,
    // or ensure the global instance's onDidReceiveNotificationResponse callback
    // can communicate with this state.
    // A common pattern is to use a StreamController or a static callback
    // that can message the active _ScreenRecorderPageState.
    // For simplicity, we'll rely on the global plugin's callback for now,
    // assuming it's set up to call a method that this instance can respond to.
    // This part might need a more robust solution for multi-instance scenarios
    // or when the page is not active.

    // This is the handler when a notification action is tapped.
     flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'), // Not used on iOS but required
        iOS: DarwinInitializationSettings( // Re-affirm categories if needed, or ensure they are set globally
           requestAlertPermission: false, // Permissions should have been requested already
           requestBadgePermission: false,
           requestSoundPermission: false,
            notificationCategories: [
              const DarwinNotificationCategory('RECORDING_CONTROLS', actions: <DarwinNotificationAction>[DarwinNotificationAction.plain('PAUSE_ACTION', 'Pause'), DarwinNotificationAction.destructive('STOP_ACTION', 'Stop')]),
              const DarwinNotificationCategory('PAUSED_CONTROLS', actions: <DarwinNotificationAction>[DarwinNotificationAction.plain('RESUME_ACTION', 'Resume'), DarwinNotificationAction.destructive('STOP_ACTION', 'Stop')]),
            ]
        )
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print("iOS Notification action tapped: ${response.actionId}");
        _handleControlAction(response.actionId);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground, // Static/top-level
    );
  }


  void _handleControlAction(String? action) {
    if (action == 'PAUSE_ACTION' || action == 'pause') {
      _pauseRecording();
    } else if (action == 'RESUME_ACTION' || action == 'resume') {
      _resumeRecording();
    } else if (action == 'STOP_ACTION' || action == 'stop') {
      _stopRecording();
    }
  }


  Future<void> _updateOverlayState() async { // Android
    if (Platform.isAndroid && (await FlutterOverlayWindow.isActive() ?? false)) {
      await FlutterOverlayWindow.shareData({
        'state': _isPaused ? 'paused' : 'recording',
        'duration': _recordingDuration,
      });
    }
  }

  Future<void> _showPersistentNotification() async { // iOS
    if (!Platform.isIOS || !_showNotificationControls) return;

    const String channelId = 'screen_recording_channel';
    const String channelName = 'Screen Recording Controls';
    const String channelDescription = 'Notification for screen recording controls';

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max, // Keep it visible
      priority: Priority.high,
      ongoing: true, // Makes it persistent
      autoCancel: false, // Should not be dismissed by tap
    );

    final DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false, // No need to increment badge for this
      presentSound: false,
      categoryIdentifier: _isPaused ? 'PAUSED_CONTROLS' : 'RECORDING_CONTROLS',
    );
    
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics, // Used for Android, but this function is iOS specific
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      _isPaused ? 'Screen Recording Paused' : 'Screen Recording Active',
      _isPaused ? 'Tap to resume or stop' : 'Tap to pause or stop. Duration: $_recordingDuration',
      platformChannelSpecifics,
      payload: 'recording_controls', 
    );
  }

  Future<void> _cancelNotification() async { // iOS
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin.cancel(0); // Use the same ID
    }
  }


  @override
  void dispose() {
    _durationTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    // Request microphone, storage (for older Android), and photos (for saving to gallery)
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.storage, // Needed for older Android versions
      Permission.photos,  // For saving to gallery on iOS and some Android versions
      // Add Permission.manageExternalStorage for broader access if targeting Android 11+ and saving outside app specific/media dirs
    ].request();

    bool permissionsGranted = statuses.values.every((status) => status.isGranted || status.isLimited);

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
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Permissions required: $deniedPermissions. Please grant access via settings.')),
          );
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Some permissions were denied. Recording may not work as expected.')),
          );
      }
    }
    return permissionsGranted;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedTime += const Duration(seconds: 1);
      _recordingDuration = _formatDuration(_elapsedTime);
      setState(() {
        // Update main UI
      });
      if (Platform.isAndroid) _updateOverlayState(); 
      if (Platform.isIOS && _isRecording && !_isPaused) _showPersistentNotification(); // Keep updating notification text
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
  }

  Future<void> _showOverlay() async { // Android
    if (!Platform.isAndroid || !_showFloatingControls) return;

    bool hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasPermission) {
      hasPermission = await FlutterOverlayWindow.requestPermission();
    }

    if (hasPermission && mounted && !(await FlutterOverlayWindow.isActive() ?? false)) {
      await FlutterOverlayWindow.showOverlay(
        overlayTitle: "Screen Recorder Controls",
        overlayContent: "Controls are active.",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: 100, 
        width: WindowSize.matchParent, 
        entryPoint: "overlayMain", // This must be the @pragma in floating_controls_widget.dart
      );
       _updateOverlayState(); 
    }
  }

  Future<void> _closeOverlay() async { // Android
    if (Platform.isAndroid && (await FlutterOverlayWindow.isActive() ?? false)) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  Future<void> _startRecordingFlow() async {
    if (_isRecording || _isCountingDown) return;

    if (!await _requestPermissions()) { // General permissions
      setState(() {
        _recordingStatus = 'Permissions Denied';
      });
      return;
    }
    
    if (Platform.isAndroid && _showFloatingControls) { 
        bool hasPermission = await FlutterOverlayWindow.isPermissionGranted();
        if (!hasPermission) {
            hasPermission = await FlutterOverlayWindow.requestPermission();
            if (!hasPermission && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Overlay permission denied. Floating controls will not be shown.'))
                );
            }
        }
    } else if (Platform.isIOS && _showNotificationControls) {
        // Notification permissions are typically requested at app start by _configureLocalNotifications
        // but can re-check or prompt here if necessary.
    }


    if (_enableCountdown) {
      setState(() {
        _isCountingDown = true;
        _currentCountdown = _countdownSeconds;
        _recordingStatus = 'Countdown...';
      });
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _currentCountdown--;
        setState(() { /* Update countdown UI */ });
        if (_currentCountdown <= 0) {
          timer.cancel();
          _isCountingDown = false;
          _proceedWithActualRecording();
        }
      });
    } else {
      _proceedWithActualRecording();
    }
  }

  Future<void> _proceedWithActualRecording() async {
    if (Platform.isAndroid && _showFloatingControls && (await FlutterOverlayWindow.isPermissionGranted())) {
      await _showOverlay(); 
    } else if (Platform.isIOS && _showNotificationControls) {
      await _showPersistentNotification();
    }
    final int width = _resolutionValues[_selectedResolution]!['width']!;
    final int height = _resolutionValues[_selectedResolution]!['height']!;

    try {
      RecordOutput? response = await _screenRecorder?.startRecordScreen(
        fileName: "recording_${DateTime.now().millisecondsSinceEpoch}", // ed_screen_recorder adds .mp4
        audioEnable: true, 
        width: width, 
        height: height,
        dirPathToSave: _customOutputPath, // Pass custom path if set
      );

      if (response != null && response.success) {
        _isRecording = true;
        _isPaused = false;
        _recordingStatus = 'Recording...';
        _elapsedTime = Duration.zero;
        _recordingDuration = _formatDuration(_elapsedTime);
        setState(() {}); 
        _startDurationTimer();
        if (Platform.isAndroid) _updateOverlayState();
        if (Platform.isIOS) _showPersistentNotification(); // Show/Update notification
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start recording: ${response?.message ?? "Unknown error"}')),
          );
        }
        _recordingStatus = 'Failed to Start';
        setState(() {});
        if (Platform.isAndroid) _closeOverlay();
        if (Platform.isIOS) _cancelNotification();
      }
    } catch (e) {
      print('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error starting recording: $e')),);
      }
       _recordingStatus = 'Error';
       setState(() {});
       if (Platform.isAndroid) _closeOverlay();
       if (Platform.isIOS) _cancelNotification();
    }
  }

  Future<void> _stopRecording() async {
    if (_isCountingDown) {
      _countdownTimer?.cancel();
      setState(() {
        _isCountingDown = false;
        _currentCountdown = 0;
        _recordingStatus = 'Stopped';
      });
      return;
    }

    if (!_isRecording) return;

    _stopDurationTimer(); // Stop timer immediately

    RecordOutput? response;
    try {
      response = await _screenRecorder?.stopRecord();
    } catch (e) {
      print('Error stopping recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    } finally {
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordingStatus = 'Stopped';
      });
      if (Platform.isAndroid) _closeOverlay(); // Ensure overlay is closed
      if (Platform.isIOS) _cancelNotification(); // Ensure notification is cancelled
    }

    if (response != null && response.success && response.file.path.isNotEmpty) {
      final filePath = response.file.path; // This will be the custom path if _customOutputPath was used, or plugin's default path
      print('Recording stopped. File saved at: $filePath');

      if (_customOutputPath == null || _customOutputPath!.isEmpty) {
        // No custom path, so attempt to save to gallery
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Processing video for Gallery... Temp path: $filePath')),
          );
        }
        try {
          final bool? savedToGallery = await GallerySaver.saveVideo(filePath);
          if (mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar(); 
            if (savedToGallery == true) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Video saved to Gallery! Path: $filePath'),
                actions: [ 
                  SnackBarAction(
                    label: 'TRIM',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrimmingScreen(filePath: filePath),
                        ),
                      );
                    },
                  ),
                  SnackBarAction(
                    label: 'SHARE',
                    onPressed: () async {
                      final box = context.findRenderObject() as RenderBox?;
                      await SharePlus.instance.share(
                        ShareParams(
                          files: [XFile(filePath)],
                          text: 'Check out this screen recording!',
                          sharePositionOrigin: box?.localToGlobal(Offset.zero) & box?.size,
                        )
                      );
                    },
                  ),
                ],
              ));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to save video to Gallery. It might be in app\'s internal storage or the temp path shown.')),
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
        // Custom path was used, file is already there.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Video saved to: $_customOutputPath'),
            actions: [
              SnackBarAction(
                label: 'TRIM',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrimmingScreen(filePath: filePath), // filePath is the custom path here
                    ),
                  );
                },
              ),
              SnackBarAction(
                label: 'SHARE',
                onPressed: () async {
                  final box = context.findRenderObject() as RenderBox?;
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(filePath)], // filePath is the custom path here
                      text: 'Check out this screen recording!',
                      sharePositionOrigin: box?.localToGlobal(Offset.zero) & box?.size,
                    )
                  );
                },
              ),
            ],
          ));
        }
      }
    } else {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording stopped, but file path is invalid or saving failed: ${response?.message}')),
        );
      }
    }
  }

  Future<void> _pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    try {
      RecordOutput? response = await _screenRecorder?.pauseRecordScreen();
      if (response != null && response.success) {
        _stopDurationTimer();
        setState(() {
          _isPaused = true;
          _recordingStatus = 'Paused';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to pause recording: ${response?.message ?? "Unknown error"}')),
          );
        }
      }
    } catch (e) {
      print('Error pausing recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pausing recording: $e')),
        );
      }
    }
  }

  Future<void> _resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    try {
      RecordOutput? response = await _screenRecorder?.resumeRecordScreen();
      if (response != null && response.success) {
        _startDurationTimer(); // Resume timer
        setState(() {
          _isPaused = false;
          _recordingStatus = 'Recording...';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to resume recording: ${response?.message ?? "Unknown error"}')),
          );
        }
      }
    } catch (e) {
      print('Error resuming recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resuming recording: $e')),
        );
      }
    }
  }


  Widget _buildControls() {
    bool canChangeSettings = !_isRecording && !_isCountingDown;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SwitchListTile(
            title: const Text('Enable 3s Countdown'),
            value: _enableCountdown,
            onChanged: canChangeSettings ? (bool value) {
              setState(() {
                _enableCountdown = value;
              });
            } : null,
            activeColor: Colors.blueAccent,
          ),
          if (_enableCountdown) // Show duration dropdown only if countdown is enabled
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text('Countdown Duration:', style: TextStyle(fontSize: 16)),
                  DropdownButton<int>(
                    value: _countdownSeconds,
                    items: _availableCountdownDurations.map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('${value}s'),
                      );
                    }).toList(),
                    onChanged: canChangeSettings ? (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _countdownSeconds = newValue;
                        });
                      }
                    } : null, // canChangeSettings already covers _isRecording & _isCountingDown
                  ),
                ],
              ),
            ),
          // The SizedBox(height: 20) below was the original spacing after the _enableCountdown SwitchListTile.
          // We keep it here, or adjust as needed depending on visual preference after adding the dropdown.
          
          // Custom Output Folder Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Output Folder: ${_customOutputPath ?? "Default (Gallery)"}',
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ElevatedButton(
                      onPressed: canChangeSettings ? () async {
                        String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
                        if (selectedDirectory != null) {
                          setState(() {
                            _customOutputPath = selectedDirectory;
                          });
                          _saveCustomOutputPath(selectedDirectory);
                        }
                      } : null,
                      child: const Text('Select Folder'),
                    ),
                    const SizedBox(width: 10),
                    if (_customOutputPath != null)
                      TextButton(
                        onPressed: canChangeSettings ? () {
                          _clearCustomOutputPath(); // Already calls setState internally
                        } : null,
                        child: const Text('Clear Custom Folder'),
                      ),
                  ],
                ),
              ],
            ),
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
                onChanged: canChangeSettings ? (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedResolution = newValue;
                    });
                  }
                } : null,
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            _isCountingDown ? 'Starting in $_currentCountdown...' : _recordingStatus,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _isRecording ? (_isPaused ? Colors.orangeAccent : Colors.red) : (_isCountingDown ? Colors.orangeAccent : Colors.green)),
          ),
          const SizedBox(height: 10),
          Text(
            _recordingDuration,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Main Start/Stop Button
              IconButton(
                icon: Icon((_isRecording || _isCountingDown) ? Icons.stop_circle_outlined : Icons.play_circle_filled),
                iconSize: 72,
                color: (_isRecording || _isCountingDown) ? Colors.red : Colors.green,
                onPressed: (_isRecording && !_isPaused) // Only allow stop if recording and not paused
                    ? _stopRecording 
                    : ((!_isRecording && !_isCountingDown) // Only allow start if not recording and not counting down
                        ? _startRecordingFlow 
                        : null), // Disable if counting down or paused (pause handled by different button)
              ),
              // Pause/Resume Button
              if (_isRecording) // Show only if recording is active
                IconButton(
                  icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  iconSize: 72,
                  color: Colors.blueAccent,
                  onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                ),
            ],
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
