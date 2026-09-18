import 'dart:async';
import 'package:commet/client/attachment.dart';
import 'package:commet/client/components/photo_album_room/photo_album_room_component.dart';
import 'package:commet/client/matrix/matrix_room.dart';
import 'package:commet/utils/background_tasks/background_task_manager.dart';
import 'package:commet/utils/image_utils.dart';

class MatrixUploadPhotosTask implements BackgroundTaskWithIntegerProgress {
  List<PickedPhoto> files;

  MatrixRoom room;
  bool extractMetadata;
  bool sendOriginal;

  @override
  BackgroundTaskStatus status = BackgroundTaskStatus.running;

  StreamController<int> progressStream = StreamController.broadcast();
  StreamController controller = StreamController.broadcast();

  MatrixUploadPhotosTask(this.files, this.room,
      {this.extractMetadata = true, this.sendOriginal = false}) {
    total = files.length;
  }

  @override
  void Function()? action;

  @override
  bool get canCallAction => false;

  @override
  int current = 0;

  @override
  void dispose() {}

  @override
  String get label => "Uploading Photos";

  @override
  Stream<int> get onProgress => progressStream.stream;

  @override
  bool shouldRemoveTask = false;

  @override
  Stream<void> get statusChanged => controller.stream;

  @override
  late int total;

  Future<void> uploadImages() async {
    for (var i = 0; i < files.length; i++) {
      var file = files[i];

      var attachment = await file.toPendingAttachment();

      Map<String, dynamic> extraInfo = {};

      if (extractMetadata) {
        Map<String, dynamic> exifInfo = {};

        var exif = await attachment.readExif();

        for (var key in [
          "EXIF DateTimeOriginal",
          "EXIF DateTimeDigitized",
          "Image DateTime",
        ]) {
          if (exif.containsKey(key)) {
            var exifData = exif[key];
            if (exifData == null) continue;

            if (exifData.tagType == "ASCII") {
              exifInfo[key] = {
                "tag_type": exifData.tagType,
                "value": exifData.printable
              };
            }
          }
        }

        if (exifInfo.isNotEmpty) {
          extraInfo["chat.commet.exif"] = exifInfo;
        }
      }

      if (!sendOriginal) {
        final result = await ImageUtils.processImage(
          path: attachment.path,
          data: attachment.data,
          name: attachment.name,
          sourceMimeType: attachment.mimeType ?? 'image/jpeg',
          quality: 90,
        );

        attachment = await PendingFileAttachment.fromProcessedImage(result);
      }

      var processed = await room.processAttachment(attachment);

      if (processed != null) {
        await room.sendMessage(
            processedAttachments: [processed], fileExtraContent: extraInfo);
      }

      current += 1;
      progressStream.add(current);
    }

    status = BackgroundTaskStatus.completed;
    controller.add(null);

    Timer(const Duration(seconds: 5), () {
      shouldRemoveTask = true;
      controller.add(null);
    });
  }
}
