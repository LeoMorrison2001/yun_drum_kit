import 'package:flutter/material.dart';
import 'package:yun_drum_kit/audio/drum_audio_engine.dart';

const _drumPads = [
  (
    label: '强音镲',
    color: Color(0xFFFF6B6B),
    asset: 'assets/audio/drums/crash.wav',
  ),
  (
    label: '高音嗵鼓',
    color: Color(0xFFFF9F43),
    asset: 'assets/audio/drums/tom_1.wav',
  ),
  (
    label: '中音嗵鼓',
    color: Color(0xFFFFC048),
    asset: 'assets/audio/drums/tom_2.wav',
  ),
  (
    label: '低音嗵鼓',
    color: Color(0xFF7BED9F),
    asset: 'assets/audio/drums/tom_3.wav',
  ),
  (
    label: '叮叮镲',
    color: Color(0xFF2ED573),
    asset: 'assets/audio/drums/ride.wav',
  ),
  (
    label: '开镲',
    color: Color(0xFF5352ED),
    asset: 'assets/audio/drums/hihat_open.wav',
  ),
  (
    label: '闭镲',
    color: Color(0xFF70A1FF),
    asset: 'assets/audio/drums/hihat_closed.wav',
  ),
  (
    label: '脚踩镲',
    color: Color(0xFFA55EEA),
    asset: 'assets/audio/drums/hihat_pedal.wav',
  ),
  (
    label: '军鼓',
    color: Color(0xFFFF6B81),
    asset: 'assets/audio/drums/snare.wav',
  ),
  (
    label: '底鼓',
    color: Color(0xFF00D2D3),
    asset: 'assets/audio/drums/kick.wav',
  ),
];

class VirtualDrumPage extends StatefulWidget {
  const VirtualDrumPage({super.key});

  @override
  State<VirtualDrumPage> createState() => _VirtualDrumPageState();
}

class _VirtualDrumPageState extends State<VirtualDrumPage> {
  final DrumAudioEngine _audioEngine = DrumAudioEngine.instance;

  @override
  void initState() {
    super.initState();
    _audioEngine.initialize(_drumPads.map((pad) => pad.asset));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '返回首页',
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '虚拟鼓',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 72),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 12, 32, 28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 18.0;
                    final padWidth = (constraints.maxWidth - spacing * 4) / 5;
                    final padHeight =
                        (constraints.maxHeight - spacing) / 2;

                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            childAspectRatio: padWidth / padHeight,
                          ),
                      itemCount: _drumPads.length,
                      itemBuilder: (context, index) {
                        final pad = _drumPads[index];
                        return DrumPad(
                          label: pad.label,
                          color: pad.color,
                          onPressed: () => _audioEngine.play(pad.asset),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DrumPad extends StatefulWidget {
  const DrumPad({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<DrumPad> createState() => _DrumPadState();
}

class _DrumPadState extends State<DrumPad> {
  final Set<int> _activePointers = {};

  void _press(PointerDownEvent event) {
    setState(() => _activePointers.add(event.pointer));
    widget.onPressed();
  }

  void _release(PointerEvent event) {
    setState(() => _activePointers.remove(event.pointer));
  }

  @override
  Widget build(BuildContext context) {
    final isPressed = _activePointers.isNotEmpty;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _press,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: AnimatedScale(
        scale: isPressed ? 1.045 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1224),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPressed
                  ? Color.lerp(widget.color, Colors.white, 0.25)!
                  : widget.color.withValues(alpha: 0.8),
              width: isPressed ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(
                  alpha: isPressed ? 0.72 : 0.12,
                ),
                blurRadius: isPressed ? 28 : 10,
                spreadRadius: isPressed ? 4 : 0,
              ),
              const BoxShadow(
                color: Color(0x66000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                opacity: isPressed ? 1 : 0.22,
                duration: const Duration(milliseconds: 90),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: RadialGradient(
                      colors: [
                        widget.color.withValues(
                          alpha: isPressed ? 0.42 : 0.1,
                        ),
                        widget.color.withValues(alpha: 0),
                      ],
                      stops: const [0, 1],
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 90),
                    style: TextStyle(
                      color: isPressed
                          ? Color.lerp(widget.color, Colors.white, 0.3)
                          : widget.color,
                      fontSize: isPressed ? 19 : 18,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: widget.color.withValues(
                            alpha: isPressed ? 0.9 : 0.35,
                          ),
                          blurRadius: isPressed ? 14 : 5,
                        ),
                      ],
                    ),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
