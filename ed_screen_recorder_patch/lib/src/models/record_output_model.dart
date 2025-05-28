import 'dart:convert';
import 'dart:io';

RecordOutput recordOutputFromJson(String str) =>
    RecordOutput.fromJson(json.decode(str));

String recordOutputToJson(RecordOutput data) => json.encode(data.toJson());

class RecordOutput {
  RecordOutput({
    required this.success,
    required this.file,
    required this.isProgress,
    required this.eventName,
    required this.message,
    required this.videoHash,
    required this.startDate,
    required this.endDate,
  });

  bool success;
  File file;
  bool isProgress;
  String eventName;
  String? message;
  String videoHash;
  int startDate;
  int? endDate;

  factory RecordOutput.fromJson(Map<String, dynamic> json) {
    return RecordOutput(
      success: json["success"],
      // Ensure 'file' is treated as a String path before creating a File object
      file: File(json["file"] as String),
      isProgress: json["isProgress"],
      eventName: json["eventname"],
      message: json["message"],
      videoHash: json["videohash"],
      startDate: json['startdate'],
      endDate: json['enddate'],
    );
  }

  Map<String, dynamic> toJson() => {
        "success": success,
        // When serializing, ensure 'file.path' is used if 'file' is a File object
        "file": file.path,
        "isProgress": isProgress, // Corrected from "progressing"
        "eventname": eventName,
        "message": message,
        "videohash": videoHash,
        "startdate": startDate,
        "enddate": endDate,
      };
}
