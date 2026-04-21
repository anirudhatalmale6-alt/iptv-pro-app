# TV Remote Research Notes (2026-04-18)

## TiViMate Features to Match

### Navigation & UI
- Left sidebar with icons: Live TV, Movies, Series, Catch-Up, Recordings, Search, Settings
- Category list in sidebar (My List, History, All shows, genre categories)
- Horizontal scrolling content rows on right side
- Series detail with season/episode list, ratings, cast info, Arabic text support
- Full remote control navigation - designed for TV from ground up

### Core Features
1. **Favorites** - long press to add, stored in Favorites tab
2. **Watch History** - shows what you watched
3. **Continue Watching / Resume** - resumes last channel on startup, remembers VOD position
4. **Episode Progress** - shows how much of each episode was watched
5. **Catch-Up TV** - watch past programs (if server supports)
6. **Recording** - live recording + scheduled recording via EPG, saved as video files
7. **Multi-View** - up to 4-9 simultaneous channels
8. **EPG Grid** - multi-day program guide, cable TV style
9. **Parental Controls** - PIN lock channels
10. **Multi-Playlist** - add multiple Xtream Codes accounts
11. **Search** - across all content types

### Player Settings
- Buffer size (Small/Medium/Large)
- Hardware/Software decoder toggle
- Subtitle track selection
- Audio track selection
- Zoom/aspect ratio
- Timeshift (pause/rewind live TV)

### Customization
- Theme/transparency options
- Channel list display modes
- EPG refresh interval
- Default zoom level

## IBO Pro Player Features
- M3U + Xtream Codes support
- Customizable themes (dark mode, font, layout)
- Audio equalizer + surround sound
- EPG auto-refresh every 24h
- HW/SW decoder toggle
- Parental controls
- Subtitle styling

## What Our App Currently Has (6/10 on mobile per client)
- Live TV, Movies, Series, TV Guide tabs ✓
- Favorites ✓
- Search ✓
- Multi-view ✓
- EPG (short) ✓
- Settings (basic) ✓
- Subtitles ✓
- Player with channel switching ✓
- Clean text (emoji removal) ✓

## What's Missing
- Watch history / continue watching
- Resume playback position (VOD)
- Episode progress tracking
- Catch-up TV
- Recording (may not be feasible on mobile)
- Proper TiViMate-style sidebar navigation
- Parental controls
- Multi-playlist support
- Theme customization
- Better channel list display options

## Flutter TV D-pad Solutions Found

### 1. `dpad` package (pub.dev/packages/dpad)
- Purpose-built for Android TV / Fire TV
- DpadFocusable widgets with autofocus and onSelect
- **Region-based navigation** - solves geometric nav issues
- Should replace our custom TvFocusable

### 2. Shortcuts Widget Approach
- Map LogicalKeyboardKey.select to ActivateIntent()
- Flutter-native way to handle TV remote SELECT
- Works with existing Focus system

### 3. Known Flutter Issues
- #147772: D-pad navigation on TextField broken on Android TV
- #49783: Focus gets lost on Android TV
- #49335: Arrow keys don't work for focus traversal of TextFormField
- #35346: Android TV remote control (DPAD) support (master issue)

### 4. Next Steps
- Wait for client's debug screenshot (does Flutter receive key events on his Sony TV?)
- If YES: try `dpad` package, it's designed for exactly this problem
- If NO: may need native Kotlin TV app with Leanback
- Add Shortcuts widget for SELECT key mapping regardless
