import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/xtream_data.dart';

class MiniPlayerProvider extends ChangeNotifier {
  VideoPlayerController? _controller;
  String? _title;
  String? _url;
  String? _channelIcon;
  int? _streamId;
  bool _isLive = false;
  List<LiveStream>? _channelList;
  int? _channelIndex;
  bool _visible = false;

  VideoPlayerController? get controller => _controller;
  String? get title => _title;
  String? get url => _url;
  String? get channelIcon => _channelIcon;
  int? get streamId => _streamId;
  bool get isLive => _isLive;
  List<LiveStream>? get channelList => _channelList;
  int? get channelIndex => _channelIndex;
  bool get visible => _visible;

  void startMiniPlayer({
    required VideoPlayerController controller,
    required String title,
    required String url,
    String? channelIcon,
    int? streamId,
    bool isLive = false,
    List<LiveStream>? channelList,
    int? channelIndex,
  }) {
    // Don't dispose old controller - it's the same one being transferred
    _controller = controller;
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
    _controller?.dispose();
    _controller = null;
    _visible = false;
    _title = null;
    _url = null;
    notifyListeners();
  }

  /// Take ownership of the controller (for going back to full screen)
  /// Returns the controller without disposing it
  VideoPlayerController? takeController() {
    final ctrl = _controller;
    _controller = null;
    _visible = false;
    notifyListeners();
    return ctrl;
  }
}
