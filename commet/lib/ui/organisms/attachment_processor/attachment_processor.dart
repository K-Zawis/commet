import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:exif/exif.dart';
import 'package:intl/intl.dart';
import 'package:tiamat/tiamat.dart' as tiamat;

import 'package:commet/client/attachment.dart';
import 'package:commet/ui/atoms/scaled_safe_area.dart';
import 'package:commet/ui/molecules/file_preview.dart';
import 'package:commet/ui/molecules/video_player/video_player_controller.dart';
import 'package:commet/utils/image_utils.dart';
import 'package:commet/utils/mime.dart';

class AttachmentProcessor extends StatefulWidget {
  const AttachmentProcessor({required this.attachment, super.key});
  final PendingFileAttachment attachment;

  @override
  State<AttachmentProcessor> createState() => _AttachmentProcessorState();
}

class _AttachmentProcessorState extends State<AttachmentProcessor> {
  String get promptAttachmentProcessingSendOriginal => Intl.message(
      "Send Original",
      name: "promptAttachmentProcessingSendOriginal",
      desc:
          "Prompt text for the option to send a file in its original state, without any further processing such as removing metadata");

  String get labelImageContainsLocationInfo => Intl.message(
      "Warning: This image contains location metadata",
      name: "labelImageContainsLocationInfo",
      desc:
          "Prompt text for the option to send a file in its original state, without any further processing such as removing metadata");

  Map<String, IfdTag>? exifData;
  late IconData icon;
  VideoPlayerController? videoController;

  bool canProcessData = false;
  bool containsGpsData = false;
  bool sendOriginalFile = false;

  bool processing = false;

  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    icon = Mime.toIcon(widget.attachment.mimeType);

    if (Mime.imageTypes.contains(widget.attachment.mimeType)) {
      loadExif();
      canProcessData = widget.attachment.mimeType != "image/gif";
    } else if (Mime.videoTypes.contains(widget.attachment.mimeType)) {
      videoController = VideoPlayerController();
      canProcessData = true;
    }

    super.initState();
  }

  @override
  void dispose() {
    videoController?.pause();
    videoController?.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void loadExif() async {
    final hasGps = await widget.attachment.hasGpsData();
    if (!mounted) return;

    setState(() {
      containsGpsData = hasGps;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaledSafeArea(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: processing ? 0.5 : 1,
            child: IgnorePointer(
              ignoring: processing,
              child: KeyboardListener(
                focusNode: focusNode,
                autofocus: true,
                onKeyEvent: (value) {
                  if (processing) return;

                  if (value.logicalKey == LogicalKeyboardKey.enter) {
                    submit();
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.attachment.name != null)
                      Row(
                        children: [
                          Icon(icon),
                          Flexible(
                            child: tiamat.Text.labelLow(
                              widget.attachment.name!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints.loose(const Size(500, 500)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FilePreview(
                              mimeType: widget.attachment.mimeType,
                              path: widget.attachment.path,
                              data: widget.attachment.data,
                              videoController: videoController,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (canProcessData)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: buildFileProcessingSwitch(),
                      ),
                    if (sendOriginalFile || !canProcessData)
                      buildMetadataDisplay(),
                    buildConfirmButton(),
                  ],
                ),
              ),
            ),
          ),
          if (processing) const CircularProgressIndicator()
        ],
      ),
    );
  }

  Widget buildFileProcessingSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        tiamat.Text.label(promptAttachmentProcessingSendOriginal),
        tiamat.Switch(
          state: sendOriginalFile,
          onChanged: (value) => setState(() {
            sendOriginalFile = value;
          }),
        ),
      ],
    );
  }

  Widget buildMetadataDisplay() {
    return Column(
      children: [
        if (containsGpsData) tiamat.Text.error(labelImageContainsLocationInfo)
      ],
    );
  }

  Widget buildConfirmButton() {
    return tiamat.Button(
      text: "Add File",
      onTap: submit,
    );
  }

  void submit() async {
    if (!canProcessData || sendOriginalFile) {
      Navigator.of(context).pop(widget.attachment);
      return;
    }

    setState(() => processing = true);

    var file = await processFile();

    if (mounted) Navigator.of(context).pop(file);
  }

  Future<PendingFileAttachment> processFile() async {
    final mimeType = widget.attachment.mimeType?.toLowerCase() ??
        await Mime.resolveType(
          widget.attachment.path,
          data: widget.attachment.data,
        );

    if (Mime.imageTypes.contains(mimeType)) return await processImage(mimeType);
    if (Mime.videoTypes.contains(mimeType)) return await processVideo();

    return widget.attachment;
  }

  Future<PendingFileAttachment> processImage(String mimeType) async {
    final result = await ImageUtils.processImage(
      path: widget.attachment.path,
      data: widget.attachment.data,
      name: widget.attachment.name,
      sourceMimeType: mimeType,
      quality: 100,
      stripExif: true,
    );

    return await PendingFileAttachment.fromProcessedImage(result);
  }

  Future<PendingFileAttachment> processVideo() async {
    final file = widget.attachment;

    if (videoController == null) return file;

    try {
      file.thumbnailFile = await videoController!.screenshot();
      if (file.thumbnailFile != null) {
        file.thumbnailMime =
            Mime.lookupType("", data: file.thumbnailFile) ?? "image/png";
      }

      file.length = await videoController!.getLength();
      file.dimensions = await videoController!.getSize();
    } catch (_) {
      // Safe fallback: continue sending video even if thumbnail/metadata extraction fails
    }

    return file;
  }
}
