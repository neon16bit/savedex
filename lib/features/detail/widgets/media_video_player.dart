import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';

class _VideoQuality {
  final int height;
  final String label;
  final String url;

  const _VideoQuality({
    required this.height,
    required this.label,
    required this.url,
  });
}

class MediaVideoPlayer extends ConsumerStatefulWidget {
  final String videoUrl;
  final String? fallbackUrl;
  final bool isGif;
  final bool autoPlay;

  const MediaVideoPlayer({
    super.key,
    required this.videoUrl,
    this.fallbackUrl,
    this.isGif = false,
    this.autoPlay = true,
  });

  @override
  ConsumerState<MediaVideoPlayer> createState() => _MediaVideoPlayerState();
}

class _MediaVideoPlayerState extends ConsumerState<MediaVideoPlayer> {
  Map<String, String> get _httpHeaders {
    final settings = ref.read(settingsViewModelProvider);
    final effectiveUserAgent = settings.userAgent?.trim() ?? '';
    return {
      if (effectiveUserAgent.isNotEmpty) 'User-Agent': effectiveUserAgent,
      'Accept': '*/*',
    };
  }

  late final Player _player;
  late final VideoController _controller;
  bool _isMuted = false;
  bool _isPlaying = false;
  bool _isBuffering = true;
  bool _showControls = true;

  bool _voGpuAttached = false;
  bool _didReopenAfterVoAttach = false;
  bool _hasAttachedAudioFile = false;
  String? _resolvedVideoUrl;
  File? _tempAudioFile;
  List<_VideoQuality> _qualities = [];
  _VideoQuality? _selectedQuality;
  Timer? _hideControlsTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _logSub;

  @override
  void initState() {
    super.initState();
    final sessionMuted = ref.read(sessionMuteStateProvider);
    final initialMuted =
        sessionMuted ?? ref.read(settingsViewModelProvider).startVideosMuted;
    _isMuted = widget.isGif ? true : initialMuted;

    _player = Player(
      configuration: PlayerConfiguration(
        muted: _isMuted,
        logLevel: kDebugMode ? MPVLogLevel.v : MPVLogLevel.warn,
      ),
    );

    _controller = VideoController(
      _player,
      configuration: Platform.isAndroid
          ? const VideoControllerConfiguration(
              enableHardwareAcceleration: true,
              hwdec: 'no',
            )
          : const VideoControllerConfiguration(),
    );

    _logSub = _player.stream.log.listen((event) {
      if (kDebugMode) {
        debugPrint('MPV [${event.prefix}] ${event.level}:${event.text}');
      }

      if (event.text.contains('Set property: vo="gpu" -> 1')) {
        _voGpuAttached = true;
      }

      if (_voGpuAttached &&
          !_didReopenAfterVoAttach &&
          event.text.contains('video=eof (paused)') &&
          _position.inMilliseconds < 500) {
        _reopenOnAttachedSurface();
      }
    });

    _errorSub = _player.stream.error.listen((error) {
      debugPrint('MPV ERROR (${widget.videoUrl}):$error');
    });

    _posSub = _player.stream.position.listen((pos) {
      if (!mounted) return;
      if (pos.inMilliseconds > 200 &&
          (_duration.inMilliseconds == 0 ||
              pos.inMilliseconds < _duration.inMilliseconds - 500)) {
        _didReopenAfterVoAttach = true;
        if (_isBuffering) {
          setState(() => _isBuffering = false);
        }
      }
      setState(() => _position = pos);
    });

    _durSub = _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _playingSub = _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() => _isPlaying = playing);
        if (playing) _startHideControlsTimer();
      }
    });

    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (mounted && _didReopenAfterVoAttach) {
        setState(() => _isBuffering = buffering);
      }
    });

    _initPlayback();
  }

  Future<({String videoUrl, File? audioFile, List<_VideoQuality> qualities})>
  _resolveRedGifsStream(String url) async {
    try {
      final redGifsService = ref.read(redgifsApiServiceProvider);
      final userAgent = ref.read(settingsViewModelProvider).userAgent?.trim();
      final info = await redGifsService.fetchVideoInfo(
        url,
        userAgent: userAgent,
      );

      if (info != null && (info.hdUrl != null || info.sdUrl != null)) {
        final qualities = <_VideoQuality>[
          if (info.hdUrl != null && info.hdUrl!.isNotEmpty)
            _VideoQuality(height: 1080, label: 'HD', url: info.hdUrl!),
          if (info.sdUrl != null && info.sdUrl!.isNotEmpty)
            _VideoQuality(height: 540, label: 'SD', url: info.sdUrl!),
        ];

        return (videoUrl: info.bestUrl!, audioFile: null, qualities: qualities);
      }
    } catch (e) {
      debugPrint('RedGifs resolve fallback: $e');
    }

    final fallback = widget.fallbackUrl;
    if (fallback != null && fallback.isNotEmpty && fallback != url) {
      return _resolveStream(fallback);
    }

    return (videoUrl: url, audioFile: null, qualities: const <_VideoQuality>[]);
  }

  Future<({String videoUrl, File? audioFile, List<_VideoQuality> qualities})>
  _resolveStream(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return (
        videoUrl: url,
        audioFile: null,
        qualities: const <_VideoQuality>[],
      );
    }

    if (uri.host.contains('redgifs.com')) {
      return _resolveRedGifsStream(url);
    }

    if (!uri.host.contains('redd.it') || !uri.path.endsWith('.m3u8')) {
      return (
        videoUrl: url,
        audioFile: null,
        qualities: const <_VideoQuality>[],
      );
    }

    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      _httpHeaders.forEach(req.headers.set);
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        return (
          videoUrl: url,
          audioFile: null,
          qualities: const <_VideoQuality>[],
        );
      }

      final playlist = await res.transform(utf8.decoder).join();

      // match CMAF_<num>.m3u8 and HLS_<num>.m3u8
      final videoMatches = RegExp(
        r'\b(CMAF|HLS)_(\d+)\.m3u8\b',
        caseSensitive: false,
      ).allMatches(playlist).toList();

      if (videoMatches.isEmpty) {
        return (
          videoUrl: url,
          audioFile: null,
          qualities: const <_VideoQuality>[],
        );
      }

      final qualityMap = <int, _VideoQuality>{};
      for (final match in videoMatches) {
        final rawFile = match.group(0)!;
        final prefix = match.group(1)!.toUpperCase();
        final height = int.tryParse(match.group(2) ?? '0') ?? 0;

        if (height > 0 && !qualityMap.containsKey(height)) {
          final ext = prefix == 'CMAF' ? '.mp4' : '.ts';
          final directFileName = rawFile.replaceAll(
            RegExp(r'\.m3u8$', caseSensitive: false),
            ext,
          );
          final resolvedUrl = uri.resolve(directFileName).toString();
          qualityMap[height] = _VideoQuality(
            height: height,
            label: '${height}p',
            url: resolvedUrl,
          );
        }
      }

      // sort highest resolution first
      final qualities = qualityMap.values.toList()
        ..sort((a, b) => b.height.compareTo(a.height));

      if (qualities.isEmpty) {
        return (
          videoUrl: url,
          audioFile: null,
          qualities: const <_VideoQuality>[],
        );
      }

      final highestQuality = qualities.first;

      // match CMAF_AUDIO_<bit>.m3u8 (.mp4) and HLS_AUDIO_<bit>_K.m3u8 (.aac)
      File? localAudioFile;
      if (!widget.isGif) {
        final audioMatches = RegExp(
          r'\b(CMAF|HLS)_AUDIO_(\d+)(?:_K)?\.m3u8\b',
          caseSensitive: false,
        ).allMatches(playlist).toList();

        if (audioMatches.isNotEmpty) {
          audioMatches.sort((a, b) {
            final bitA = int.tryParse(a.group(2) ?? '0') ?? 0;
            final bitB = int.tryParse(b.group(2) ?? '0') ?? 0;
            return bitB.compareTo(bitA);
          });

          final bestAudioMatch = audioMatches.first;
          final rawAudioM3u8 = bestAudioMatch.group(0)!;
          final audioPrefix = bestAudioMatch.group(1)!.toUpperCase();
          final audioExt = audioPrefix == 'CMAF' ? '.mp4' : '.aac';

          final audioFileName = rawAudioM3u8.replaceAll(
            RegExp(r'\.m3u8$', caseSensitive: false),
            audioExt,
          );
          final directAudioUri = uri.resolve(audioFileName);

          final audioReq = await client.getUrl(directAudioUri);
          _httpHeaders.forEach(audioReq.headers.set);
          final audioRes = await audioReq.close().timeout(
            const Duration(seconds: 5),
          );
          final mimeType = audioRes.headers.contentType?.mimeType ?? '';
          if (audioRes.statusCode == 200 && !mimeType.contains('html')) {
            final tempFile = File(
              '${Directory.systemTemp.path}/savedex_audio_${DateTime.now().microsecondsSinceEpoch}$audioExt',
            );
            final bytes = await consolidateHttpClientResponseBytes(audioRes);
            await tempFile.writeAsBytes(bytes, flush: true);
            localAudioFile = tempFile;
          }
        }
      }

      return (
        videoUrl: highestQuality.url,
        audioFile: localAudioFile,
        qualities: qualities,
      );
    } catch (e) {
      debugPrint('Reddit HLS resolve fallback: $e');
      return (
        videoUrl: url,
        audioFile: null,
        qualities: const <_VideoQuality>[],
      );
    } finally {
      client.close();
    }
  }

  Future<void> _reopenOnAttachedSurface() async {
    if (_didReopenAfterVoAttach || !mounted || _resolvedVideoUrl == null) {
      return;
    }
    _didReopenAfterVoAttach = true;
    debugPrint('MPV: Re-opening stream with vo="gpu" already attached...');

    await _player.open(
      Media(_resolvedVideoUrl!, httpHeaders: _httpHeaders),
      play: widget.autoPlay,
    );
  }

  Future<void> _configureNativeMpvProperties() async {
    if (_player.platform is NativePlayer) {
      final native = _player.platform as NativePlayer;
      await native.setProperty('cache', 'yes');
      await native.setProperty('demuxer-seekable-cache', 'yes');

      if (widget.isGif) {
        await native.setProperty('demuxer-max-back-bytes', '33554432');
        await native.setProperty('loop-file', 'inf');
      } else {
        await native.setProperty('demuxer-max-back-bytes', '0');
        await native.setProperty('loop-file', 'no');
      }
      await native.setProperty('demuxer-lavf-probesize', '32768');
      await native.setProperty('demuxer-lavf-analyzeduration', '0.5');

      if (_tempAudioFile != null) {
        await native.setProperty('audio-files', _tempAudioFile!.path);
        _hasAttachedAudioFile = true;
      } else if (_hasAttachedAudioFile) {
        await native.setProperty('audio-files', '');
        _hasAttachedAudioFile = false;
      }
    }
  }

  Future<void> _initPlayback() async {
    _voGpuAttached = false;
    _didReopenAfterVoAttach = false;

    await _controller.platform.future;
    if (!mounted) return;

    final resolved = await _resolveStream(widget.videoUrl);
    if (!mounted) {
      resolved.audioFile?.delete().ignore();
      return;
    }

    _tempAudioFile?.delete().ignore();
    _tempAudioFile = resolved.audioFile;
    _resolvedVideoUrl = resolved.videoUrl;
    setState(() {
      _qualities = resolved.qualities;
      _selectedQuality = resolved.qualities.isNotEmpty
          ? resolved.qualities.first
          : null;
    });

    await _configureNativeMpvProperties();

    _controller.waitUntilFirstFrameRendered.then((_) {
      if (mounted) {
        setState(() => _isBuffering = false);
      }
    });

    await _player.setVolume(_isMuted ? 0.0 : 100.0);

    if (widget.isGif) {
      await _player.setPlaylistMode(PlaylistMode.single);
    } else {
      await _player.setPlaylistMode(PlaylistMode.none);
    }

    debugPrint(
      'Opening video URL: $_resolvedVideoUrl (audio:${_tempAudioFile?.path})',
    );
    await _player.open(
      Media(_resolvedVideoUrl!, httpHeaders: _httpHeaders),
      play: widget.autoPlay,
    );
  }

  Future<void> _changeQuality(_VideoQuality quality) async {
    if (_selectedQuality?.url == quality.url) return;

    final savedPosition = _position;
    final wasPlaying = _isPlaying;

    setState(() {
      _selectedQuality = quality;
      _resolvedVideoUrl = quality.url;
      _isBuffering = true;
    });

    await _configureNativeMpvProperties();

    await _player.open(
      Media(
        quality.url,
        httpHeaders: _httpHeaders,
        start: savedPosition > Duration.zero ? savedPosition : null,
      ),
      play: wasPlaying,
    );

    _startHideControlsTimer();
  }

  void _showQualitySelector() {
    if (_qualities.isEmpty) return;
    _hideControlsTimer?.cancel();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Video Quality',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ..._qualities.map((q) {
                final isSelected = q.url == _selectedQuality?.url;
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_rounded : null,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    q.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _changeQuality(q);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) _startHideControlsTimer();
    });
  }

  @override
  void didUpdateWidget(covariant MediaVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      setState(() {
        _isBuffering = true;
        _position = Duration.zero;
        _duration = Duration.zero;
        _qualities = [];
        _selectedQuality = null;
      });
      _initPlayback();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  Future<void> _togglePlayPause() async {
    if (!_isPlaying &&
        _duration.inMilliseconds > 0 &&
        _position.inMilliseconds >= _duration.inMilliseconds - 600) {
      await _player.seek(Duration.zero);
      await _player.play();
    } else {
      await _player.playOrPause();
    }
    _startHideControlsTimer();
  }

  void _toggleMute() {
    final newMute = !_isMuted;
    setState(() => _isMuted = newMute);
    _player.setVolume(newMute ? 0.0 : 100.0);
    ref.read(sessionMuteStateProvider.notifier).setMuted(newMute);
    _startHideControlsTimer();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _logSub?.cancel();
    _player.dispose();
    _tempAudioFile?.delete().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Video(
            controller: _controller,
            controls: NoVideoControls,
            fit: BoxFit.contain,
          ),

          if (_isBuffering)
            const Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            ),

          // controls overlay
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Stack(
                children: [
                  // center play/pause button
                  Center(
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        iconSize: 48,
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                    ),
                  ),

                  // bottom bar
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_duration.inMilliseconds > 0) ...[
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                                trackHeight: 3,
                                activeTrackColor: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                min: 0.0,
                                max: _duration.inMilliseconds.toDouble(),
                                value: _position.inMilliseconds
                                    .clamp(0, _duration.inMilliseconds)
                                    .toDouble(),
                                onChangeStart: (_) {
                                  _hideControlsTimer?.cancel();
                                },
                                onChangeEnd: (val) {
                                  _player.seek(
                                    Duration(milliseconds: val.round()),
                                  );
                                  _startHideControlsTimer();
                                },
                                onChanged: (val) {
                                  setState(() {
                                    _position = Duration(
                                      milliseconds: val.round(),
                                    );
                                  });
                                },
                              ),
                            ),
                          ],
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                              if (_duration.inMilliseconds > 0)
                                Text(
                                  '${_formatDuration(_position)} /${_formatDuration(_duration)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const Spacer(),
                              // quality selector
                              if (_qualities.isNotEmpty)
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: _showQualitySelector,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_selectedQuality != null) ...[
                                          Text(
                                            _selectedQuality!.label,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        const Icon(
                                          Icons.settings_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // mute/unmute
                              if (!widget.isGif)
                                IconButton(
                                  icon: Icon(
                                    _isMuted
                                        ? Icons.volume_off_rounded
                                        : Icons.volume_up_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  tooltip: _isMuted ? 'Unmute' : 'Mute',
                                  onPressed: _toggleMute,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
