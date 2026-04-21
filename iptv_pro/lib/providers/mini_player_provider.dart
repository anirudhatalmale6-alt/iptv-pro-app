import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/xtream_data.dart';

class MiniPlayerProvider extends ChangeNotifier {
  Player? _player;
  VideoController? _videoController;
  String? _title;
  String? _url;
  String? _channelIcon;
  int? _streamId;
  bool _isLive = false;
  List<LiveStream>? _channelList;
  int? _channelIndex;
  bool _visible = false;

  Player? get player => _player;
  VideoController? get videoController => _videoController;
  String? get title => _title;
  String? get url => _url;
  String? get channelIcon => _channelIcon;
  int? get streamId => _streamId;
  bool get isLive => _isLive;
  List<LiveStream>? get channelList => _channelList;
  int? get channelIndex => _channelIndex;
  bool get visible => _visible;

  void startMiniPlayer({
    required Player player,
    required VideoController videoController,
    required String title,
    required String url,
    String? channelIcon,
    int? streamId,
    bool isLive = false,
    List<LiveStream>? channelList,
    int? channelIndex,
  }) {
    _player = player;
    _videoController = videoController;
    _title = title;
    _url = url;
    _channelIcon = channelIcon;
    _streamId = streamId;
    _isLive = isLive;
    _channelList = channelList;
    _channelIndex = channelIndex;
    _visible = true;
    notifyListeners();
  }

  void dismiss() {
    _player?.dispose();
    _player = null;
    _videoController = null;
    _visible = false;
    _title = null;
    _url = null;
    notifyListeners();
  }

  /// Take ownership of the player (for going back to full screen)
  (Player, VideoController)? takePlayerAndController() {
    final p = _player;
    final vc = _videoController;
    if (p == null || vc == null) return null;
    _player = null;
    _videoController = null;
    _visible = false;
    notifyListeners();
    return (p, vc);
  }

  /// Switch to a different channel while in split-screen mode
  Future<void> switchChannel({
    required String url,
    required String title,
    String? channelIcon,
    int? streamId,
    List<LiveStream>? channelList,
    int? channelIndex,
  }) async {
    _title = title;
    _url = url;
    _channelIcon = channelIcon;
    _streamId = streamId;
    _isLive = true;
    _channelList = channelList;
    _channelIndex = channelIndex;
    notifyListeners();

    try {
      if (_player == null) {
        _player = Player();
        if (_player!.platform is NativePlayer) {
          (_player!.platform as NativePlayer).setProperty('user-agent', 'Lavf/60.3.100');
        }
        _videoController = VideoController(_player!);
      }
      await _player!.open(Media(url));
    } catch (e) {
      _visible = false;
      notifyListeners();
    }
  }
}
