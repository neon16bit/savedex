import 'dart:io';

import 'package:extended_image/extended_image.dart' hide MediaType;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/detail/widgets/media_video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailMediaView extends StatelessWidget {
  final SavedItem item;

  const DetailMediaView({super.key, required this.item});

  void _openMediaViewer(BuildContext context, {int initialIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) =>
            FullscreenMediaViewer(item: item, initialIndex: initialIndex),
      ),
    );
  }

  Future<void> _openExternalLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This link is not a valid web URL')),
      );
      return;
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open this link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.hasDisplayImage) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _openMediaViewer(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 400),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ExtendedImage.network(
                      item.displayImageUrl!,
                      fit: BoxFit.contain,
                      cache: true,
                      cacheWidth: 800,
                      retries: 1,
                      printError: false,
                      loadStateChanged: (state) {
                        if (state.extendedImageLoadState == LoadState.failed) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Icon(
                                item.isPlayableMedia
                                    ? (item.isGif
                                          ? Icons.gif_box_rounded
                                          : Icons.videocam_rounded)
                                    : Icons.broken_image_rounded,
                                size: 44,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                    if (item.isPlayableMedia)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isGif
                                  ? Icons.gif_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item.isGif ? 'Play GIF' : 'Play Video',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (item.galleryImages.length > 1)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '${item.galleryImages.length} items',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ] else if (item.isPlayableMedia) ...[
          const SizedBox(height: 16),
          Material(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openMediaViewer(context),
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isGif
                            ? Icons.gif_box_rounded
                            : Icons.play_circle_fill_rounded,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.isGif ? 'GIF' : 'Video',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to play media',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        if (item.url != null &&
            item.url!.trim().isNotEmpty &&
            !item.url!.contains('v.redd.it') &&
            !item.url!.contains('i.redd.it') &&
            !item.url!.contains('reddit.com/gallery') &&
            (item.mediaType == MediaType.link ||
                !item.hasDisplayImage && !item.isPlayableMedia)) ...[
          const SizedBox(height: 16),
          Material(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openExternalLink(context, item.url!),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.link_rounded,
                        size: 18,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.url!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to open external link',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class FullscreenMediaViewer extends StatefulWidget {
  final SavedItem item;
  final int initialIndex;

  const FullscreenMediaViewer({
    super.key,
    required this.item,
    this.initialIndex = 0,
  });

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer> {
  bool _isDownloading = false;
  late final ExtendedPageController _pageController;
  late int _currentIndex;
  late final List<String> _mediaUrls;

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  void initState() {
    super.initState();
    if (widget.item.galleryImages.isNotEmpty) {
      _mediaUrls = widget.item.galleryImages;
    } else {
      final single =
          widget.item.playMediaUrl ??
          widget.item.fullImageUrl ??
          widget.item.displayImageUrl;
      _mediaUrls = single != null ? [single] : [];
    }

    _currentIndex = widget.initialIndex.clamp(
      0,
      _mediaUrls.isNotEmpty ? _mediaUrls.length - 1 : 0,
    );
    _pageController = ExtendedPageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _currentUrl =>
      _mediaUrls.isNotEmpty ? _mediaUrls[_currentIndex] : '';

  bool _isCurrentVideo(String url) {
    if (widget.item.galleryImages.isEmpty) {
      return widget.item.isVideo;
    }
    return SavedItem.isVideoUrl(url);
  }

  bool _isCurrentGif(String url) {
    if (widget.item.galleryImages.isEmpty) {
      return widget.item.isGif;
    }
    return SavedItem.isGifUrl(url);
  }

  Future<void> _handleDownloadTap() async {
    final current = _currentUrl;
    if (current.isEmpty) return;

    if (_isCurrentGif(current)) {
      _showGifDownloadDialog();
    } else if (_isCurrentVideo(current)) {
      _downloadMedia(current, extension: 'mp4');
    } else {
      _downloadMedia(current, extension: 'jpg');
    }
  }

  void _showGifDownloadDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Download GIF',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_rounded),
                  title: const Text('Save as MP4 Video'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _downloadMedia(_currentUrl, extension: 'mp4');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.gif_box_rounded),
                  title: const Text('Save as GIF Image'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _downloadMedia(_currentUrl, extension: 'gif');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadMedia(String url, {required String extension}) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      Uint8List? bytes;

      try {
        bytes = await getNetworkImageData(url, useCache: true);
      } catch (_) {
        bytes = null;
      }

      if (bytes == null || bytes.isEmpty) {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 40));
        if (response.statusCode == 200) {
          bytes = response.bodyBytes;
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      }

      String baseName = 'savedex_media';
      if (widget.item.title.trim().isNotEmpty) {
        final sanitized = widget.item.title
            .trim()
            .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
            .replaceAll(RegExp(r'_+'), '_');
        if (sanitized.isNotEmpty) {
          baseName = sanitized.length > 40
              ? sanitized.substring(0, 40)
              : sanitized;
        }
      }
      final filename =
          '${baseName}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final mimeType = switch (extension.toLowerCase()) {
        'mp4' => 'video/mp4',
        'gif' => 'image/gif',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      if (_isDesktop) {
        final saveUri = await FilePickerPlatform.instance.saveFile(
          dialogTitle: 'Save File',
          fileName: filename,
          mimeType: mimeType,
          bytes: bytes,
        );
        if (saveUri != null) {
          final filePath = saveUri.toFilePath();
          final file = File(filePath);
          if (!await file.exists() || await file.length() == 0) {
            await file.writeAsBytes(bytes);
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to $filePath'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (extension == 'mp4') {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(p.join(tempDir.path, filename));
          await tempFile.writeAsBytes(bytes);
          await Gal.putVideo(tempFile.path, album: 'Savedex');
        } else {
          await Gal.putImageBytes(
            bytes,
            album: 'Savedex',
            name: filename.replaceAll('.$extension', ''),
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to gallery'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mediaUrls.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'No media available',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: _mediaUrls.length > 1
            ? Text(
                '${_currentIndex + 1} / ${_mediaUrls.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
        actions: [
          if (_isDownloading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Download media',
              onPressed: _handleDownloadTap,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          ExtendedImageGesturePageView.builder(
            controller: _pageController,
            itemCount: _mediaUrls.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final url = _mediaUrls[index];
              final isVid = _isCurrentVideo(url);
              final isG = _isCurrentGif(url);

              if (isVid || isG) {
                return Center(
                  child: MediaVideoPlayer(
                    videoUrl: url,
                    fallbackUrl: widget.item.fallbackPlayMediaUrl,
                    isGif: isG,
                    autoPlay: true,
                  ),
                );
              }

              return ExtendedImage.network(
                url,
                fit: BoxFit.contain,
                mode: ExtendedImageMode.gesture,
                cache: true,
                printError: false,
                loadStateChanged: (state) {
                  if (state.extendedImageLoadState == LoadState.loading) {
                    return const Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }
                  if (state.extendedImageLoadState == LoadState.failed) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 64,
                        color: Colors.white70,
                      ),
                    );
                  }
                  return null;
                },
                initGestureConfigHandler: (state) {
                  return GestureConfig(
                    minScale: 0.9,
                    animationMinScale: 0.7,
                    maxScale: 4.0,
                    animationMaxScale: 4.5,
                    speed: 1.0,
                    inertialSpeed: 100.0,
                    initialScale: 1.0,
                    inPageView: true,
                  );
                },
              );
            },
          ),

          if (_isDesktop && _mediaUrls.length > 1) ...[
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _GalleryNavigationButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Previous media',
                  onPressed: _currentIndex == 0
                      ? null
                      : () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _GalleryNavigationButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Next media',
                  onPressed: _currentIndex == _mediaUrls.length - 1
                      ? null
                      : () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GalleryNavigationButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _GalleryNavigationButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 34),
      color: Colors.white,
      disabledColor: Colors.white30,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.55),
        disabledBackgroundColor: Colors.black.withValues(alpha: 0.25),
        padding: const EdgeInsets.all(10),
      ),
    );
  }
}
