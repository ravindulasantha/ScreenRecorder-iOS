package com.ed_screen_recorder.ed_screen_recorder

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Environment
import androidx.annotation.NonNull
import com.hbisoft.hbrecorder.HBRecorder
import com.hbisoft.hbrecorder.HBRecorderListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import org.json.JSONObject
import java.util.HashMap

class EdScreenRecorderPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener, HBRecorderListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activityPluginBinding: ActivityPluginBinding? = null

    private var hbRecorder: HBRecorder? = null
    private var isRecording = false
    private var currentMethodResult: Result? = null
    private var startRecordArgs: HashMap<String, Any>? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        this.flutterPluginBinding = flutterPluginBinding
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ed_screen_recorder")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        currentMethodResult = result
        when (call.method) {
            "startRecordScreen" -> {
                startRecordArgs = call.arguments as HashMap<String, Any>
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    if (hbRecorder == null && activity != null) {
                        hbRecorder = HBRecorder(activity!!, this)
                        // Configure HBRecorder based on args
                        configureHBRecorder(startRecordArgs!!)
                    }
                    if (hbRecorder?.isBusyRecording == true) {
                        sendResponse("ALREADY_RECORDING", "A recording is already in progress.", false)
                        return
                    }
                    requestMediaProjectionPermission()
                } else {
                    sendResponse("API_LEVEL_ERROR", "Screen recording requires Android Lollipop (API 21) or higher.", false)
                }
            }
            "stopRecordScreen" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && hbRecorder != null && hbRecorder!!.isBusyRecording) {
                    hbRecorder!!.stopScreenRecording()
                } else {
                    sendResponse("NOT_RECORDING", "No recording is currently in progress to stop.", false)
                }
            }
            "pauseRecordScreen" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) { // API Level 24 for pause
                    if (hbRecorder != null && hbRecorder!!.isBusyRecording) {
                        hbRecorder!!.pauseScreenRecording()
                        sendResponse("PAUSED", "Recording paused.", true, eventName = "pauseRecordScreen")
                    } else {
                        sendResponse("NOT_RECORDING", "No recording in progress to pause.", false, eventName = "pauseRecordScreen")
                    }
                } else {
                    sendResponse("API_LEVEL_ERROR", "Pause/resume requires Android Nougat (API 24) or higher.", false, eventName = "pauseRecordScreen")
                }
            }
            "resumeRecordScreen" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) { // API Level 24 for resume
                     if (hbRecorder != null && hbRecorder!!.isBusyRecording) { // Check if it's paused is tricky, HBRecorder doesn't expose state
                        hbRecorder!!.resumeScreenRecording()
                        sendResponse("RESUMED", "Recording resumed.", true, eventName = "resumeRecordScreen")
                    } else {
                        sendResponse("NOT_RECORDING", "No recording in progress to resume.", false, eventName = "resumeRecordScreen")
                    }
                } else {
                    sendResponse("API_LEVEL_ERROR", "Pause/resume requires Android Nougat (API 24) or higher.", false, eventName = "resumeRecordScreen")
                }
            }
            else -> {
                result.notImplemented()
                currentMethodResult = null
            }
        }
    }

    private fun configureHBRecorder(args: HashMap<String, Any>) {
        val fileName = args["filename"] as String
        val dirPathToSave = args["dirpathtosave"] as? String
        // val addTimeCode = args["addtimecode"] as? Boolean ?: true // HBRecorder does this by default
        val videoFrame = args["videoframe"] as? Int ?: 30
        val videoBitrate = args["videobitrate"] as? Int ?: 3000000
        // val fileOutputFormat = args["fileoutputformat"] as? String // HBRecorder uses MP4 by default
        val audioEnable = args["audioenable"] as? Boolean ?: true
        val width = args["width"] as? Int
        val height = args["height"] as? Int

        hbRecorder?.setVideoEncoder("H264") // Default is MPEG_4_SP, H264 is better
        hbRecorder?.setAudioSource("MIC") // or CAMCORDER if you want internal audio (requires more setup)
        hbRecorder?.isAudioEnabled(audioEnable)
        hbRecorder?.setVideoFrameRate(videoFrame)
        hbRecorder?.setVideoBitrate(videoBitrate)

        if (width != null && height != null) {
            hbRecorder?.setScreenDimensions(height, width) // HBRecorder takes height, width
        }
        
        val outputUri: String
        if (dirPathToSave != null && dirPathToSave.isNotEmpty()) {
            val dir = File(dirPathToSave)
            if (!dir.exists()) {
                dir.mkdirs()
            }
            outputUri = "$dirPathToSave/$fileName.mp4"
        } else {
            // Default to Movies directory
            val moviesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
            outputUri = "$moviesDir/$fileName.mp4"
        }
        hbRecorder?.setOutputPath(outputUri)
    }

    private fun requestMediaProjectionPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val mediaProjectionManager = context?.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager?
            if (mediaProjectionManager != null && activity != null) {
                activity!!.startActivityForResult(
                    mediaProjectionManager.createScreenCaptureIntent(),
                    SCREEN_RECORD_REQUEST_CODE
                )
            } else {
                 sendResponse("ERROR", "MediaProjectionManager not available.", false)
            }
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    hbRecorder?.startScreenRecording(data, resultCode)
                    isRecording = true
                    // HBonStart will send the success response
                }
                return true
            } else {
                sendResponse("PERMISSION_DENIED", "Screen recording permission denied.", false)
            }
        }
        return false
    }

    // HBRecorderListener methods
    override fun HBRecorderOnStart() {
        isRecording = true
        val filePath = hbRecorder?.filePath ?: ""
        sendResponse("RECORDING_STARTED", "Recording started successfully.", true, filePath, "startRecordScreen")
    }

    override fun HBRecorderOnComplete() {
        isRecording = false
        val filePath = hbRecorder?.filePath ?: "" // Get file path before reset
        hbRecorder?.stopScreenRecording() // Ensure it's fully stopped and reset
        sendResponse("RECORDING_COMPLETE", "Recording completed.", true, filePath, "stopRecordScreen")
        hbRecorder = null // Reset for next recording
    }

    override fun HBRecorderOnError(errorCode: Int, reason: String?) {
        isRecording = false
        sendResponse("RECORDER_ERROR", "HBRecorder error $errorCode: $reason", false)
        hbRecorder = null // Reset on error
    }
    
    // Not used by HBRecorder 3.0.1 from docs, but kept for compatibility if underlying changes
    override fun HBRecorderOnPause() {
        // This callback is not explicitly in HBRecorder 3.0.1 docs,
        // "pauseRecordScreen" method channel call directly confirms.
    }

    override fun HBRecorderOnResume() {
        // This callback is not explicitly in HBRecorder 3.0.1 docs,
        // "resumeRecordScreen" method channel call directly confirms.
    }


    private fun sendResponse(message: String, detailedMessage: String?, success: Boolean, filePath: String? = null, eventName: String? = null) {
        val response = JSONObject()
        response.put("success", success)
        response.put("file", filePath ?: "")
        response.put("isProgress", isRecording) // isProgress might mean "is currently recording"
        response.put("eventname", eventName ?: "general")
        response.put("message", message + (if (detailedMessage != null) " - $detailedMessage" else ""))
        // videoHash, startDate, endDate are not directly available from HBRecorder in this way
        // These were part of the original plugin's Dart-side logic
        response.put("videohash", startRecordArgs?.get("videohash") as? String ?: "")
        response.put("startdate", startRecordArgs?.get("startdate") as? Long ?: 0)
        response.put("enddate", if (eventName == "stopRecordScreen") System.currentTimeMillis() else 0)

        currentMethodResult?.success(response.toString())
        currentMethodResult = null // Consume the result callback
        startRecordArgs = if (eventName == "stopRecordScreen" || eventName == "RECORDER_ERROR") null else startRecordArgs // Clear args after stop/error
    }

    // ActivityAware methods
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityPluginBinding = binding
        binding.addActivityResultListener(this)
        // It's safer to initialize HBRecorder when startRecordScreen is called and activity is confirmed non-null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        activityPluginBinding?.removeActivityResultListener(this)
        activityPluginBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityPluginBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
        hbRecorder?.stopScreenRecording() // Clean up if recording
        hbRecorder = null
        activityPluginBinding?.removeActivityResultListener(this)
        activityPluginBinding = null
    }
    
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        this.flutterPluginBinding = null
        this.context = null
        hbRecorder?.stopScreenRecording()
        hbRecorder = null
    }

    companion object {
        private const val SCREEN_RECORD_REQUEST_CODE = 123 // Or any unique integer
    }
}
