import 'dart:io';
import 'dart:typed_data';

import 'package:commet/client/attachment.dart';
import 'package:commet/client/client.dart';
import 'package:commet/client/components/photo_album_room/photo_album_timeline.dart';
import 'package:commet/client/components/room_component.dart';
import 'package:commet/config/platform_utils.dart' show PlatformUtils;

import 'package:commet/utils/image_utils.dart';

class PickedPhoto {
  String? filepath;
  String name;
  final Future<Uint8List> Function()? getBytes;
  final String? mimeType;
  final int? size;

  PickedPhoto({
    this.filepath,
    required this.name,
    this.getBytes,
    this.mimeType,
    this.size,
  });

  /// Factory to cleanly map a ProcessedImageResult back into a PickedPhoto
  static PickedPhoto fromProcessedImage(ProcessedImageResult result) {
    return PickedPhoto(
      filepath: result.path,
      name: result.name,
      mimeType: result.mimeType,
      size: result.size,
      getBytes: result.data != null
          ? () async => result.data!
          : (result.path.hasContent
              ? () => File(result.path!).readAsBytes()
              : null),
    );
  }

  /// Internal bridge to stream via PendingFileAttachment without OOMs
  Future<PendingFileAttachment> toPendingAttachment() async {
    if (!PlatformUtils.isWeb && filepath.hasContent) {
      return await PendingFileAttachment.fromPath(
        path: filepath!,
        name: name,
        mimeType: mimeType,
        size: size,
      );
    }

    if (getBytes != null) {
      final bytes = await getBytes!();
      return PendingFileAttachment.fromBytes(
        data: bytes,
        name: name,
        mimeType: mimeType,
      );
    }

    throw StateError("PickedPhoto has no valid filepath or getBytes provider.");
  }
}

abstract class PhotoAlbumRoom<R extends Client, T extends Room>
    implements RoomComponent<R, T> {
  bool get canUpload;

  Future<void> uploadPhotos(
    List<PickedPhoto> photos, {
    bool sendOriginal = false,
    bool extractMetadata = true,
  });

  Future<PhotoAlbumTimeline> getTimeline();
}
