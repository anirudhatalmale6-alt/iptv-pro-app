import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/app_provider.dart';
import '../home/home_shell.dart';
import '../tv/tv_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Track which field is focused for TV D-pad
  int _focusedIndex = 0; // 0=server, 1=username, 2=password, 3=connect
  final _serverFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _connectFocus = FocusNode();
  final _rootFocus = FocusNode();

  // Debug: show what key events Flutter receives on TV
  String _debugLastKey = 'No key pressed yet';
  int _debugKeyCount = 0;

  List<FocusNode> get _focusNodes => [_serverFocus, _usernameFocus, _passwordFocus, _connectFocus];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _tryAutoLogin();

    // Auto-focus server field after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _serverFocus.requestFocus();
    });
  }

  Future<void> _tryAutoLogin() async {
    final provider = context.read<AppProvider>();
    final success = await provider.tryAutoLogin();
    if (success && mounted) {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    // Use TV layout on wide screens (Android TV, tablets in landscape)
    final isTV = MediaQuery.of(context).size.shortestSide > 600 ||
        MediaQuery.of(context).size.width > 960;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => isTV ? const TvHome() : const HomeShell()),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();
    final success = await provider.login(
      _serverController.text.trim(),
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );
    if (success && mounted) {
      _navigateToHome();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Login failed'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  void _moveFocus(int direction) {
    setState(() {
      _focusedIndex = (_focusedIndex + direction).clamp(0, 3);
    });
    _focusNodes[_focusedIndex].requestFocus();
  }

  void _handleSelect() {
    if (_focusedIndex == 3) {
      // Connect button
      _login();
    }
    // For text fields (0-2), ENTER goes through Flutter's normal handling
    // which opens the on-screen keyboard
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Debug: log ALL key events so we can see what the TV sends
    if (event is KeyDownEvent) {
      setState(() {
        _debugKeyCount++;
        _debugLastKey = '#$_debugKeyCount: ${event.logicalKey.keyLabel} (id:${event.logicalKey.keyId}) focused:$_focusedIndex';
      });
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.select ||
               key == LogicalKeyboardKey.enter ||
               key == LogicalKeyboardKey.gameButtonA) {
      if (_focusedIndex == 3) {
        _handleSelect();
        return KeyEventResult.handled;
      }
      // Let text fields handle their own select/enter (opens keyboard)
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _animController.dispose();
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _serverFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _connectFocus.dispose();
    _rootFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final size = MediaQuery.of(context).size;
    final isTV = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: KeyboardListener(
        focusNode: _rootFocus,
        onKeyEvent: (event) {
          // Backup key detection - fires even if Focus.onKeyEvent doesn't
          if (event is KeyDownEvent) {
            setState(() {
              _debugKeyCount++;
              _debugLastKey = '#$_debugKeyCount: ${event.logicalKey.keyLabel} (id:${event.logicalKey.keyId}) focused:$_focusedIndex';
            });
            // Handle navigation
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowDown) {
              _moveFocus(1);
            } else if (key == LogicalKeyboardKey.arrowUp) {
              _moveFocus(-1);
            } else if ((key == LogicalKeyboardKey.select ||
                       key == LogicalKeyboardKey.enter ||
                       key == LogicalKeyboardKey.gameButtonA) && _focusedIndex == 3) {
              _login();
            }
          }
        },
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: BoxConstraints(maxWidth: isTV ? 480 : 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/images/veltrix_logo.png',
                        height: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
                          'VELTRIX TV',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connect to your IPTV service',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 40),

                      // Server URL
                      _buildFocusableField(
                        index: 0,
                        child: TextFormField(
                          controller: _serverController,
                          focusNode: _serverFocus,
                          style: const TextStyle(color: AppColors.white),
                          decoration: const InputDecoration(
                            labelText: 'Server URL',
                            hintText: 'http://example.com:port',
                            prefixIcon: Icon(Icons.dns_outlined, color: AppColors.whiteMuted),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _moveFocus(1),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Username
                      _buildFocusableField(
                        index: 1,
                        child: TextFormField(
                          controller: _usernameController,
                          focusNode: _usernameFocus,
                          style: const TextStyle(color: AppColors.white),
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline, color: AppColors.whiteMuted),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _moveFocus(1),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      _buildFocusableField(
                        index: 2,
                        child: TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          style: const TextStyle(color: AppColors.white),
                          obscureText: MediaQuery.of(context).size.width > 700 ? false : _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.whiteMuted),
                            suffixIcon: MediaQuery.of(context).size.width > 700 ? null : IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: AppColors.whiteMuted,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          onFieldSubmitted: (_) => _moveFocus(1),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Login button
                      _buildFocusableField(
                        index: 3,
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            focusNode: _connectFocus,
                            onPressed: provider.isLoading ? null : _login,
                            child: provider.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('CONNECT', style: TextStyle(letterSpacing: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Enter your Xtream Codes credentials',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (isTV) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Use UP/DOWN arrows to navigate between fields\nPress OK to type, press OK on CONNECT to login',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.whiteMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      // Debug: show key events received from TV remote
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.yellow.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.yellow.withOpacity(0.5)),
                        ),
                        child: Column(
                          children: [
                            const Text('DEBUG - Remote Button Log:', style: TextStyle(color: Colors.yellow, fontSize: 11, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(_debugLastKey, style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFocusableField({required int index, required Widget child}) {
    final isFocused = _focusedIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isFocused
            ? Border.all(color: AppColors.red, width: 2.5)
            : Border.all(color: Colors.transparent, width: 2.5),
        boxShadow: isFocused
            ? [BoxShadow(color: AppColors.red.withOpacity(0.3), blurRadius: 12)]
            : [],
      ),
      child: child,
    );
  }
}
