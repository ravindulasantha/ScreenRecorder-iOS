import Flutter
import UIKit
import ReplayKit
import Photos

struct RecorderConfig {
    var fileName: String = ""
    var dirPathToSave:NSString = ""
    var isAudioEnabled: Bool = false
    var addTimeCode: Bool! = false
    var filePath: NSString = ""
    var videoFrame: Int?
    var videoBitrate: Int?
    var fileOutputFormat: String = ""
    var fileExtension: String = ""
    var videoHash: String = ""
    var width:Int?
    var height:Int?
}

struct JsonObj : Codable {
    var success: Bool!
    var file: String
    var isProgress: Bool!
    var eventname: String!
    var message: String?
    var videohash: String!
    var startdate: Int?
    var enddate: Int?
}

public class SwiftEdScreenRecorderPlugin: NSObject, FlutterPlugin {

    let recorder = RPScreenRecorder.shared()
    var videoOutputURL : URL?
    var videoWriter : AVAssetWriter?
    var audioInput:AVAssetWriterInput!
    var videoWriterInput : AVAssetWriterInput?

    var success: Bool = false
    var startDate: Int?
    var endDate: Int?
    var isProgress: Bool = false
    var eventName: String = ""
    var message: String = ""


    var myResult: FlutterResult?

    var recorderConfig:RecorderConfig = RecorderConfig()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ed_screen_recorder", binaryMessenger: registrar.messenger())
        let instance = SwiftEdScreenRecorderPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

        if(call.method == "startRecordScreen"){
            let args = call.arguments as? Dictionary<String, Any>
            recorderConfig = RecorderConfig()
            recorderConfig.isAudioEnabled=((args?["audioenable"] as? Bool?)! ?? false)!
            // Ensure filename has .mp4 extension, original plugin might have handled this differently
            let baseFileName = (args?["filename"] as? String)!
            if baseFileName.hasSuffix(".mp4") {
                recorderConfig.fileName = baseFileName
            } else {
                recorderConfig.fileName = "\(baseFileName).mp4"
            }
            recorderConfig.dirPathToSave = ((args?["dirpathtosave"] as? NSString) ?? "")
            recorderConfig.addTimeCode=((args?["addtimecoe"] as? Bool?)! ?? false)! // Note: 'addtimecoe' might be a typo in original, check if used
            recorderConfig.videoFrame=(args?["videoframe"] as? Int)!
            recorderConfig.videoBitrate=(args?["videobitrate"] as? Int)!
            recorderConfig.fileOutputFormat=(args?["fileoutputformat"] as? String)!
            recorderConfig.fileExtension=(args?["fileextension"] as? String)!
            recorderConfig.videoHash=(args?["videohash"] as? String)!
            recorderConfig.width=(args?["width"] as? Int)
            recorderConfig.height=(args?["height"] as? Int)

            if UIDevice.current.orientation.isLandscape {
                if(recorderConfig.width == nil) {
                    recorderConfig.width = Int(UIScreen.main.nativeBounds.height)
                }
                if(recorderConfig.height == nil) {
                    recorderConfig.height = Int(UIScreen.main.nativeBounds.width)
                }
            }else{
                if(recorderConfig.width == nil) {
                    recorderConfig.width = Int(UIScreen.main.nativeBounds.width)
                }
                if(recorderConfig.height == nil) {
                    recorderConfig.height = Int(UIScreen.main.nativeBounds.height)
                }
            }
            self.success=Bool(startRecording(width: Int32(recorderConfig.width!) ,height: Int32(recorderConfig.height!)));
            self.startDate=Int(NSDate().timeIntervalSince1970 * 1_000)
            // myResult = result // Storing result can be problematic if multiple calls come quickly
            let jsonObject: JsonObj = JsonObj(
                success: Bool(self.success),
                file: String("\(recorderConfig.filePath)/\(recorderConfig.fileName)"),
                isProgress: Bool(self.isProgress),
                eventname: String("startRecordScreen"), // Set event name
                message: String(self.message),
                videohash: String(recorderConfig.videoHash),
                startdate: Int(self.startDate ?? Int(NSDate().timeIntervalSince1970 * 1_000)),
                enddate: Int(self.endDate ?? 0)
            )
            let encoder = JSONEncoder()
            let json = try! encoder.encode(jsonObject)
            let jsonStr = String(data:json,encoding: .utf8)
            result(jsonStr)
        }else if(call.method == "stopRecordScreen"){
            if(videoWriter != nil || recorder.isRecording){ // Check recorder.isRecording as well
                self.isProgress=Bool(false) // Should be set before async operations
                self.eventName=String("stopRecordScreen")
                self.endDate=Int(NSDate().timeIntervalSince1970 * 1_000)
                // Call stopRecording and handle its async nature properly
                stopRecording { [weak self] success, message in
                    guard let self = self else { return }
                    self.success = success
                    self.message = message ?? (success ? "Success" : "Failure")
                    
                    let jsonObject: JsonObj = JsonObj(
                        success: Bool(self.success),
                        file: String("\(self.recorderConfig.filePath)/\(self.recorderConfig.fileName)"),
                        isProgress: Bool(self.isProgress),
                        eventname: String(self.eventName),
                        message: String(self.message),
                        videohash: String(self.recorderConfig.videoHash),
                        startdate: Int(self.startDate ?? Int(NSDate().timeIntervalSince1970 * 1_000)),
                        enddate: Int(self.endDate ?? 0)
                    )
                    let encoder = JSONEncoder()
                    let json = try! encoder.encode(jsonObject)
                    let jsonStr = String(data:json,encoding: .utf8)
                    result(jsonStr)
                }
            } else {
                self.success=Bool(false)
                self.message="Recording not active or writer not initialized."
                let jsonObject: JsonObj = JsonObj(
                    success: Bool(self.success),
                    file: String("\(recorderConfig.filePath)/\(recorderConfig.fileName)"), // May not be valid if never started
                    isProgress: Bool(false),
                    eventname: String("stopRecordScreen"),
                    message: String(self.message),
                    videohash: String(recorderConfig.videoHash), // May not be valid
                    startdate: Int(self.startDate ?? 0),
                    enddate: Int(NSDate().timeIntervalSince1970 * 1_000)
                )
                let encoder = JSONEncoder()
                let json = try! encoder.encode(jsonObject)
                let jsonStr = String(data:json,encoding: .utf8)
                result(jsonStr)
            }
        } else if (call.method == "pauseRecordScreen") {
            // Implementation for pauseRecordScreen will go here in Step 3
            if #available(iOS 14.0, *) {
                if recorder.isRecording {
                    recorder.pauseRecording()
                    // Send success response
                    let jsonObject: JsonObj = JsonObj(
                        success: Bool(true),
                        file: String("\(self.recorderConfig.filePath)/\(self.recorderConfig.fileName)"),
                        isProgress: Bool(self.isProgress), // isProgress should reflect that recording is paused, not stopped
                        eventname: String("pauseRecordScreen"),
                        message: String("Recording paused successfully."),
                        videohash: String(self.recorderConfig.videoHash),
                        startdate: Int(self.startDate ?? 0),
                        enddate: Int(self.endDate ?? 0)
                    )
                    let encoder = JSONEncoder()
                    let json = try! encoder.encode(jsonObject)
                    let jsonStr = String(data:json,encoding: .utf8)
                    result(jsonStr)
                } else {
                    // Send error response - not recording
                    let jsonObject: JsonObj = JsonObj(
                        success: Bool(false),
                        file: String(""),
                        isProgress: Bool(false),
                        eventname: String("pauseRecordScreen"),
                        message: String("Recording not in progress or already stopped."),
                        videohash: String(""),
                        startdate: Int(0),
                        enddate: Int(0)
                    )
                    let encoder = JSONEncoder()
                    let json = try! encoder.encode(jsonObject)
                    let jsonStr = String(data:json,encoding: .utf8)
                    result(jsonStr)
                }
            } else {
                // Send error response - iOS version not supported
                let jsonObject: JsonObj = JsonObj(
                    success: Bool(false),
                    file: String(""),
                    isProgress: Bool(false),
                    eventname: String("pauseRecordScreen"),
                    message: String("Pause/resume screen recording requires iOS 14.0 or later."),
                    videohash: String(""),
                    startdate: Int(0),
                    enddate: Int(0)
                )
                let encoder = JSONEncoder()
                let json = try! encoder.encode(jsonObject)
                let jsonStr = String(data:json,encoding: .utf8)
                result(jsonStr)
            }
        }
        else if (call.method == "resumeRecordScreen") {
            if #available(iOS 14.0, *) {
                if recorder.isRecording { // Check if it's actually recording (and implicitly paused)
                    recorder.resumeRecording()
                    // Send success response
                    let jsonObject: JsonObj = JsonObj(
                        success: Bool(true),
                        file: String("\(self.recorderConfig.filePath)/\(self.recorderConfig.fileName)"),
                        isProgress: Bool(self.isProgress), // isProgress should reflect that recording is active
                        eventname: String("resumeRecordScreen"),
                        message: String("Recording resumed successfully."),
                        videohash: String(self.recorderConfig.videoHash),
                        startdate: Int(self.startDate ?? 0),
                        enddate: Int(self.endDate ?? 0)
                    )
                    let encoder = JSONEncoder()
                    let json = try! encoder.encode(jsonObject)
                    let jsonStr = String(data:json,encoding: .utf8)
                    result(jsonStr)
                } else {
                     // Send error response - not recording or not paused
                    let jsonObject: JsonObj = JsonObj(
                        success: Bool(false),
                        file: String(""),
                        isProgress: Bool(false),
                        eventname: String("resumeRecordScreen"),
                        message: String("Recording not in progress or not paused."),
                        videohash: String(""),
                        startdate: Int(0),
                        enddate: Int(0)
                    )
                    let encoder = JSONEncoder()
                    let json = try! encoder.encode(jsonObject)
                    let jsonStr = String(data:json,encoding: .utf8)
                    result(jsonStr)
                }
            } else {
                // Send error response - iOS version not supported
                 let jsonObject: JsonObj = JsonObj(
                    success: Bool(false),
                    file: String(""),
                    isProgress: Bool(false),
                    eventname: String("resumeRecordScreen"),
                    message: String("Pause/resume screen recording requires iOS 14.0 or later."),
                    videohash: String(""),
                    startdate: Int(0),
                    enddate: Int(0)
                )
                let encoder = JSONEncoder()
                let json = try! encoder.encode(jsonObject)
                let jsonStr = String(data:json,encoding: .utf8)
                result(jsonStr)
            }
        }
    }

    func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }

    @objc func startRecording(width: Int32, height: Int32) -> Bool {
        var res : Bool = true
        if(recorder.isAvailable){
            if !recorderConfig.dirPathToSave.isEqual(to: "") { // Check for empty string
                recorderConfig.filePath = (recorderConfig.dirPathToSave ) as NSString
                self.videoOutputURL = URL(fileURLWithPath: String(recorderConfig.filePath.appendingPathComponent(recorderConfig.fileName ) ))
            } else {
                // Default to documents directory if dirPathToSave is empty
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
                recorderConfig.filePath = documentsPath
                self.videoOutputURL = URL(fileURLWithPath: String(recorderConfig.filePath.appendingPathComponent(recorderConfig.fileName ) ))
            }
            
            // Check if file exists and remove it
            do {
                let fileManager = FileManager.default
                if (fileManager.fileExists(atPath: videoOutputURL!.path)){
                    try FileManager.default.removeItem(at: videoOutputURL!)}
            } catch let fileError as NSError{
                self.message="Error deleting existing file: \(fileError.localizedDescription)"
                // res = Bool(false); // Decide if this is a fatal error for starting
            }

            do {
                try videoWriter = AVAssetWriter(outputURL: videoOutputURL!, fileType: AVFileType.mp4)
                self.message="Writer initialized for video path: \(videoOutputURL!.path)"
            } catch let writerError as NSError {
                self.message="AVAssetWriter error: \(writerError.localizedDescription)"
                videoWriter = nil;
                return Bool(false); // Cannot proceed without writer
            }
            
            if #available(iOS 11.0, *) {
                recorder.isMicrophoneEnabled = recorderConfig.isAudioEnabled
                let videoSettings: [String : Any] = [
                    AVVideoCodecKey  : AVVideoCodecType.h264,
                    AVVideoWidthKey  : NSNumber.init(value: width),
                    AVVideoHeightKey : NSNumber.init(value: height),
                    AVVideoCompressionPropertiesKey: [
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                        AVVideoAverageBitRateKey: recorderConfig.videoBitrate!
                    ] as [String : Any],
                ]
                self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings);
                self.videoWriterInput?.expectsMediaDataInRealTime = true;
                
                if let videoWriterInput = self.videoWriterInput, self.videoWriter?.canAdd(videoWriterInput) ?? false {
                    self.videoWriter!.add(videoWriterInput)
                } else {
                    self.message = "Cannot add video input to writer"
                    return Bool(false)
                }

                if(recorderConfig.isAudioEnabled) {
                    let audioOutputSettings: [String : Any] = [
                        AVNumberOfChannelsKey : 2,
                        AVFormatIDKey : kAudioFormatMPEG4AAC,
                        AVSampleRateKey: 44100,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]
                    self.audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioOutputSettings)
                    self.audioInput?.expectsMediaDataInRealTime = true;
                    if let audioInput = self.audioInput, self.videoWriter?.canAdd(audioInput) ?? false {
                         self.videoWriter!.add(audioInput);
                    } else {
                        self.message = "Cannot add audio input to writer"
                        // Not necessarily fatal if video only is acceptable
                    }
                }

                recorder.startCapture(handler: { (cmSampleBuffer, rpSampleType, error) in guard error == nil else {
                    self.message = "Capture error: \(error!.localizedDescription)"
                    // Consider how to propagate this error - it's async
                    return
                    }
                    switch rpSampleType {
                    case RPSampleBufferType.video:
                        if self.videoWriter?.status == AVAssetWriter.Status.unknown {
                            self.videoWriter?.startWriting()
                            self.videoWriter?.startSession(atSourceTime:  CMSampleBufferGetPresentationTimeStamp(cmSampleBuffer));
                        }else if self.videoWriter?.status == AVAssetWriter.Status.writing {
                            if (self.videoWriterInput?.isReadyForMoreMediaData == true) {
                                if  self.videoWriterInput?.append(cmSampleBuffer) == false {
                                    // self.message="Error appending video buffer"; // This is too noisy
                                    print("Error appending video buffer: \(self.videoWriter?.error?.localizedDescription ?? "Unknown error")")
                                }
                            }
                        }
                    case RPSampleBufferType.audioMic:
                        if(self.recorderConfig.isAudioEnabled){
                            if self.audioInput?.isReadyForMoreMediaData == true {
                                if self.audioInput?.append(cmSampleBuffer) == false {
                                     // print("Error appending audio buffer: \(self.videoWriter?.error?.localizedDescription ?? "Unknown error")")
                                }
                            }
                        }
                    default:
                        // print("Ignoring sample type: \(rpSampleType.rawValue)")
                        break;
                    }
                }){(error) in guard error == nil else {
                    self.message = "Error starting capture session: \(error!.localizedDescription)"
                    // Propagate this error
                    return
                }
                    self.isProgress = true // Recording has started
                    self.eventName = "startRecordScreen"
                    self.message = "Recording started" // Initial success message
                }
            } else {
                 self.message = "iOS 11.0+ is required for screen recording."
                 res = Bool(false)
            }
        } else {
            self.message = "Screen recording is not available on this device."
            res = Bool(false)
        }
        return  Bool(res)
    }

    @objc func stopRecording(completion: @escaping (Bool, String?) -> Void) {
        var res: Bool = true
        var localMessage: String? = "Recording stopped."

        if recorder.isRecording {
            if #available(iOS 11.0, *) {
                recorder.stopCapture { error in
                    if let error = error {
                        res = false
                        localMessage = "Error in stopCapture: \(error.localizedDescription)"
                        self.videoWriter?.cancelWriting() // Cancel writer on capture error
                        completion(res, localMessage)
                    } else {
                        // Ensure writer is in writing state before finishing
                        if self.videoWriter?.status == .writing {
                            self.videoWriterInput?.markAsFinished()
                            if self.recorderConfig.isAudioEnabled {
                                self.audioInput?.markAsFinished()
                            }

                            self.videoWriter?.finishWriting {
                                if self.videoWriter?.status == .completed {
                                    PHPhotoLibrary.shared().performChanges({
                                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.videoOutputURL!)
                                    }) { success, error in
                                        if success {
                                            localMessage = "Video saved to gallery."
                                        } else {
                                            res = false
                                            localMessage = "Failed to save video: \(error?.localizedDescription ?? "unknown error")"
                                        }
                                        completion(res, localMessage)
                                    }
                                } else {
                                    res = false
                                    localMessage = "Failed to finish writing with status: \(self.videoWriter?.status.rawValue ?? -1). Error: \(self.videoWriter?.error?.localizedDescription ?? "N/A")"
                                    completion(res, localMessage)
                                }
                            }
                        } else {
                            res = false
                            localMessage = "Attempted to stop recording while writer status is: \(self.videoWriter?.status.rawValue ?? -1). Not 'writing'."
                            completion(res, localMessage)
                        }
                    }
                }
            } else {
                res = false
                localMessage = "iOS 11.0+ is required for screen recording."
                completion(res, localMessage)
            }
        } else {
            localMessage = "Recording has not been started or already stopped."
            res = false // Or true if "already stopped" is considered success for a stop call
            completion(res, localMessage)
        }
    }
}
