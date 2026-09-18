import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:commet/utils/mime.dart';

extension NullableStringUtils on String? {
  /// Returns `true` if the string is not null and not empty.
  bool get isNotNullOrEmpty => this != null && this!.isNotEmpty;

  /// Returns `true` if the string is either null or empty.
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// Alias for `isNotNullOrEmpty` for cleaner conditional reading.
  bool get hasContent => isNotNullOrEmpty;
}

class ProcessedImageResult {
  final String? path;
  final Uint8List? data;
  final String mimeType;
  final int size;
  final String name;

  ProcessedImageResult({
    this.path,
    this.data,
    required this.mimeType,
    required this.size,
    required this.name,
  });
}

class ImageUtils {
  static Future<ui.Image> imageProviderToImage(ImageProvider provider) async {
    Completer<ui.Image> completer = Completer<ui.Image>();

    provider
        .resolve(const ImageConfiguration())
        .addListener(ImageStreamListener((info, synchronousCall) {
      if (!completer.isCompleted) {
        completer.complete(info.image);
      }
    }));
    return completer.future;
  }

  /// Master image processing function.
  /// Handles EXIF stripping, format conversion, and quality compression.
  /// Automatically streams zero-RAM disk-to-disk natively when a path is available.
  /// Safely passes through unparseable formats (like SVG) untouched.
  static Future<ProcessedImageResult> processImage({
    String? path,
    Uint8List? data,
    String? name,
    String sourceMimeType = 'image/jpeg',
    int quality = 100,
    bool stripExif = true,
  }) async {
    final mime = sourceMimeType.toLowerCase();

    final String fallbackName = path.hasContent ? p.basename(path!) : "image";
    final String effectiveName = name.hasContent ? name! : fallbackName;

    final String rawName = p.basenameWithoutExtension(effectiveName);
    final String ext = Mime.extensionFromMime(mime) ?? 'jpg';
    final String targetName = "$rawName.$ext";

    final format = switch (mime) {
      'image/jpeg' || 'image/jpg' => CompressFormat.jpeg,
      'image/png' => CompressFormat.png,
      'image/webp' => CompressFormat.webp,
      _ => null,
    };

    final bool supportsNativeCompress = !kIsWeb &&
        (Platform.isAndroid ||
            Platform.isIOS ||
            Platform.isMacOS ||
            Platform.isLinux);

    if (supportsNativeCompress && format != null) {
      try {
        if (path.hasContent) {
          final tempDir = await getTemporaryDirectory();
          final targetPath = p.join(
            tempDir.path,
            "processed_${DateTime.now().millisecondsSinceEpoch}_$targetName",
          );

          final result = await FlutterImageCompress.compressAndGetFile(
            path!,
            targetPath,
            keepExif: !stripExif,
            quality: quality,
            format: format,
          );

          if (result != null) {
            return ProcessedImageResult(
              path: result.path,
              mimeType: mime,
              size: await result.length(),
              name: targetName,
            );
          }
        }

        if (data != null && data.isNotEmpty) {
          final processedData = await FlutterImageCompress.compressWithList(
            data,
            keepExif: !stripExif,
            quality: quality,
            format: format,
          );

          return ProcessedImageResult(
            data: processedData,
            size: processedData.lengthInBytes,
            mimeType: mime,
            name: targetName,
          );
        }
      } catch (_) {}
    }

    try {
      return await compute(_fallbackProcessWorker, (
        path: path,
        data: data,
        quality: quality,
        mimeType: mime,
        targetName: targetName,
        stripExif: stripExif,
      ));
    } catch (_) {
      final size = data?.lengthInBytes ??
          (path.hasContent ? await File(path!).length() : 0);

      return ProcessedImageResult(
        path: path,
        data: data,
        mimeType: mime,
        size: size,
        name: effectiveName,
      );
    }
  }

  /// Pure-Dart fallback isolate worker
  static Future<ProcessedImageResult> _fallbackProcessWorker(
    ({
      String? path,
      Uint8List? data,
      int quality,
      String mimeType,
      String targetName,
      bool stripExif,
    }) args,
  ) async {
    img.Image? image;

    if (args.path.hasContent) {
      image = await img.decodeImageFile(args.path!);
    } else if (args.data != null && args.data!.isNotEmpty) {
      image = img.decodeImage(args.data!);
    }

    if (image == null) throw Exception("Unable to decode image file.");

    if (args.stripExif) {
      image.exif.clear();
    }

    Uint8List? processedData;
    String finalMime = args.mimeType;
    String finalName = args.targetName;

    if (args.mimeType == 'image/jpeg' || args.mimeType == 'image/jpg') {
      processedData = img.encodeJpg(image, quality: args.quality);
    } else {
      processedData = img.encodeNamedImage(args.targetName, image);
    }

    if (processedData == null) {
      processedData = img.encodePng(image);
      finalMime = 'image/png';
      finalName = '${p.basenameWithoutExtension(args.targetName)}.png';
    }

    return ProcessedImageResult(
      data: processedData,
      size: processedData.lengthInBytes,
      mimeType: finalMime,
      name: finalName,
    );
  }
}
