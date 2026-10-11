import 'package:extended_image/extended_image.dart' hide MediaType;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:savedex/core/constants/constants.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailMediaView extends StatelessWidget {
  final SavedItem item;

  const DetailMediaView({super.key, required this.item});

  void _openFullscreen(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) =>
            _FullscreenImageViewer(imageUrl: imageUrl, itemTitle: item.title),
      ),
    );
  }

  void _playVideo(String? videoUrl) {
    if (videoUrl != null) {
      launchUrl(Uri.parse(videoUrl), mode: LaunchMode.externalApplication);
    }
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
            onTap: () {
              if (item.isVideo) {
                _playVideo(item.mediaUrl ?? item.url);
              } else {
                _openFullscreen(
                  context,
                  item.fullImageUrl ?? item.displayImageUrl!,
                );
              }
            },
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
                      printError: false,
                      loadStateChanged: (state) {
                        if (state.extendedImageLoadState == LoadState.failed) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Icon(
                                item.isVideo
                                    ? Icons.videocam_rounded
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
                    if (item.fullImageUrl != null &&
                        item.fullImageUrl != item.displayImageUrl)
                      ExtendedImage.network(
                        item.fullImageUrl!,
                        fit: BoxFit.contain,
                        cache: true,
                        printError: false,
                        loadStateChanged: (state) {
                          if (state.extendedImageLoadState ==
                              LoadState.loading) {
                            return const IgnorePointer(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            );
                          }
                          if (state.extendedImageLoadState ==
                              LoadState.failed) {
                            return const SizedBox.shrink();
                          }
                          return null;
                        },
                      ),
                    if (item.isVideo)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Play Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ] else if (item.isVideo) ...[
          const SizedBox(height: 16),
          Material(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _playVideo(item.mediaUrl ?? item.url),
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
                        Icons.play_circle_fill_rounded,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reddit Video',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to play external video',
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
            !item.url!.contains('reddit.com') &&
            item.mediaType == MediaType.link) ...[
          const SizedBox(height: 14),
          Material(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openExternalLink(context, item.url!),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
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

class _FullscreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? itemTitle;

  const _FullscreenImageViewer({required this.imageUrl, this.itemTitle});

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  bool _isDownloading = false;

  Future<void> _downloadImage() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      Uint8List? bytes;

      // directly from extended_image cache
      try {
        bytes = await getNetworkImageData(widget.imageUrl, useCache: true);
      } catch (_) {
        bytes = null;
      }

      // if not cached or failed, fetch via HTTP
      if (bytes == null || bytes.isEmpty) {
        final response = await http
            .get(Uri.parse(widget.imageUrl))
            .timeout(const Duration(seconds: 25));
        if (response.statusCode == 200) {
          bytes = response.bodyBytes;
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      }

      String baseName = 'savedex_image';
      if (widget.itemTitle != null && widget.itemTitle!.trim().isNotEmpty) {
        final sanitized = widget.itemTitle!
            .trim()
            .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
            .replaceAll(RegExp(r'_+'), '_');
        if (sanitized.isNotEmpty) {
          baseName = sanitized.length > 40
              ? sanitized.substring(0, 40)
              : sanitized;
        }
      }
      final name = '${baseName}_${DateTime.now().millisecondsSinceEpoch}';

      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage access permission denied'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
      }

      await Gal.putImageBytes(bytes, album: 'Savedex', name: name);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image saved to Pictures/Savedex'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image: $e'),
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
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
              tooltip: 'Download image',
              onPressed: _downloadImage,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ExtendedImage.network(
          widget.imageUrl,
          fit: BoxFit.contain,
          mode: ExtendedImageMode.gesture,
          cache: true,
          printError: false,
          initGestureConfigHandler: (state) {
            return GestureConfig(
              minScale: 0.9,
              animationMinScale: 0.7,
              maxScale: 4.0,
              animationMaxScale: 4.5,
              speed: 1.0,
              inertialSpeed: 100.0,
              initialScale: 1.0,
              inPageView: false,
            );
          },
        ),
      ),
    );
  }
}
