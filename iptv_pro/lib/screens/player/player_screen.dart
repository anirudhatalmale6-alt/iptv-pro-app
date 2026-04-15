import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../config/theme.dart';
import '../../models/xtream_data.dart';
import '../../providers/app_provider.dart';
import '../../providers/mini_player_provider.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final bool isLive;
  final String? channelIcon;
  final int? streamId;
  final String? plot;
  final String? year;
  final String? duration;
  final String? rating;
  final List<LiveStream>? channelList;
  final int? currentChannelIndex;
  // For resuming from mini player
  final Player? existingPlayer;
  final VideoController? existingVideoController;

  const PlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.isLive = false,
    this.channelIcon,
    this.streamId,
    this.plot,
    this.year,
    this.duration,
    this.rating,
    this.channelList,
    this.currentChannelIndex,
    this.existingPlayer,
    this.existingVideoController,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Player? _player;
  VideoController? _videoController;
  bool _isError = false;
  String _errorMessage = '';
  bool _isInitializing = true;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _showInfo = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  List<EpgEntry> _epgEntries = [];
  int _currentChannelIdx = 0;
  String _currentUrl = '';
  String _currentTitle = '';
  bool _transferToMiniOnPop = true;

  // Subtitle state
  List<SubtitleTrack> _subtitleTracks = [];
  SubtitleTrack? _activeSubtitleTrack;
  String _subtitleText = '';

  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _currentUrl = widget.url;
    _currentTitle = widget.title;
    _currentChannelIdx = widget.currentChannelIndex ?? 0;
    context.read<MiniPlayerProvider>().dismiss();

    if (widget.existingPlayer != null && widget.existingVideoController != null) {
      _player = widget.existingPlayer;
      _videoController = widget.existingVideoController;
      _setupListeners();
      setState(() {
        _isInitializing = false;
        _isPlaying = _player!.state.playing;
        _position = _player!.state.position;
        _totalDuration = _player!.state.duration;
        _subtitleTracks = _player!.state.tracks.subtitle;
        _subtitleText = _player!.state.subtitle.first;
      });
      _autoHideControls();
    } else {
      _initPlayer();
    }
    if (widget.isLive && widget.streamId != null) {
      _loadEpg(widget.streamId!);
    }
  }

  Future<void> _loadEpg(int streamId) async {
    try {
      final provider = context.read<AppProvider>();
      final epg = await provider.getShortEpg(streamId);
      if (mounted) setState(() => _epgEntries = epg);
    } catch (_) {}
  }

  Future<void> _initPlayer() async {
    try {
      _player = Player();
      _videoController = VideoController(_player!);
      _setupListeners();
      await _player!.open(Media(_currentUrl));
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isPlaying = true;
        });
        _autoHideControls();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = e.toString();
          _isInitializing = false;
        });
      }
    }
  }

  void _setupListeners() {
    if (_player == null) return;
    _subscriptions.add(_player!.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    }));
    _subscriptions.add(_player!.stream.position.listen((position) {
      if (mounted) setState(() => _position = position);
    }));
    _subscriptions.add(_player!.stream.duration.listen((duration) {
      if (mounted) setState(() => _totalDuration = duration);
    }));
    _subscriptions.add(_player!.stream.error.listen((error) {
      if (mounted && error.isNotEmpty) {
        setState(() {
          _isError = true;
          _errorMessage = error;
        });
      }
    }));
    _subscriptions.add(_player!.stream.tracks.listen((tracks) {
      if (mounted) {
        setState(() => _subtitleTracks = tracks.subtitle);
        // Auto-enable first subtitle track if available and none selected
        if (_activeSubtitleTrack == null && tracks.subtitle.length > 1) {
          // First track is usually "no" (disabled), pick the second one
          final firstReal = tracks.subtitle.where((t) => t.id != 'no' && t.id != 'auto').toList();
          if (firstReal.isNotEmpty) {
            _player!.setSubtitleTrack(firstReal.first);
            setState(() => _activeSubtitleTrack = firstReal.first);
          }
        }
      }
    }));
    _subscriptions.add(_player!.stream.subtitle.listen((subtitle) {
      if (mounted) {
        setState(() => _subtitleText = subtitle.first);
      }
    }));
  }

  void _autoHideControls() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isPlaying && _showControls && !_showInfo) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (!_showControls) _showInfo = false;
    });
    if (_showControls) _autoHideControls();
  }

  void _toggleInfo() {
    setState(() {
      _showInfo = !_showInfo;
      if (_showInfo) _showControls = true;
    });
  }

  void _togglePlayPause() {
    if (_player == null) return;
    _player!.playOrPause();
  }

  void _seekRelative(int seconds) {
    if (_player == null) return;
    final newPos = _position + Duration(seconds: seconds);
    _player!.seek(newPos);
  }

  void _switchChannel(int delta) {
    if (widget.channelList == null || widget.channelList!.isEmpty) return;
    final newIdx = (_currentChannelIdx + delta).clamp(0, widget.channelList!.length - 1);
    if (newIdx == _currentChannelIdx) return;
    _currentChannelIdx = newIdx;
    final ch = widget.channelList![newIdx];
    final provider = context.read<AppProvider>();
    final url = provider.buildLiveUrl(ch.streamId);
    setState(() {
      _currentUrl = url;
      _currentTitle = ch.name;
      _isError = false;
      _epgEntries = [];
      _subtitleTracks = [];
      _activeSubtitleTrack = null;
      _subtitleText = '';
    });
    _player?.open(Media(url));
    _loadEpg(ch.streamId);
  }

  void _showSubtitlePicker() {
    final tracks = _subtitleTracks.where((t) => t.id != 'auto').toList();
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subtitle tracks found in this stream', style: TextStyle(fontSize: 13)),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.bgCard,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDeep,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Subtitle Tracks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            // "Off" option
            ListTile(
              leading: Icon(Icons.closed_caption_off, color: _activeSubtitleTrack == null ? AppColors.red : AppColors.whiteMuted),
              title: Text('Off', style: TextStyle(color: _activeSubtitleTrack == null ? AppColors.red : Colors.white)),
              trailing: _activeSubtitleTrack == null ? const Icon(Icons.check, color: AppColors.red) : null,
              onTap: () {
                _player?.setSubtitleTrack(SubtitleTrack.no());
                setState(() {
                  _activeSubtitleTrack = null;
                  _subtitleText = '';
                });
                Navigator.pop(ctx);
              },
            ),
            ...tracks.where((t) => t.id != 'no').map((track) {
              final isActive = _activeSubtitleTrack?.id == track.id;
              final label = track.title ?? track.language ?? 'Track ${track.id}';
              return ListTile(
                leading: Icon(Icons.closed_caption, color: isActive ? AppColors.red : AppColors.whiteMuted),
                title: Text(label, style: TextStyle(color: isActive ? AppColors.red : Colors.white)),
                subtitle: track.language != null && track.title != null
                    ? Text(track.language!, style: const TextStyle(color: AppColors.whiteMuted, fontSize: 11))
                    : null,
                trailing: isActive ? const Icon(Icons.check, color: AppColors.red) : null,
                onTap: () {
                  _player?.setSubtitleTrack(track);
                  setState(() => _activeSubtitleTrack = track);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _retryPlay() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _player?.dispose();
    _player = null;
    _videoController = null;
    setState(() {
      _isInitializing = true;
      _isError = false;
      _subtitleTracks = [];
      _activeSubtitleTrack = null;
      _subtitleText = '';
    });
    _initPlayer();
  }

  void _goBackWithMiniPlayer() {
    if (_transferToMiniOnPop && _player != null && widget.isLive) {
      // Cancel listeners but don't dispose - mini player takes ownership
      for (final sub in _subscriptions) {
        sub.cancel();
      }
      _subscriptions.clear();
      context.read<MiniPlayerProvider>().startMiniPlayer(
        player: _player!,
        videoController: _videoController!,
        title: _currentTitle,
        url: _currentUrl,
        channelIcon: widget.channelIcon,
        streamId: widget.streamId,
        isLive: widget.isLive,
        channelList: widget.channelList,
        channelIndex: _currentChannelIdx,
      );
      _player = null;
      _videoController = null;
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _player?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: _toggleControls,
          onDoubleTapDown: (details) {
            final w = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < w / 3) {
              _seekRelative(-10);
            } else if (details.globalPosition.dx > w * 2 / 3) {
              _seekRelative(10);
            } else {
              _togglePlayPause();
            }
          },
          onVerticalDragEnd: (details) {
            if (widget.isLive && details.primaryVelocity != null) {
              if (details.primaryVelocity! < -100) _switchChannel(-1);
              if (details.primaryVelocity! > 100) _switchChannel(1);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildVideoLayer(),
              if (_showControls && !_isInitializing && !_isError) _buildControlsOverlay(),
              if (_showInfo) _buildInfoPanel(),
            ],
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter) {
      _togglePlayPause();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _seekRelative(-10);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _seekRelative(10);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (widget.isLive) _switchChannel(-1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (widget.isLive) _switchChannel(1);
    } else if (key == LogicalKeyboardKey.info || key == LogicalKeyboardKey.contextMenu) {
      _toggleInfo();
    } else if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
      _goBackWithMiniPlayer();
    }
  }

  Widget _buildVideoLayer() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.red),
            SizedBox(height: 16),
            Text('Loading stream...', style: TextStyle(color: AppColors.whiteDim, fontSize: 14)),
          ],
        ),
      );
    }
    if (_isError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.red, size: 48),
            const SizedBox(height: 12),
            const Text('Stream Unavailable', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(_errorMessage, style: const TextStyle(color: AppColors.whiteMuted, fontSize: 12), textAlign: TextAlign.center, maxLines: 3),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(onPressed: _retryPlay, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.whiteMuted)),
                  child: const Text('Back', style: TextStyle(color: AppColors.whiteDim)),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (_videoController != null) {
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Video(
            controller: _videoController!,
            controls: NoVideoControls,
          ),
          // Subtitle overlay
          if (_subtitleText.isNotEmpty && _activeSubtitleTrack != null)
            Positioned(
              bottom: 60,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _subtitleText,
                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _buildControlsOverlay() {
    return Stack(
      children: [
        // Top bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 8, right: 16, bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.85), Colors.transparent]),
            ),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _goBackWithMiniPlayer),
                if (widget.channelIcon != null && widget.channelIcon!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(widget.channelIcon!, width: 28, height: 28, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox()),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_currentTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (_epgEntries.isNotEmpty)
                        Text(
                          _epgEntries.where((e) => e.isCurrentlyAiring).map((e) => e.title ?? '').join(''),
                          style: const TextStyle(color: AppColors.whiteDim, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Subtitle track count badge
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        _activeSubtitleTrack != null ? Icons.closed_caption : Icons.closed_caption_off,
                        color: _activeSubtitleTrack != null ? AppColors.red : Colors.white,
                      ),
                      onPressed: _showSubtitlePicker,
                    ),
                    if (_subtitleTracks.where((t) => t.id != 'no' && t.id != 'auto').isNotEmpty)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                          child: Text(
                            '${_subtitleTracks.where((t) => t.id != 'no' && t.id != 'auto').length}',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: _toggleInfo,
                ),
                if (widget.isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: AppColors.redGlow, blurRadius: 8)]),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Center controls
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.isLive)
                _ControlButton(icon: Icons.replay_10, onTap: () => _seekRelative(-10)),
              const SizedBox(width: 20),
              if (widget.isLive && widget.channelList != null)
                _ControlButton(icon: Icons.keyboard_arrow_up, onTap: () => _switchChannel(-1), size: 40),
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(color: AppColors.red.withOpacity(0.85), shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.redGlow, blurRadius: 20)]),
                  child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36),
                ),
              ),
              if (widget.isLive && widget.channelList != null)
                _ControlButton(icon: Icons.keyboard_arrow_down, onTap: () => _switchChannel(1), size: 40),
              const SizedBox(width: 20),
              if (!widget.isLive)
                _ControlButton(icon: Icons.forward_10, onTap: () => _seekRelative(10)),
            ],
          ),
        ),

        // Bottom bar
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.85), Colors.transparent]),
            ),
            child: widget.isLive ? _buildLiveBottomBar() : _buildVodBottomBar(),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveBottomBar() {
    final currentEpg = _epgEntries.where((e) => e.isCurrentlyAiring).toList();
    final nextEpg = _epgEntries.where((e) => !e.isCurrentlyAiring).toList();

    return Row(
      children: [
        if (widget.channelList != null)
          Text(
            '${_currentChannelIdx + 1}/${widget.channelList!.length}',
            style: const TextStyle(color: AppColors.whiteMuted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        const SizedBox(width: 16),
        if (currentEpg.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(3)),
            child: const Text('NOW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(currentEpg.first.title ?? '', style: const TextStyle(color: AppColors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
        if (nextEpg.isNotEmpty) ...[
          const SizedBox(width: 12),
          Text('Next: ', style: TextStyle(color: AppColors.whiteMuted, fontSize: 11)),
          Expanded(
            child: Text(nextEpg.first.title ?? '', style: TextStyle(color: AppColors.whiteDim, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ],
    );
  }

  Widget _buildVodBottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(_position), style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            if (widget.duration != null || _totalDuration.inSeconds > 0)
              Text(
                _totalDuration.inSeconds > 0 ? _formatDuration(_totalDuration) : (widget.duration ?? ''),
                style: const TextStyle(color: AppColors.whiteMuted, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_player != null)
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: AppColors.red,
              inactiveTrackColor: AppColors.whiteMuted.withOpacity(0.3),
              thumbColor: AppColors.red,
              overlayColor: AppColors.red.withOpacity(0.2),
            ),
            child: Slider(
              value: _totalDuration.inMilliseconds > 0
                  ? (_position.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
                  : 0.0,
              onChanged: (v) {
                final newPos = Duration(milliseconds: (v * _totalDuration.inMilliseconds).toInt());
                _player!.seek(newPos);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    final currentEpg = _epgEntries.where((e) => e.isCurrentlyAiring).toList();
    final nextEpg = _epgEntries.where((e) => !e.isCurrentlyAiring).toList();

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgDeep.withOpacity(0.95),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            border: Border(top: BorderSide(color: AppColors.red.withOpacity(0.3))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (widget.channelIcon != null && widget.channelIcon!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(widget.channelIcon!, width: 40, height: 40, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_currentTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        if (widget.isLive)
                          const Text('Live Channel', style: TextStyle(color: AppColors.redSoft, fontSize: 12, fontWeight: FontWeight.w600))
                        else
                          Row(
                            children: [
                              if (widget.year != null) Text('${widget.year}  ', style: const TextStyle(color: AppColors.whiteDim, fontSize: 12)),
                              if (widget.rating != null) ...[
                                const Icon(Icons.star, color: AppColors.gold, size: 14),
                                Text(' ${widget.rating}  ', style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                              ],
                              if (widget.duration != null) Text(widget.duration!, style: const TextStyle(color: AppColors.whiteDim, fontSize: 12)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: AppColors.whiteMuted), onPressed: () => setState(() => _showInfo = false)),
                ],
              ),
              if (widget.plot != null && widget.plot!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(widget.plot!, style: const TextStyle(color: AppColors.whiteDim, fontSize: 13, height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
                ),
              // Subtitle tracks info
              if (_subtitleTracks.where((t) => t.id != 'no' && t.id != 'auto').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'SUBTITLE TRACKS (${_subtitleTracks.where((t) => t.id != 'no' && t.id != 'auto').length})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.whiteMuted, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: _subtitleTracks.where((t) => t.id != 'no' && t.id != 'auto').map((t) {
                    final isActive = _activeSubtitleTrack?.id == t.id;
                    return GestureDetector(
                      onTap: () {
                        _player?.setSubtitleTrack(t);
                        setState(() => _activeSubtitleTrack = t);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.red : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t.title ?? t.language ?? 'Track ${t.id}',
                          style: TextStyle(fontSize: 11, color: isActive ? Colors.white : AppColors.whiteDim, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (widget.isLive && _epgEntries.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('PROGRAM GUIDE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.whiteMuted, letterSpacing: 1)),
                const SizedBox(height: 8),
                if (currentEpg.isNotEmpty)
                  _EpgInfoTile(entry: currentEpg.first, isNow: true),
                ...nextEpg.take(3).map((e) => _EpgInfoTile(entry: e, isNow: false)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _ControlButton({required this.icon, required this.onTap, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }
}

class _EpgInfoTile extends StatelessWidget {
  final EpgEntry entry;
  final bool isNow;

  const _EpgInfoTile({required this.entry, required this.isNow});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isNow ? AppColors.red.withOpacity(0.1) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(6),
        border: isNow ? Border.all(color: AppColors.red.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          if (isNow)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(3)),
              child: const Text('NOW', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title ?? 'Unknown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isNow ? AppColors.white : AppColors.whiteDim)),
                if (entry.description != null && entry.description!.isNotEmpty)
                  Text(entry.description!, style: const TextStyle(fontSize: 10, color: AppColors.whiteMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
