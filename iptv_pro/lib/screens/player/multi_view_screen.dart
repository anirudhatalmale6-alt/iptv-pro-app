import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../config/theme.dart';
import '../../models/xtream_data.dart';
import '../../providers/app_provider.dart';
import '../../providers/mini_player_provider.dart';
import 'player_screen.dart';

class MultiViewScreen extends StatefulWidget {
  final List<LiveStream> channels;

  const MultiViewScreen({super.key, required this.channels});

  @override
  State<MultiViewScreen> createState() => _MultiViewScreenState();
}

class _MultiViewScreenState extends State<MultiViewScreen> {
  final List<_ViewData?> _views = [null, null, null, null];
  int _layout = 2;
  int _focusedIndex = 0;
  bool _showChannelPicker = false;
  int _pickingForSlot = 0;
  String _pickerSearch = '';
  final _pickerSearchController = TextEditingController();
  List<LiveStream> _pickerChannels = [];
  String? _pickerCategoryId;
  bool _pickerLoading = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _pickerChannels = widget.channels;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MiniPlayerProvider>().dismiss();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _showChannelPicker = true;
        _pickingForSlot = 0;
      });
    });
  }

  void _startChannel(int slot, LiveStream channel) {
    _views[slot]?.player.dispose();

    final provider = context.read<AppProvider>();
    final url = provider.buildLiveUrl(channel.streamId);
    // Use smaller buffer for multi-view to reduce memory pressure
    final player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 2 * 1024 * 1024, // 2MB buffer (vs default ~32MB)
      ),
    );
    if (player.platform is NativePlayer) {
      (player.platform as NativePlayer).setProperty('user-agent', 'Lavf/60.3.100');
    }
    final videoController = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    _views[slot] = _ViewData(channel: channel, player: player, videoController: videoController, url: url);

    player.open(Media(url)).then((_) {
      if (mounted) {
        player.setVolume(slot == _focusedIndex ? 100.0 : 0.0);
        setState(() {});
      }
    }).catchError((e) {
      debugPrint('Multi-view player $slot error: $e');
      if (mounted) setState(() {});
    });

    // Monitor for stream errors and auto-recover
    player.stream.error.listen((error) {
      debugPrint('Multi-view stream $slot error: $error');
      if (mounted && _views[slot]?.channel == channel) {
        // Auto-restart after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _views[slot]?.channel == channel) {
            player.open(Media(url));
          }
        });
      }
    });

    setState(() {});
  }

  void _openChannelPicker(int slot) {
    _pickerSearchController.clear();
    setState(() {
      _showChannelPicker = true;
      _pickingForSlot = slot;
      _pickerSearch = '';
    });
  }

  Future<void> _loadPickerCategory(String? categoryId) async {
    setState(() {
      _pickerCategoryId = categoryId;
      _pickerLoading = true;
    });
    try {
      final provider = context.read<AppProvider>();
      final streams = await provider.service.getLiveStreams(categoryId: categoryId);
      if (mounted) {
        setState(() {
          _pickerChannels = streams;
          _pickerLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _pickerLoading = false);
    }
  }

  void _switchLayout(int count) {
    if (count < _layout) {
      for (int i = count; i < 4; i++) {
        _views[i]?.player.dispose();
        _views[i] = null;
      }
    }
    setState(() {
      _layout = count;
      if (_focusedIndex >= count) _focusedIndex = 0;
    });
  }

  void _focusView(int index) {
    for (int i = 0; i < _views.length; i++) {
      _views[i]?.player.setVolume(i == index ? 100.0 : 0.0);
    }
    setState(() => _focusedIndex = index);
  }

  void _goFullScreen(int index) {
    final view = _views[index];
    if (view == null) return;
    final ch = view.channel;
    final provider = context.read<AppProvider>();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        url: provider.buildLiveUrl(ch.streamId),
        title: ch.name,
        isLive: true,
        channelIcon: ch.streamIcon,
        streamId: ch.streamId,
        channelList: _pickerChannels,
        currentChannelIndex: _pickerChannels.indexOf(ch),
      ),
    ));
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    for (final v in _views) {
      v?.player.dispose();
    }
    _pickerSearchController.dispose();
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
          _buildGrid(),
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
                  _LayoutButton(label: '2', isActive: _layout == 2, onTap: () => _switchLayout(2)),
                  const SizedBox(width: 8),
                  _LayoutButton(label: '4', isActive: _layout == 4, onTap: () => _switchLayout(4)),
                ],
              ),
            ),
          ),
          if (_showChannelPicker) _buildChannelPicker(),
        ],
      ),
    );
  }

  Widget _buildChannelPicker() {
    final filtered = _pickerSearch.isEmpty
        ? _pickerChannels
        : _pickerChannels.where((c) => c.name.toLowerCase().contains(_pickerSearch.toLowerCase())).toList();

    final provider = context.read<AppProvider>();
    final categories = provider.liveCategories;

    return Container(
      color: Colors.black.withOpacity(0.92),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() => _showChannelPicker = false),
                ),
                const SizedBox(width: 8),
                Text('Pick channel for View ${_pickingForSlot + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _pickerSearchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search channels...',
                  hintStyle: TextStyle(color: AppColors.whiteMuted, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.whiteMuted),
                  suffixIcon: _pickerSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: AppColors.whiteMuted),
                          onPressed: () {
                            _pickerSearchController.clear();
                            setState(() => _pickerSearch = '');
                          },
                        )
                      : null,
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: AppColors.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => _pickerSearch = v),
              ),
            ),
          ),
          if (categories.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = _pickerCategoryId == cat.categoryId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _loadPickerCategory(cat.categoryId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.red : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? AppColors.red : Colors.white10),
                        ),
                        child: Text(cat.categoryName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.whiteDim)),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: _pickerLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.red, strokeWidth: 2))
                : filtered.isEmpty
                    ? Center(child: Text(_pickerSearch.isNotEmpty ? 'No channels match "$_pickerSearch"' : 'No channels', style: TextStyle(color: AppColors.whiteMuted)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final ch = filtered[index];
                          final inSlot = _views.any((v) => v?.channel.streamId == ch.streamId);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _startChannel(_pickingForSlot, ch);
                                setState(() => _showChannelPicker = false);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: inSlot ? AppColors.red.withOpacity(0.2) : AppColors.bgCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: inSlot ? AppColors.red : Colors.white10),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: ch.streamIcon != null && ch.streamIcon!.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: ch.streamIcon!,
                                              fit: BoxFit.contain,
                                              errorWidget: (_, __, ___) => const Icon(Icons.tv, color: AppColors.whiteMuted, size: 20),
                                            )
                                          : const Icon(Icons.tv, color: AppColors.whiteMuted, size: 20),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(ch.name, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                                        maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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
    if (index >= _layout) return const SizedBox();

    final view = _views[index];
    final isFocused = index == _focusedIndex;

    if (view == null) {
      return GestureDetector(
        onTap: () => _openChannelPicker(index),
        child: Container(
          color: AppColors.bgDeep,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.red.withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.add, color: AppColors.red, size: 28),
                ),
                const SizedBox(height: 8),
                Text('View ${index + 1}', style: const TextStyle(color: AppColors.whiteMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                const Text('Tap to add channel', style: TextStyle(color: AppColors.whiteMuted, fontSize: 10)),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _focusView(index),
      onDoubleTap: () => _goFullScreen(index),
      onLongPress: () => _openChannelPicker(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: isFocused ? AppColors.red : Colors.transparent, width: 2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              controller: view.videoController,
              controls: NoVideoControls,
            ),
            Positioned(
              bottom: 4, left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(3)),
                child: Text(view.channel.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1),
              ),
            ),
            Positioned(
              bottom: 4, right: 4,
              child: GestureDetector(
                onTap: () => _openChannelPicker(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.swap_horiz, color: Colors.white, size: 14),
                ),
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
  final Player player;
  final VideoController videoController;
  final String url;

  _ViewData({required this.channel, required this.player, required this.videoController, required this.url});
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
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
      ),
    );
  }
}
