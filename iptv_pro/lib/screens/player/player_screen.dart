import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
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
  // For navigating channels
  final List<LiveStream>? channelList;
  final int? currentChannelIndex;
  // For resuming from mini player
  final VideoPlayerController? existingController;

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
    this.existingController,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _isError = false;
  String _errorMessage = '';
  bool _isInitializing = true;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _showInfo = false;
  bool _subtitlesEnabled = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  List<EpgEntry> _epgEntries = [];
  int _currentChannelIdx = 0;
  String _currentUrl = '';
  String _currentTitle = '';

  bool _transferToMiniOnPop = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _currentUrl = widget.url;
    _currentTitle = widget.title;
    _currentChannelIdx = widget.currentChannelIndex ?? 0;
    // Dismiss any existing mini player
    context.read<MiniPlayerProvider>().dismiss();
    if (widget.existingController != null) {
      // Resume from mini player
      _controller = widget.existingController;
      _controller!.addListener(_onUpdate);
      _totalDuration = _controller!.value.duration;
      _isInitializing = false;
      _isPlaying = _controller!.value.isPlaying;
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
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(_currentUrl),
        httpHeaders: const {'User-Agent': 'IPTV Pro/1.0'},
      );
      await _controller!.initialize();
      _controller!.play();
      _controller!.addListener(_onUpdate);
      _totalDuration = _controller!.value.duration;
      setState(() {
        _isInitializing = false;
        _isPlaying = true;
      });
      _autoHideControls();
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = e.toString();
        _isInitializing = false;
      });
    }
  }

  void _onUpdate() {
    if (!mounted || _controller == null) return;
    final val = _controller!.value;
    setState(() {
      _isPlaying = val.isPlaying;
      _position = val.position;
      _totalDuration = val.duration;
    });
    if (val.hasError) {
      setState(() {
        _isError = true;
        _errorMessage = val.errorDescription ?? 'Playback error';
      });
    }
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
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _seekRelative(int seconds) {
    if (_controller == null) return;
    final newPos = _position + Duration(seconds: seconds);
    _controller!.seekTo(newPos);
  }

  void _switchChannel(int delta) {
    if (widget.channelList == null || widget.channelList!.isEmpty) return;
    final newIdx = (_currentChannelIdx + delta).clamp(0, widget.channelList!.length - 1);
    if (newIdx == _currentChannelIdx) return;
    _currentChannelIdx = newIdx;
    final ch = widget.channelList![newIdx];
    final provider = context.read<AppProvider>();
    final url = provider.buildLiveUrl(ch.streamId);
    _controller?.removeListener(_onUpdate);
    _controller?.dispose();
    _controller = null;
    setState(() {
      _currentUrl = url;
      _currentTitle = ch.name;
      _isInitializing = true;
      _isError = false;
      _epgEntries = [];
    });
    _initPlayer();
    _loadEpg(ch.streamId);
  }

  String _selectedSubtitleLang = 'off';

  void _showSubtitlePicker() {
    final languages = [
      {'code': 'off', 'name': 'Off'},
      {'code': 'eng', 'name': 'English'},
      {'code': 'fra', 'name': 'French'},
      {'code': 'ara', 'name': 'Arabic'},
      {'code': 'spa', 'name': 'Spanish'},
      {'code': 'deu', 'name': 'German'},
      {'code': 'por', 'name': 'Portuguese'},
      {'code': 'ita', 'name': 'Italian'},
      {'code': 'tur', 'name': 'Turkish'},
      {'code': 'rus', 'name': 'Russian'},
      {'code': 'hin', 'name': 'Hindi'},
      {'code': 'zho', 'name': 'Chinese'},
      {'code': 'jpn', 'name': 'Japanese'},
      {'code': 'kor', 'name': 'Korean'},
      {'code': 'nld', 'name': 'Dutch'},
      {'code': 'pol', 'name': 'Polish'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDeep.withOpacity(0.95),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Subtitles / CC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected = _selectedSubtitleLang == lang['code'];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? AppColors.red : AppColors.whiteMuted,
                        size: 20,
                      ),
                      title: Text(lang['name']!, style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.whiteDim,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 14,
                      )),
                      onTap: () {
                        setState(() {
                          _selectedSubtitleLang = lang['code']!;
                          _subtitlesEnabled = lang['code'] != 'off';
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Subtitle availability depends on the stream source. If subtitles are embedded in the stream they will display automatically.',
                  style: TextStyle(color: AppColors.whiteMuted, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _retryPlay() {
    _controller?.removeListener(_onUpdate);
    _controller?.dispose();
    _controller = null;
    setState(() {
      _isInitializing = true;
      _isError = false;
    });
    _initPlayer();
  }

  void _goBackWithMiniPlayer() {
    if (_transferToMiniOnPop && _controller != null && _controller!.value.isInitialized && widget.isLive) {
      _controller!.removeListener(_onUpdate);
      context.read<MiniPlayerProvider>().startMiniPlayer(
        controller: _controller!,
        title: _currentTitle,
        url: _currentUrl,
        channelIcon: widget.channelIcon,
        streamId: widget.streamId,
        isLive: widget.isLive,
        channelList: widget.channelList,
        channelIndex: _currentChannelIdx,
      );
      _controller = null; // Don't dispose - mini player owns it now
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
    _controller?.removeListener(_onUpdate);
    _controller?.dispose();
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
              if (details.primaryVelocity! < -100) _switchChannel(-1); // swipe up = next
              if (details.primaryVelocity! > 100) _switchChannel(1); // swipe down = prev
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video
              _buildVideoLayer(),
              // Controls overlay
              if (_showControls && !_isInitializing && !_isError) _buildControlsOverlay(),
              // Info panel
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
    if (_controller != null && _controller!.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_controller!),
              if (_subtitlesEnabled)
                ClosedCaption(
                  text: _controller!.value.caption.text,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    backgroundColor: Colors.black54,
                  ),
                ),
            ],
          ),
        ),
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
                          _epgEntries.where((e) => e.isCurrentlyAiring).map((e) => e.title ?? '').join('') ?? '',
                          style: const TextStyle(color: AppColors.whiteDim, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Subtitles button
                if (!widget.isLive)
                  IconButton(
                    icon: Icon(
                      _subtitlesEnabled ? Icons.closed_caption : Icons.closed_caption_off,
                      color: _subtitlesEnabled ? AppColors.red : Colors.white,
                    ),
                    onPressed: _showSubtitlePicker,
                  ),
                // Info button
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

        // Bottom bar with progress
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.85), Colors.transparent]),
            ),
            child: widget.isLive
                ? _buildLiveBottomBar()
                : _buildVodBottomBar(),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveBottomBar() {
    // Show channel number and EPG info
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
        // Time labels
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
        // Seek bar
        if (_controller != null)
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
                _controller!.seekTo(newPos);
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
        onTap: () {}, // absorb taps
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
              // Header
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

              // Plot
              if (widget.plot != null && widget.plot!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(widget.plot!, style: const TextStyle(color: AppColors.whiteDim, fontSize: 13, height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
                ),

              // EPG info for live
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
