import 'package:flutter/widgets.dart';

/// Simple callback holder for TV D-pad SELECT action.
/// TvFocusable registers its onTap here when focused.
/// The root D-pad handler (HomeShell, SeriesDetailScreen) calls onSelect
/// when SELECT/ENTER is pressed.
class TvDpadService {
  static VoidCallback? onSelect;
}
