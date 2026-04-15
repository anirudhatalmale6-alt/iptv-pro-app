import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/xtream_data.dart';
import '../../providers/app_provider.dart';
import 'player_screen.dart';

class MultiViewScreen extends StatefulWidget {
  final List<LiveStream> channels;

  const MultiViewScreen({super.key, required this.channels});

  @override
  State<MultiViewScreen> createState() => _MultiViewScreenState();
}

class _MultiViewScreenState extends State<MultiViewScreen> {
  final List<_ViewData> _views = [];
  int _layout = 2; // 2 or 4
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _initViews();
  }

  void _initViews() {
    final provider = context.read<AppProvider>();
    final count = _layout.clamp(1, widget.channels.length);
    for (int i = 0; i < count && i < widget.channels.length; i++) {
      final ch = widget.channels[i];
      final url = provider.buildLiveUrl(ch.streamId);
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: const {'User-Agent': 'IPTV Pro/1.0'});
      _views.add(_ViewData(channel: ch, controller: ctrl, url: url));
      ctrl.initialize().then((_) {
        if (mounted) {
          ctrl.play();
          ctrl.setVolume(i == 0 ? 1.0 : 0.0); // Only first view has audio
          setState(() {});
        }
      }).catchError((_) {});
    }
  }

  void _disposeViews() {
    for (final v in _views) {
      v.controller.dispose();
    }
    _views.clear();
  }

  void _switchLayout(int count) {
    _disposeViews();
    setState(() {
      _layout = count;
      _focusedIndex = 0;
    });
    _initViews();
  }

  void _focusView(int index) {
    for (int i = 0; i < _views.length; i++) {
      _views[i].controller.setVolume(i == index ? 1.0 : 0.0);
    }
    setState(() => _focusedIndex = index);
  }

  void _goFullScreen(int index) {
    if (index >= _views.length) return;
    final ch = _views[index].channel;
    final provider = context.read<AppProvider>();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        url: provider.buildLiveUrl(ch.streamId),
        title: ch.name,
        isLive: true,
        channelIcon: ch.streamIcon,
        streamId: ch.streamId,
        channelList: widget.channels,
        currentChannelIndex: widget.channels.indexOf(ch),
      ),
    ));
  }

  @override
  void dispose() {
    _disposeViews();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Grid of videos
          _buildGrid(),

          // Top controls
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4, left: 8, right: 8, bottom: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent]),
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  const Text('Multi View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  // Layout toggle
                  _LayoutButton(label: '2', isActive: _layout == 2, onTap: () => _switchLayout(2)),
                  const SizedBox(width: 8),
                  _LayoutButton(label: '4', isActive: _layout == 4, onTap: () => _switchLayout(4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_layout == 2) {
      return Row(
        children: [
          Expanded(child: _buildViewTile(0)),
          Container(width: 2, color: AppColors.bgDeep),
          Expanded(child: _buildViewTile(1)),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildViewTile(0)),
              Container(width: 2, color: AppColors.bgDeep),
              Expanded(child: _buildViewTile(1)),
            ],
          ),
        ),
        Container(height: 2, color: AppColors.bgDeep),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildViewTile(2)),
              Container(width: 2, color: AppColors.bgDeep),
              Expanded(child: _buildViewTile(3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewTile(int index) {
    if (index >= _views.length) {
      return Container(
        color: AppColors.bgDeep,
        child: const Center(child: Icon(Icons.tv_off, color: AppColors.whiteMuted, size: 32)),
      );
    }

    final view = _views[index];
    final isFocused = index == _focusedIndex;

    return GestureDetector(
      onTap: () => _focusView(index),
      onDoubleTap: () => _goFullScreen(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: isFocused ? AppColors.red : Colors.transparent, width: 2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (view.controller.value.isInitialized)
              VideoPlayer(view.controller)
            else
              const Center(child: CircularProgressIndicator(color: AppColors.red, strokeWidth: 2)),
            // Channel name overlay
            Positioned(
              bottom: 4, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(3)),
                child: Text(view.channel.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1),
              ),
            ),
            if (isFocused)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(3)),
                  child: const Icon(Icons.volume_up, color: Colors.white, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewData {
  final LiveStream channel;
  final VideoPlayerController controller;
  final String url;

  _ViewData({required this.channel, required this.controller, required this.url});
}

class _LayoutButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LayoutButton({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: isActive ? AppColors.red : AppColors.bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? AppColors.red : Colors.white12),
        ),
        child: Center(child: Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
      ),
    );
  }
}
