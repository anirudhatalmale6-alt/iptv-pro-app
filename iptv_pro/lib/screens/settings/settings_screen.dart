import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../login/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedSection = 'General';
  bool _hardwareDecoding = true;
  bool _autoUpdateEpg = true;
  bool _autoPlayNext = true;
  String _defaultQuality = 'Auto';
  String _bufferSize = 'Medium (5s)';
  String _epgInterval = 'Every 8 hours';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    if (isWide) {
      return Row(
        children: [
          _buildNav(),
          Expanded(child: _buildContent(provider)),
        ],
      );
    }

    return _buildMobileContent(provider);
  }

  Widget _buildNav() {
    final sections = [
      ('General', Icons.settings_outlined),
      ('Appearance', Icons.palette_outlined),
      ('Player', Icons.play_arrow_outlined),
      ('EPG', Icons.grid_view_outlined),
      ('Parental', Icons.lock_outline),
      ('About', Icons.info_outline),
    ];

    return Container(
      width: 220,
      color: AppColors.bgSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text('SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.whiteMuted)),
          ),
          ...sections.map((s) {
            final isSelected = s.$1 == _selectedSection;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedSection = s.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.red.withOpacity(0.15) : null,
                    border: Border(left: BorderSide(color: isSelected ? AppColors.red : Colors.transparent, width: 3)),
                  ),
                  child: Row(
                    children: [
                      Icon(s.$2, size: 18, color: isSelected ? AppColors.white : AppColors.whiteDim),
                      const SizedBox(width: 12),
                      Text(s.$1, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? AppColors.white : AppColors.whiteDim)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContent(AppProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_selectedSection, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          ..._buildSectionContent(provider),
        ],
      ),
    );
  }

  Widget _buildMobileContent(AppProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupTitle('PLAYBACK'),
          _buildDropdownRow('Default Quality', _defaultQuality, ['Auto', 'Full HD (1080p)', 'HD (720p)', 'SD (480p)'], (v) => setState(() => _defaultQuality = v)),
          _buildToggleRow('Hardware Decoding', 'Use hardware acceleration', _hardwareDecoding, (v) => setState(() => _hardwareDecoding = v)),
          _buildDropdownRow('Buffer Size', _bufferSize, ['Small (2s)', 'Medium (5s)', 'Large (10s)'], (v) => setState(() => _bufferSize = v)),
          _buildToggleRow('Auto-play Next', 'Play next episode automatically', _autoPlayNext, (v) => setState(() => _autoPlayNext = v)),
          const SizedBox(height: 20),
          _buildGroupTitle('EPG'),
          _buildToggleRow('Auto-update EPG', 'Refresh guide data automatically', _autoUpdateEpg, (v) => setState(() => _autoUpdateEpg = v)),
          _buildDropdownRow('Update Interval', _epgInterval, ['Every 4 hours', 'Every 8 hours', 'Every 12 hours', 'Daily'], (v) => setState(() => _epgInterval = v)),
          const SizedBox(height: 20),
          _buildGroupTitle('CONNECTION'),
          _buildInfoRow('Status', provider.isLoggedIn ? 'Connected' : 'Disconnected'),
          _buildInfoRow('Server', provider.service.server),
          _buildInfoRow('Username', provider.service.username),
          if (provider.userInfo?.expDate != null)
            _buildInfoRow('Expires', _formatExpiry(provider.userInfo!.expDate!)),
          const SizedBox(height: 20),
          _buildGroupTitle('ACCOUNT'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _logout(provider),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red.withOpacity(0.15),
                foregroundColor: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSectionContent(AppProvider provider) {
    switch (_selectedSection) {
      case 'General':
        return [
          _buildGroupTitle('PLAYBACK'),
          _buildDropdownRow('Default Quality', _defaultQuality, ['Auto', 'Full HD (1080p)', 'HD (720p)', 'SD (480p)'], (v) => setState(() => _defaultQuality = v)),
          _buildToggleRow('Hardware Decoding', 'Use hardware acceleration for video', _hardwareDecoding, (v) => setState(() => _hardwareDecoding = v)),
          _buildDropdownRow('Buffer Size', _bufferSize, ['Small (2s)', 'Medium (5s)', 'Large (10s)'], (v) => setState(() => _bufferSize = v)),
          _buildToggleRow('Auto-play Next Episode', 'Automatically play the next episode', _autoPlayNext, (v) => setState(() => _autoPlayNext = v)),
        ];
      case 'EPG':
        return [
          _buildGroupTitle('EPG SETTINGS'),
          _buildToggleRow('Auto-update EPG', 'Refresh program guide data automatically', _autoUpdateEpg, (v) => setState(() => _autoUpdateEpg = v)),
          _buildDropdownRow('Update Interval', _epgInterval, ['Every 4 hours', 'Every 8 hours', 'Every 12 hours', 'Daily'], (v) => setState(() => _epgInterval = v)),
        ];
      case 'About':
        return [
          _buildGroupTitle('CONNECTION'),
          _buildInfoRow('Status', provider.isLoggedIn ? 'Connected' : 'Disconnected'),
          _buildInfoRow('Server', provider.service.server),
          _buildInfoRow('Username', provider.service.username),
          _buildInfoRow('Max Connections', '${provider.userInfo?.maxConnections ?? 'N/A'}'),
          if (provider.userInfo?.expDate != null)
            _buildInfoRow('Account Expires', _formatExpiry(provider.userInfo!.expDate!)),
          const SizedBox(height: 24),
          _buildGroupTitle('APP INFO'),
          _buildInfoRow('Version', '1.0.0'),
          _buildInfoRow('Build', 'Android'),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: () => _logout(provider),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.red.withOpacity(0.15), foregroundColor: AppColors.red),
            ),
          ),
        ];
      default:
        return [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text('$_selectedSection settings coming soon', style: TextStyle(color: AppColors.whiteMuted)),
            ),
          ),
        ];
    }
  }

  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.whiteMuted)),
          const SizedBox(height: 6),
          Container(height: 1, color: Colors.white.withOpacity(0.04)),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.whiteMuted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String title, String value, List<String> options, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: DropdownButton<String>(
              value: value,
              dropdownColor: AppColors.bgCard,
              style: const TextStyle(color: AppColors.white, fontSize: 12),
              underline: const SizedBox(),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.whiteDim)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.redSoft)),
        ],
      ),
    );
  }

  String _formatExpiry(String timestamp) {
    try {
      final ts = int.parse(timestamp);
      final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }

  void _logout(AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Logout'),
        content: const Text('Are you sure you want to disconnect?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
