class UserInfo {
  final int? auth;
  final String? status;
  final String? expDate;
  final String? isTrial;
  final int? activeCons;
  final String? createdAt;
  final int? maxConnections;
  final List<String>? allowedOutputFormats;
  final String? username;
  final String? password;
  final String? message;

  UserInfo({
    this.auth,
    this.status,
    this.expDate,
    this.isTrial,
    this.activeCons,
    this.createdAt,
    this.maxConnections,
    this.allowedOutputFormats,
    this.username,
    this.password,
    this.message,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      auth: _toInt(json['auth']),
      status: json['status']?.toString(),
      expDate: json['exp_date']?.toString(),
      isTrial: json['is_trial']?.toString(),
      activeCons: _toInt(json['active_cons']),
      createdAt: json['created_at']?.toString(),
      maxConnections: _toInt(json['max_connections']),
      allowedOutputFormats: (json['allowed_output_formats'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      username: json['username']?.toString(),
      password: json['password']?.toString(),
      message: json['message']?.toString(),
    );
  }

  bool get isAuthenticated => auth == 1;

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}

class ServerInfo {
  final String? url;
  final String? port;
  final String? httpsPort;
  final String? serverProtocol;
  final String? timezone;

  ServerInfo({this.url, this.port, this.httpsPort, this.serverProtocol, this.timezone});

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      url: json['url']?.toString(),
      port: json['port']?.toString(),
      httpsPort: json['https_port']?.toString(),
      serverProtocol: json['server_protocol']?.toString(),
      timezone: json['timezone']?.toString(),
    );
  }
}

class Category {
  final String categoryId;
  final String categoryName;
  final int? parentId;

  Category({required this.categoryId, required this.categoryName, this.parentId});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      categoryId: json['category_id']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? '',
      parentId: json['parent_id'] is int ? json['parent_id'] : int.tryParse(json['parent_id']?.toString() ?? ''),
    );
  }
}

class LiveStream {
  final int? num;
  final String name;
  final String? streamType;
  final int streamId;
  final String? streamIcon;
  final String? epgChannelId;
  final String? added;
  final String? isAdult;
  final String? categoryId;
  final List<dynamic>? categoryIds;
  final String? customSid;
  final int? tvArchive;
  final String? directSource;
  final int? tvArchiveDuration;

  LiveStream({
    this.num,
    required this.name,
    this.streamType,
    required this.streamId,
    this.streamIcon,
    this.epgChannelId,
    this.added,
    this.isAdult,
    this.categoryId,
    this.categoryIds,
    this.customSid,
    this.tvArchive,
    this.directSource,
    this.tvArchiveDuration,
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    return LiveStream(
      num: json['num'] is int ? json['num'] : int.tryParse(json['num']?.toString() ?? ''),
      name: json['name']?.toString() ?? 'Unknown',
      streamType: json['stream_type']?.toString(),
      streamId: json['stream_id'] is int ? json['stream_id'] : int.parse(json['stream_id'].toString()),
      streamIcon: json['stream_icon']?.toString(),
      epgChannelId: json['epg_channel_id']?.toString(),
      added: json['added']?.toString(),
      isAdult: json['is_adult']?.toString(),
      categoryId: json['category_id']?.toString(),
      categoryIds: json['category_ids'] as List<dynamic>?,
      customSid: json['custom_sid']?.toString(),
      tvArchive: json['tv_archive'] is int ? json['tv_archive'] : int.tryParse(json['tv_archive']?.toString() ?? ''),
      directSource: json['direct_source']?.toString(),
      tvArchiveDuration: json['tv_archive_duration'] is int ? json['tv_archive_duration'] : int.tryParse(json['tv_archive_duration']?.toString() ?? ''),
    );
  }
}

class VodStream {
  final int? num;
  final String name;
  final String? streamType;
  final int streamId;
  final String? streamIcon;
  final String? rating;
  final String? ratingFiveStars;
  final String? added;
  final String? categoryId;
  final String? containerExtension;
  final String? customSid;
  final String? directSource;

  VodStream({
    this.num,
    required this.name,
    this.streamType,
    required this.streamId,
    this.streamIcon,
    this.rating,
    this.ratingFiveStars,
    this.added,
    this.categoryId,
    this.containerExtension,
    this.customSid,
    this.directSource,
  });

  factory VodStream.fromJson(Map<String, dynamic> json) {
    return VodStream(
      num: json['num'] is int ? json['num'] : int.tryParse(json['num']?.toString() ?? ''),
      name: json['name']?.toString() ?? 'Unknown',
      streamType: json['stream_type']?.toString(),
      streamId: json['stream_id'] is int ? json['stream_id'] : int.parse(json['stream_id'].toString()),
      streamIcon: json['stream_icon']?.toString(),
      rating: json['rating']?.toString(),
      ratingFiveStars: json['rating_5based']?.toString(),
      added: json['added']?.toString(),
      categoryId: json['category_id']?.toString(),
      containerExtension: json['container_extension']?.toString(),
      customSid: json['custom_sid']?.toString(),
      directSource: json['direct_source']?.toString(),
    );
  }

  double get ratingValue {
    final r = double.tryParse(rating ?? '0') ?? 0;
    return r > 10 ? r / 10 : r;
  }
}

class SeriesItem {
  final int? num;
  final String name;
  final int seriesId;
  final String? cover;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final String? lastModified;
  final String? rating;
  final String? categoryId;
  final String? backdropPath;

  SeriesItem({
    this.num,
    required this.name,
    required this.seriesId,
    this.cover,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.lastModified,
    this.rating,
    this.categoryId,
    this.backdropPath,
  });

  factory SeriesItem.fromJson(Map<String, dynamic> json) {
    return SeriesItem(
      num: json['num'] is int ? json['num'] : int.tryParse(json['num']?.toString() ?? ''),
      name: json['name']?.toString() ?? 'Unknown',
      seriesId: json['series_id'] is int ? json['series_id'] : int.parse(json['series_id'].toString()),
      cover: json['cover']?.toString(),
      plot: json['plot']?.toString(),
      cast: json['cast']?.toString(),
      director: json['director']?.toString(),
      genre: json['genre']?.toString(),
      releaseDate: json['releaseDate']?.toString() ?? json['release_date']?.toString(),
      lastModified: json['last_modified']?.toString(),
      rating: json['rating']?.toString(),
      categoryId: json['category_id']?.toString(),
      backdropPath: json['backdrop_path'] as String?,
    );
  }

  double get ratingValue {
    final r = double.tryParse(rating ?? '0') ?? 0;
    return r > 10 ? r / 10 : r;
  }
}

class SeriesInfo {
  final Map<String, dynamic>? info;
  final Map<String, List<Episode>> seasons;

  SeriesInfo({this.info, required this.seasons});

  factory SeriesInfo.fromJson(Map<String, dynamic> json) {
    final episodes = json['episodes'] as Map<String, dynamic>? ?? {};
    final Map<String, List<Episode>> seasons = {};
    episodes.forEach((seasonNum, episodeList) {
      if (episodeList is List) {
        seasons[seasonNum] = episodeList
            .map((e) => Episode.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    });
    return SeriesInfo(
      info: json['info'] as Map<String, dynamic>?,
      seasons: seasons,
    );
  }
}

class Episode {
  final String? id;
  final int? episodeNum;
  final String? title;
  final String? containerExtension;
  final Map<String, dynamic>? info;
  final String? customSid;
  final String? added;
  final String? season;
  final String? directSource;

  Episode({
    this.id,
    this.episodeNum,
    this.title,
    this.containerExtension,
    this.info,
    this.customSid,
    this.added,
    this.season,
    this.directSource,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id']?.toString(),
      episodeNum: json['episode_num'] is int ? json['episode_num'] : int.tryParse(json['episode_num']?.toString() ?? ''),
      title: json['title']?.toString(),
      containerExtension: json['container_extension']?.toString(),
      info: json['info'] as Map<String, dynamic>?,
      customSid: json['custom_sid']?.toString(),
      added: json['added']?.toString(),
      season: json['season']?.toString(),
      directSource: json['direct_source']?.toString(),
    );
  }

  String? get plot => info?['plot']?.toString();
  String? get duration => info?['duration']?.toString();
  String? get movieImage => info?['movie_image']?.toString();
  String? get rating => info?['rating']?.toString();
}

class EpgEntry {
  final String? id;
  final String? epgId;
  final String? title;
  final String? lang;
  final String? start;
  final String? end;
  final String? description;
  final String? channelId;
  final String? startTimestamp;
  final String? stopTimestamp;

  EpgEntry({
    this.id,
    this.epgId,
    this.title,
    this.lang,
    this.start,
    this.end,
    this.description,
    this.channelId,
    this.startTimestamp,
    this.stopTimestamp,
  });

  static String? _decodeBase64(String? value) {
    if (value == null || value.isEmpty) return value;
    try {
      // Check if it looks like base64 (only contains valid base64 chars)
      final b64Regex = RegExp(r'^[A-Za-z0-9+/=]+$');
      if (b64Regex.hasMatch(value) && value.length > 3) {
        final bytes = _base64Decode(value);
        if (bytes != null) return bytes;
      }
      return value;
    } catch (_) {
      return value;
    }
  }

  static String? _base64Decode(String input) {
    try {
      // Pad if necessary
      String padded = input;
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      final bytes = List<int>.from(_decodeB64Bytes(padded));
      return String.fromCharCodes(bytes);
    } catch (_) {
      return null;
    }
  }

  static List<int> _decodeB64Bytes(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final output = <int>[];
    final buffer = <int>[];
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '=') break;
      final idx = alphabet.indexOf(char);
      if (idx == -1) continue;
      buffer.add(idx);
      if (buffer.length == 4) {
        output.add((buffer[0] << 2) | (buffer[1] >> 4));
        output.add(((buffer[1] & 0x0F) << 4) | (buffer[2] >> 2));
        output.add(((buffer[2] & 0x03) << 6) | buffer[3]);
        buffer.clear();
      }
    }
    if (buffer.length == 3) {
      output.add((buffer[0] << 2) | (buffer[1] >> 4));
      output.add(((buffer[1] & 0x0F) << 4) | (buffer[2] >> 2));
    } else if (buffer.length == 2) {
      output.add((buffer[0] << 2) | (buffer[1] >> 4));
    }
    return output;
  }

  factory EpgEntry.fromJson(Map<String, dynamic> json) {
    return EpgEntry(
      id: json['id']?.toString(),
      epgId: json['epg_id']?.toString(),
      title: _decodeBase64(json['title']?.toString()),
      lang: json['lang']?.toString(),
      start: json['start']?.toString(),
      end: json['end']?.toString(),
      description: _decodeBase64(json['description']?.toString()),
      channelId: json['channel_id']?.toString(),
      startTimestamp: json['start_timestamp']?.toString(),
      stopTimestamp: json['stop_timestamp']?.toString(),
    );
  }

  bool get isCurrentlyAiring {
    // Try timestamps first (most reliable)
    final startTs = int.tryParse(startTimestamp ?? '') ?? 0;
    final stopTs = int.tryParse(stopTimestamp ?? '') ?? 0;
    if (startTs > 0 && stopTs > 0) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return now >= startTs && now <= stopTs;
    }
    // Fallback to date strings
    if (start == null || end == null) return false;
    try {
      final now = DateTime.now();
      // Try parsing as UTC (Xtream API often returns UTC times)
      DateTime startDt = DateTime.tryParse(start!) ?? DateTime.tryParse('${start!}Z') ?? DateTime.parse(start!);
      DateTime endDt = DateTime.tryParse(end!) ?? DateTime.tryParse('${end!}Z') ?? DateTime.parse(end!);
      // If parsed as UTC, convert to local
      if (startDt.isUtc) {
        startDt = startDt.toLocal();
        endDt = endDt.toLocal();
      }
      return now.isAfter(startDt) && now.isBefore(endDt);
    } catch (_) {
      return false;
    }
  }

  bool get isUpcoming {
    final startTs = int.tryParse(startTimestamp ?? '') ?? 0;
    if (startTs > 0) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return now < startTs;
    }
    if (start == null) return false;
    try {
      final now = DateTime.now();
      DateTime startDt = DateTime.tryParse(start!) ?? DateTime.parse(start!);
      if (startDt.isUtc) startDt = startDt.toLocal();
      return now.isBefore(startDt);
    } catch (_) {
      return false;
    }
  }

  String get timeRange {
    // Try timestamps first
    final startTs = int.tryParse(startTimestamp ?? '') ?? 0;
    final stopTs = int.tryParse(stopTimestamp ?? '') ?? 0;
    if (startTs > 0 && stopTs > 0) {
      final s = DateTime.fromMillisecondsSinceEpoch(startTs * 1000);
      final e = DateTime.fromMillisecondsSinceEpoch(stopTs * 1000);
      return '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')} - ${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';
    }
    try {
      if (start != null && end != null) {
        DateTime s = DateTime.tryParse(start!) ?? DateTime.parse(start!);
        DateTime e = DateTime.tryParse(end!) ?? DateTime.parse(end!);
        if (s.isUtc) { s = s.toLocal(); e = e.toLocal(); }
        return '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')} - ${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return '';
  }
}
