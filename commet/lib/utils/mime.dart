import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:mime/mime.dart' as mime;

class Mime {
  static final mime.MimeTypeResolver _resolver = mime.MimeTypeResolver()
    ..addMagicNumber([0x42, 0x4d], "image/bmp")
    ..addMagicNumber([0x3c, 0x73, 0x76, 0x67], "image/svg+xml");

  static int get magicNumbersMaxLength => _resolver.magicNumbersMaxLength;

  static const displayableImageTypes = {
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/bmp",
    "image/webp"
  };

  static const imageTypes = {
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/webp",
    "image/bmp",
  };

  static const gifTypes = {
    "image/gif",
    "image/webp",
  };

  static const playableAudioTypes = {
    "audio/x-wav",
    "audio/ogg",
    "audio/wav",
    "audio/mp3",
    "audio/mpeg",
  };

  static bool isText(String mime) => mime.startsWith("text/");

  static const videoTypes = {
    "video/mp4",
    "video/mpeg",
    "video/webm",
    "video/quicktime"
  };

  static const videoStreamTypes = {"application/vnd.apple.mpegurl"};

  static const archiveTypes = {
    "application/x-7z-compressed",
    "application/x-bzip",
    "application/x-bzip2",
    "application/gzip"
  };

  static const extensionToMime = {
    "jpeg": "image/jpeg",
    "jpg": "image/jpeg",
    "png": "image/png",
    "gif": "image/gif",
    "webp": "image/webp",
    "bmp": "image/bmp"
  };

  static const mimeToExtension = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/gif": "gif",
    "image/webp": "webp",
    "image/bmp": "bmp",
  };

  static String? extensionFromMime(String mimeType) {
    return mimeToExtension[mimeType.toLowerCase()];
  }

  static String? fromExtenstion(String extension) {
    return extensionToMime.tryGet(extension);
  }

  static IconData toIcon(String? mimeType) {
    if (imageTypes.contains(mimeType)) return Icons.image;
    if (videoTypes.contains(mimeType)) return Icons.video_file_rounded;
    if (archiveTypes.contains(mimeType)) return Icons.folder_zip;
    if (playableAudioTypes.contains(mimeType)) return Icons.audio_file;
    return Icons.file_present;
  }

  static String? lookupType(String filepath, {Uint8List? data}) {
    return _resolver.lookup(filepath, headerBytes: data);
  }

  static Future<String> resolveType(
    String? path, {
    Uint8List? data,
  }) async {
    final hasInMemoryBytes = data != null && data.isNotEmpty;
    if (hasInMemoryBytes)
      return lookupType(path ?? "", data: data)?.toLowerCase() ?? "";

    final canStreamFromFile = !kIsWeb && path != null && path.isNotEmpty;
    if (canStreamFromFile) return _resolveFromFileHeaderStream(path);

    final hasPathOnly = path != null && path.isNotEmpty;
    if (hasPathOnly) return lookupType(path)?.toLowerCase() ?? "";

    return "";
  }

  static Future<String> _resolveFromFileHeaderStream(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return lookupType(path)?.toLowerCase() ?? "";

      final headerByteStream = file.openRead(0, magicNumbersMaxLength);
      final headerBytes = (await headerByteStream.first) as Uint8List;
      return lookupType(path, data: headerBytes)?.toLowerCase() ?? "";
    } catch (_) {}

    return lookupType(path)?.toLowerCase() ?? "";
  }
}
