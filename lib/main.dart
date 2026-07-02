import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yun_drum_kit/pages/virtual_drum_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const YunDrumKitApp());
}

class YunDrumKitApp extends StatelessWidget {
  const YunDrumKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yun Drum Kit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: const Color(0xFF11071A),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<_Ripple> _ripples = [];
  int _nextRippleId = 0;
  Duration? _lastTouchTime;
  Offset? _lastTouchPosition;

  void _showRipple(PointerDownEvent event) {
    final lastTime = _lastTouchTime;
    final lastPosition = _lastTouchPosition;
    final isDuplicate =
        lastTime != null &&
        lastPosition != null &&
        event.timeStamp - lastTime < const Duration(milliseconds: 60) &&
        (event.localPosition - lastPosition).distance < 24;

    _lastTouchTime = event.timeStamp;
    _lastTouchPosition = event.localPosition;

    if (isDuplicate) return;

    setState(() {
      _ripples
        ..clear()
        ..add(_Ripple(id: _nextRippleId++, position: event.localPosition));
    });
  }

  void _removeRipple(int id) {
    if (!mounted) return;

    setState(() {
      _ripples.removeWhere((ripple) => ripple.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _showRipple,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      children: [
                        Expanded(
                          child: FeatureCard(
                            icon: Icons.music_note_rounded,
                            title: '虚拟鼓',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      const VirtualDrumPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Expanded(
                          child: FeatureCard(
                            icon: Icons.graphic_eq_rounded,
                            title: '节奏创作',
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Expanded(
                          child: FeatureCard(
                            icon: Icons.library_music_rounded,
                            title: '鼓谱',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            for (final ripple in _ripples)
              Positioned(
                left: ripple.position.dx - 40,
                top: ripple.position.dy - 40,
                child: IgnorePointer(
                  child: TouchRipple(
                    key: ValueKey(ripple.id),
                    onFinished: () => _removeRipple(ripple.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Ripple {
  const _Ripple({required this.id, required this.position});

  final int id;
  final Offset position;
}

class TouchRipple extends StatefulWidget {
  const TouchRipple({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<TouchRipple> createState() => _TouchRippleState();
}

class _TouchRippleState extends State<TouchRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final progress = _progress.value;
        return Opacity(
          opacity: 1 - progress,
          child: Transform.scale(scale: 0.25 + progress, child: child),
        );
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFB99CFF), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66B99CFF),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF21152C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF382747)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 54, color: const Color(0xFFB99CFF)),
                const SizedBox(height: 22),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
