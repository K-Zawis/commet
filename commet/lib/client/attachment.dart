import 'dart:io';
import 'dart:typed_data';

import 'package:commet/utils/image_utils.dart';
import 'package:exif/exif.dart'
    show readExifFromBytes, readExifFromFile, IfdTag;
import 'package:flutter/material.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart' show XFile;

import 'package:commet/cache/file_provider.dart';
import 'package:commet/config/platform_utils.dart' show PlatformUtils;
import 'package:commet/utils/mime.dart';

abstract class Attachment {
  late String? name;
}

abstract class ProcessedAttachment {}

class PendingFileAttachment {
  static final _gpsTagRegExp = RegExp(r'gps', caseSensitive: false);

  final String? name;
  final String? path;
  final Uint8List? data;
  String? mimeType;
  final int? size;

  Uint8List? thumbnailFile; // todo: use locally saved temp files instead
  String? thumbnailMime;
  Size? dimensions;
  Duration? length;

  /// Private constructor forcing usage through factories or explicit setup
  PendingFileAttachment._({
    this.name,
    this.path,
    this.data,
    this.mimeType,
    this.size,
  });

  /// Factory for file-path based attachments (Native platforms)
  /// Streams magic header bytes off disk without loading the full file into RAM
  static Future<PendingFileAttachment> fromPath({
    required String path,
    String? name,
    String? mimeType,
    int? size,
  }) async {
    final resolvedMime = (mimeType != null && mimeType.isNotEmpty)
        ? mimeType
        : await Mime.resolveType(path);

    return PendingFileAttachment._(
      name: name ?? path.split(Platform.pathSeparator).last,
      path: path,
      mimeType: resolvedMime,
      size: size,
    );
  }

  /// Synchronous factory for in-memory byte sources (Web or Clipboard)
  factory PendingFileAttachment.fromBytes({
    required Uint8List data,
    String? name,
    String? mimeType,
  }) {
    final resolvedMime = (mimeType != null && mimeType.isNotEmpty)
        ? mimeType
        : Mime.lookupType(name ?? "", data: data);

    return PendingFileAttachment._(
      name: name,
      data: data,
      mimeType: resolvedMime,
      size: data.lengthInBytes,
    );
  }

  /// Factory for image_picker or desktop_drop XFiles (cross-platform web/native)
  static Future<PendingFileAttachment> fromXFile(XFile file) async {
    if (PlatformUtils.isWeb) {
      final bytes = await file.readAsBytes();
      return PendingFileAttachment.fromBytes(
        data: bytes,
        name: file.name,
        mimeType: file.mimeType,
      );
    }

    final size = await file.length();
    return PendingFileAttachment.fromPath(
      path: file.path,
      name: file.name,
      mimeType: file.mimeType,
      size: size,
    );
  }

  /// Factory that cleanly bridges from ImageUtils processing back into a PendingFileAttachment
  static Future<PendingFileAttachment> fromProcessedImage(
    ProcessedImageResult result,
  ) async {
    if (result.path.hasContent) {
      return await PendingFileAttachment.fromPath(
        path: result.path!,
        name: result.name,
        mimeType: result.mimeType,
        size: result.size,
      );
    }

    return PendingFileAttachment.fromBytes(
      data: result.data!,
      name: result.name,
      mimeType: result.mimeType,
    );
  }

  /// Streams EXIF tags safely without reading the whole file into RAM
  Future<Map<String, IfdTag>> readExif() async {
    if (!Mime.imageTypes.contains(mimeType)) return {};

    try {
      if (data != null) {
        return await readExifFromBytes(data!);
      } else if (path != null) {
        return await readExifFromFile(File(path!));
      }
    } catch (_) {}

    return {};
  }

  /// Returns true if the image contains location/GPS metadata
  Future<bool> hasGpsData() async {
    final tags = await readExif();
    return tags.keys.any(_gpsTagRegExp.hasMatch);
  }

  ImageProvider? getAsImage() {
    if (Mime.imageTypes.contains(mimeType)) {
      if (data != null) {
        return Image.memory(data!).image;
      } else if (path != null) {
        return Image.file(File(path!)).image;
      }
    }

    return null;
  }
}

class FileAttachment implements Attachment {
  @override
  String? name;
  int? fileSize;
  String? mimeType;
  FileProvider file;
  FileAttachment(this.file, {required this.name, this.fileSize, this.mimeType});
}

class ImageAttachment extends FileAttachment {
  final ImageProvider image;
  final double? width;
  final double? height;

  double get aspectRatio =>
      (width != null && height != null) ? (width! / height!) : 1;

  ImageAttachment(
    this.image,
    super.file, {
    required super.name,
    required super.mimeType,
    super.fileSize,
    this.width,
    this.height,
  });
}

class VideoAttachment extends FileAttachment {
  final ImageProvider? thumbnail;
  final double? width;
  final double? height;
  final Duration? duration;

  double get aspectRatio =>
      (width != null && height != null) ? (width! / height!) : 1;

  final Uri? streamUrl;

  VideoAttachment(super.file,
      {super.name,
      required super.mimeType,
      this.thumbnail,
      this.streamUrl,
      this.width,
      this.height,
      this.duration,
      super.fileSize});
}
