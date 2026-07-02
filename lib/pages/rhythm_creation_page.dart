import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yun_drum_kit/audio/drum_audio_engine.dart';

const _tracks = [
  (
    label: '闭镲',
    color: Color(0xFF70A1FF),
    asset: 'assets/audio/drums/hihat_closed.wav',
  ),
  (
    label: '底鼓',
    color: Color(0xFF00D2D3),
    asset: 'assets/audio/drums/kick.wav',
  ),
  (
    label: '军鼓',
    color: Color(0xFFFF6B81),
    asset: 'assets/audio/drums/snare.wav',
  ),
  (
    label: '强音镲',
    color: Color(0xFFFF6B6B),
    asset: 'assets/audio/drums/crash.wav',
  ),
  (
    label: '叮叮镲',
    color: Color(0xFF2ED573),
    asset: 'assets/audio/drums/ride.wav',
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
    label: '开镲',
    color: Color(0xFF5352ED),
    asset: 'assets/audio/drums/hihat_open.wav',
  ),
  (
    label: '脚踩镲',
    color: Color(0xFFA55EEA),
    asset: 'assets/audio/drums/hihat_pedal.wav',
  ),
];

enum _TimeSignature {
  fourFour(label: '4/4', stepCount: 16, subdivisionsPerBeat: 4),
  threeFour(label: '3/4', stepCount: 12, subdivisionsPerBeat: 4),
  sixEight(label: '6/8', stepCount: 12, subdivisionsPerBeat: 2);

  const _TimeSignature({
    required this.label,
    required this.stepCount,
    required this.subdivisionsPerBeat,
  });

  final String label;
  final int stepCount;
  final int subdivisionsPerBeat;
}

class RhythmCreationPage extends StatefulWidget {
  const RhythmCreationPage({super.key});

  @override
  State<RhythmCreationPage> createState() => _RhythmCreationPageState();
}

class _RhythmCreationPageState extends State<RhythmCreationPage> {
  final DrumAudioEngine _audioEngine = DrumAudioEngine.instance;
  List<List<List<bool>>>? _measureData;

  _TimeSignature _timeSignature = _TimeSignature.fourFour;
  Timer? _timer;
  int _selectedMeasureIndex = 0;
  int? _playbackMeasureIndex;
  int? _currentStep;
  int _bpm = 120;

  bool get _isPlaying => _timer != null;
  List<List<List<bool>>> get _measures =>
      _measureData ??= [
        _createEmptyMeasure(_TimeSignature.fourFour.stepCount),
      ];
  List<List<bool>> get _currentMeasure =>
      _measures[_selectedMeasureIndex];

  @override
  void initState() {
    super.initState();
    _audioEngine.initialize(_tracks.map((track) => track.asset));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _stepDuration {
    final milliseconds =
        60000 / _bpm / _timeSignature.subdivisionsPerBeat;
    return Duration(microseconds: (milliseconds * 1000).round());
  }

  List<List<bool>> _createEmptyMeasure(int stepCount) {
    return List.generate(
      _tracks.length,
      (_) => List.filled(stepCount, false),
    );
  }

  void _toggleStep(int trackIndex, int stepIndex) {
    setState(() {
      final steps = _currentMeasure[trackIndex];
      steps[stepIndex] = !steps[stepIndex];
    });
    _audioEngine.play(_tracks[trackIndex].asset);
  }

  void _selectMeasure(int index) {
    if (_isPlaying) _stop();
    setState(() => _selectedMeasureIndex = index);
  }

  void _addEmptyMeasure() {
    if (_isPlaying) _stop();
    setState(() {
      _measures.add(_createEmptyMeasure(_timeSignature.stepCount));
      _selectedMeasureIndex = _measures.length - 1;
    });
  }

  void _duplicateCurrentMeasure() {
    if (_isPlaying) _stop();
    final copy = _currentMeasure
        .map((trackSteps) => List<bool>.from(trackSteps))
        .toList();

    setState(() {
      final insertIndex = _selectedMeasureIndex + 1;
      _measures.insert(insertIndex, copy);
      _selectedMeasureIndex = insertIndex;
    });
  }

  void _deleteCurrentMeasure() {
    if (_measures.length <= 1) return;
    if (_isPlaying) _stop();

    setState(() {
      _measures.removeAt(_selectedMeasureIndex);
      if (_selectedMeasureIndex >= _measures.length) {
        _selectedMeasureIndex = _measures.length - 1;
      }
    });
  }

  void _changeBpm(int amount) {
    final nextBpm = (_bpm + amount).clamp(40, 240) as int;
    if (nextBpm == _bpm) return;

    setState(() => _bpm = nextBpm);
    if (_isPlaying) {
      _restartTimerFromCurrentStep();
    }
  }

  Future<void> _editBpm() async {
    final controller = TextEditingController(text: '$_bpm');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF21152C),
          title: const Text(
            '设置速度',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              suffixText: 'BPM',
              helperText: '请输入 40–240',
            ),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    final value = int.tryParse(result ?? '');
    if (value == null || !mounted) return;

    final nextBpm = value.clamp(40, 240) as int;
    setState(() => _bpm = nextBpm);
    if (_isPlaying) {
      _restartTimerFromCurrentStep();
    }
  }

  void _changeTimeSignature(_TimeSignature? value) {
    if (value == null || value == _timeSignature) return;

    _stop();
    setState(() {
      _timeSignature = value;
      for (final measure in _measures) {
        for (final trackSteps in measure) {
          if (trackSteps.length < value.stepCount) {
            trackSteps.addAll(
              List.filled(value.stepCount - trackSteps.length, false),
            );
          }
        }
      }
    });
  }

  void _togglePlayback() {
    _isPlaying ? _stop() : _playFromStart();
  }

  void _playFromStart() {
    _timer?.cancel();
    _timer = Timer.periodic(_stepDuration, (_) => _advance());
    setState(() {
      _selectedMeasureIndex = 0;
      _playbackMeasureIndex = 0;
      _currentStep = 0;
    });
    _playStep(0, 0);
  }

  void _advance() {
    var nextStep = (_currentStep ?? -1) + 1;
    var nextMeasure = _playbackMeasureIndex ?? 0;

    if (nextStep >= _timeSignature.stepCount) {
      nextStep = 0;
      nextMeasure = (nextMeasure + 1) % _measures.length;
    }

    setState(() {
      _currentStep = nextStep;
      _playbackMeasureIndex = nextMeasure;
      _selectedMeasureIndex = nextMeasure;
    });
    _playStep(nextMeasure, nextStep);
  }

  void _playStep(int measureIndex, int stepIndex) {
    for (var trackIndex = 0; trackIndex < _tracks.length; trackIndex++) {
      if (_measures[measureIndex][trackIndex][stepIndex]) {
        _audioEngine.play(_tracks[trackIndex].asset);
      }
    }
  }

  void _restartTimerFromCurrentStep() {
    _timer?.cancel();
    _timer = Timer.periodic(_stepDuration, (_) => _advance());
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _playbackMeasureIndex = null;
      _currentStep = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              isPlaying: _isPlaying,
              bpm: _bpm,
              timeSignature: _timeSignature,
              onBack: () => Navigator.of(context).pop(),
              onPlay: _togglePlayback,
              onDecreaseBpm: () => _changeBpm(-1),
              onIncreaseBpm: () => _changeBpm(1),
              onEditBpm: _editBpm,
              onTimeSignatureChanged: _changeTimeSignature,
            ),
            _MeasureBar(
              measureCount: _measures.length,
              selectedIndex: _selectedMeasureIndex,
              onMeasureSelected: _selectMeasure,
              onAddMeasure: _addEmptyMeasure,
              onDuplicateMeasure: _duplicateCurrentMeasure,
              onDeleteMeasure: _deleteCurrentMeasure,
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                itemCount: _tracks.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, trackIndex) {
                  final track = _tracks[trackIndex];
                  return _TrackRow(
                    label: track.label,
                    color: track.color,
                    steps: _currentMeasure[trackIndex],
                    visibleStepCount: _timeSignature.stepCount,
                    subdivisionsPerBeat:
                        _timeSignature.subdivisionsPerBeat,
                    currentStep: _currentStep,
                    onStepPressed: (stepIndex) =>
                        _toggleStep(trackIndex, stepIndex),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isPlaying,
    required this.bpm,
    required this.timeSignature,
    required this.onBack,
    required this.onPlay,
    required this.onDecreaseBpm,
    required this.onIncreaseBpm,
    required this.onEditBpm,
    required this.onTimeSignatureChanged,
  });

  final bool isPlaying;
  final int bpm;
  final _TimeSignature timeSignature;
  final VoidCallback onBack;
  final VoidCallback onPlay;
  final VoidCallback onDecreaseBpm;
  final VoidCallback onIncreaseBpm;
  final VoidCallback onEditBpm;
  final ValueChanged<_TimeSignature?> onTimeSignatureChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 72,
              child: IconButton(
                onPressed: onBack,
                tooltip: '返回首页',
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          const Text(
            '节奏创作',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1224),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF382747)),
                ),
                child: SizedBox(
                  height: 46,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: onDecreaseBpm,
                        tooltip: '降低速度',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.remove_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      Tooltip(
                        message: '点击输入速度',
                        child: InkWell(
                          onTap: onEditBpm,
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 72,
                            height: 38,
                            child: Center(
                              child: Text(
                                '$bpm BPM',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onIncreaseBpm,
                        tooltip: '提高速度',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: const Color(0xFF493856),
                      ),
                      const SizedBox(width: 10),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<_TimeSignature>(
                          value: timeSignature,
                          dropdownColor: const Color(0xFF21152C),
                          iconEnabledColor: const Color(0xFFB99CFF),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          items: _TimeSignature.values
                              .map(
                                (signature) => DropdownMenuItem(
                                  value: signature,
                                  child: Text(signature.label),
                                ),
                              )
                              .toList(),
                          onChanged: onTimeSignatureChanged,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 1,
                        height: 24,
                        color: const Color(0xFF493856),
                      ),
                      IconButton(
                        onPressed: onPlay,
                        tooltip: isPlaying ? '停止' : '从头播放',
                        icon: Icon(
                          isPlaying
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          color: const Color(0xFFB99CFF),
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasureBar extends StatelessWidget {
  const _MeasureBar({
    required this.measureCount,
    required this.selectedIndex,
    required this.onMeasureSelected,
    required this.onAddMeasure,
    required this.onDuplicateMeasure,
    required this.onDeleteMeasure,
  });

  final int measureCount;
  final int selectedIndex;
  final ValueChanged<int> onMeasureSelected;
  final VoidCallback onAddMeasure;
  final VoidCallback onDuplicateMeasure;
  final VoidCallback onDeleteMeasure;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            const Text(
              '小节',
              style: TextStyle(
                color: Color(0xFFB9ACC4),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: measureCount,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = selectedIndex == index;
                  return Center(
                    child: InkWell(
                      onTap: () => onMeasureSelected(index),
                      borderRadius: BorderRadius.circular(9),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 42,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF8062C6)
                              : const Color(0xFF21182A),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFB99CFF)
                                : const Color(0xFF3A2B46),
                          ),
                          boxShadow: isSelected
                              ? const [
                                  BoxShadow(
                                    color: Color(0x668062C6),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            IconButton(
              onPressed: onDuplicateMeasure,
              tooltip: '复制当前小节',
              icon: const Icon(
                Icons.copy_rounded,
                color: Color(0xFFB99CFF),
                size: 22,
              ),
            ),
            IconButton(
              onPressed: measureCount > 1 ? onDeleteMeasure : null,
              tooltip: '删除当前小节',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: measureCount > 1
                    ? const Color(0xFFFF7A90)
                    : const Color(0xFF5A4D62),
                size: 23,
              ),
            ),
            IconButton(
              onPressed: onAddMeasure,
              tooltip: '添加空白小节',
              icon: const Icon(
                Icons.add_box_outlined,
                color: Color(0xFFB99CFF),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.label,
    required this.color,
    required this.steps,
    required this.visibleStepCount,
    required this.subdivisionsPerBeat,
    required this.currentStep,
    required this.onStepPressed,
  });

  final String label;
  final Color color;
  final List<bool> steps;
  final int visibleStepCount;
  final int subdivisionsPerBeat;
  final int? currentStep;
  final ValueChanged<int> onStepPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(visibleStepCount, (stepIndex) {
                final isEnabled = steps[stepIndex];
                final isCurrent = currentStep == stepIndex;
                final isBeatStart = stepIndex % subdivisionsPerBeat == 0;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: isBeatStart && stepIndex > 0 ? 5 : 2,
                      right: 2,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onStepPressed(stepIndex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? color.withValues(alpha: 0.78)
                              : const Color(0xFF21182A),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: isCurrent
                                ? Colors.white
                                : isEnabled
                                ? color
                                : const Color(0xFF3A2B46),
                            width: isCurrent ? 2 : 1,
                          ),
                          boxShadow: isEnabled
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.42),
                                    blurRadius: isCurrent ? 12 : 7,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
