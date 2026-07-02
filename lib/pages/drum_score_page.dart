import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yun_drum_kit/audio/drum_audio_engine.dart';

const _scoreInstruments = [
  (
    label: '闭镲',
    color: Color(0xFF70A1FF),
    asset: 'assets/audio/drums/hihat_closed.wav',
    staffOffset: -3.0,
    crossed: true,
  ),
  (
    label: '底鼓',
    color: Color(0xFF00D2D3),
    asset: 'assets/audio/drums/kick.wav',
    staffOffset: 3.0,
    crossed: false,
  ),
  (
    label: '军鼓',
    color: Color(0xFFFF6B81),
    asset: 'assets/audio/drums/snare.wav',
    staffOffset: 0.0,
    crossed: false,
  ),
  (
    label: '强音镲',
    color: Color(0xFFFF6B6B),
    asset: 'assets/audio/drums/crash.wav',
    staffOffset: -5.0,
    crossed: true,
  ),
  (
    label: '叮叮镲',
    color: Color(0xFF2ED573),
    asset: 'assets/audio/drums/ride.wav',
    staffOffset: -4.0,
    crossed: true,
  ),
  (
    label: '高音嗵鼓',
    color: Color(0xFFFF9F43),
    asset: 'assets/audio/drums/tom_1.wav',
    staffOffset: -2.0,
    crossed: false,
  ),
  (
    label: '中音嗵鼓',
    color: Color(0xFFFFC048),
    asset: 'assets/audio/drums/tom_2.wav',
    staffOffset: -1.0,
    crossed: false,
  ),
  (
    label: '低音嗵鼓',
    color: Color(0xFF7BED9F),
    asset: 'assets/audio/drums/tom_3.wav',
    staffOffset: 1.0,
    crossed: false,
  ),
  (
    label: '开镲',
    color: Color(0xFF5352ED),
    asset: 'assets/audio/drums/hihat_open.wav',
    staffOffset: -3.0,
    crossed: true,
  ),
  (
    label: '脚踩镲',
    color: Color(0xFFA55EEA),
    asset: 'assets/audio/drums/hihat_pedal.wav',
    staffOffset: 5.0,
    crossed: true,
  ),
];

enum _ScoreTimeSignature {
  fourFour(label: '4/4', beats: 4, stepsPerBeat: 4),
  threeFour(label: '3/4', beats: 3, stepsPerBeat: 4),
  sixEight(label: '6/8', beats: 6, stepsPerBeat: 2);

  const _ScoreTimeSignature({
    required this.label,
    required this.beats,
    required this.stepsPerBeat,
  });

  final String label;
  final int beats;
  final int stepsPerBeat;

  int get stepCount => beats * stepsPerBeat;
}

class DrumScorePage extends StatefulWidget {
  const DrumScorePage({super.key});

  @override
  State<DrumScorePage> createState() => _DrumScorePageState();
}

class _DrumScorePageState extends State<DrumScorePage> {
  final DrumAudioEngine _audioEngine = DrumAudioEngine.instance;
  late final List<List<List<bool>>> _measures;

  _ScoreTimeSignature _timeSignature = _ScoreTimeSignature.fourFour;
  int _selectedMeasure = 0;
  int _bpm = 120;
  Timer? _timer;
  int? _playingMeasure;
  int? _playingStep;

  bool get _isPlaying => _timer != null;
  List<List<bool>> get _currentMeasure => _measures[_selectedMeasure];

  @override
  void initState() {
    super.initState();
    _measures = [_emptyMeasure(_timeSignature.stepCount)];
    _audioEngine.initialize(_scoreInstruments.map((item) => item.asset));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<List<bool>> _emptyMeasure(int stepCount) {
    return List.generate(
      _scoreInstruments.length,
      (_) => List.filled(stepCount, false),
    );
  }

  Duration get _stepDuration {
    final milliseconds = 60000 / _bpm / _timeSignature.stepsPerBeat;
    return Duration(microseconds: (milliseconds * 1000).round());
  }

  void _toggleHit(int instrumentIndex, int stepIndex) {
    setState(() {
      final steps = _currentMeasure[instrumentIndex];
      steps[stepIndex] = !steps[stepIndex];
    });
    _audioEngine.play(_scoreInstruments[instrumentIndex].asset);
  }

  void _selectMeasure(int index) {
    _stopPlayback();
    setState(() => _selectedMeasure = index);
  }

  void _addMeasure() {
    _stopPlayback();
    setState(() {
      _measures.add(_emptyMeasure(_timeSignature.stepCount));
      _selectedMeasure = _measures.length - 1;
    });
  }

  void _duplicateMeasure() {
    _stopPlayback();
    final copy = _currentMeasure
        .map((steps) => List<bool>.from(steps))
        .toList();
    setState(() {
      _measures.insert(_selectedMeasure + 1, copy);
      _selectedMeasure++;
    });
  }

  void _deleteMeasure() {
    if (_measures.length == 1) return;
    _stopPlayback();
    setState(() {
      _measures.removeAt(_selectedMeasure);
      _selectedMeasure = math.min(_selectedMeasure, _measures.length - 1);
    });
  }

  void _changeTimeSignature(_ScoreTimeSignature? signature) {
    if (signature == null || signature == _timeSignature) return;
    _stopPlayback();
    setState(() {
      _timeSignature = signature;
      for (final measure in _measures) {
        for (final steps in measure) {
          if (steps.length < signature.stepCount) {
            steps.addAll(
              List.filled(signature.stepCount - steps.length, false),
            );
          } else if (steps.length > signature.stepCount) {
            steps.removeRange(signature.stepCount, steps.length);
          }
        }
      }
    });
  }

  void _changeBpm(int amount) {
    final next = (_bpm + amount).clamp(40, 240);
    if (next == _bpm) return;
    setState(() => _bpm = next);
    if (_isPlaying) _restartTimer();
  }

  Future<void> _editBpm() async {
    var inputValue = '$_bpm';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF21152C),
        title: const Text('设置速度', style: TextStyle(color: Colors.white)),
        content: TextFormField(
          initialValue: inputValue,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            suffixText: 'BPM',
            helperText: '请输入 40–240',
          ),
          onChanged: (value) => inputValue = value,
          onFieldSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(inputValue),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    final value = int.tryParse(result ?? '');
    if (value == null || !mounted) return;
    setState(() => _bpm = value.clamp(40, 240));
    if (_isPlaying) _restartTimer();
  }

  void _togglePlayback() {
    _isPlaying ? _stopPlayback() : _startPlayback();
  }

  void _startPlayback() {
    _timer?.cancel();
    setState(() {
      _playingMeasure = 0;
      _playingStep = 0;
      _selectedMeasure = 0;
    });
    _playStep(0, 0);
    _timer = Timer.periodic(_stepDuration, (_) => _advancePlayback());
  }

  void _advancePlayback() {
    var measure = _playingMeasure ?? 0;
    var step = (_playingStep ?? -1) + 1;
    if (step >= _timeSignature.stepCount) {
      step = 0;
      measure = (measure + 1) % _measures.length;
    }
    setState(() {
      _playingMeasure = measure;
      _playingStep = step;
      _selectedMeasure = measure;
    });
    _playStep(measure, step);
  }

  void _playStep(int measureIndex, int stepIndex) {
    for (var index = 0; index < _scoreInstruments.length; index++) {
      if (_measures[measureIndex][index][stepIndex]) {
        _audioEngine.play(_scoreInstruments[index].asset);
      }
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_stepDuration, (_) => _advancePlayback());
  }

  void _stopPlayback() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _timer = null;
      _playingMeasure = null;
      _playingStep = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ScoreTopBar(
              bpm: _bpm,
              signature: _timeSignature,
              isPlaying: _isPlaying,
              onBack: () => Navigator.of(context).pop(),
              onPlay: _togglePlayback,
              onDecreaseBpm: () => _changeBpm(-1),
              onIncreaseBpm: () => _changeBpm(1),
              onEditBpm: _editBpm,
              onSignatureChanged: _changeTimeSignature,
            ),
            _ScoreMeasureBar(
              count: _measures.length,
              selectedIndex: _selectedMeasure,
              onSelected: _selectMeasure,
              onAdd: _addMeasure,
              onDuplicate: _duplicateMeasure,
              onDelete: _deleteMeasure,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: _EditorPanel(
                        measure: _currentMeasure,
                        stepCount: _timeSignature.stepCount,
                        stepsPerBeat: _timeSignature.stepsPerBeat,
                        playingStep: _playingMeasure == _selectedMeasure
                            ? _playingStep
                            : null,
                        onHitChanged: _toggleHit,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 5,
                      child: _ScorePreview(
                        measures: _measures,
                        signature: _timeSignature,
                        bpm: _bpm,
                        playingMeasure: _playingMeasure,
                        playingStep: _playingStep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreTopBar extends StatelessWidget {
  const _ScoreTopBar({
    required this.bpm,
    required this.signature,
    required this.isPlaying,
    required this.onBack,
    required this.onPlay,
    required this.onDecreaseBpm,
    required this.onIncreaseBpm,
    required this.onEditBpm,
    required this.onSignatureChanged,
  });

  final int bpm;
  final _ScoreTimeSignature signature;
  final bool isPlaying;
  final VoidCallback onBack;
  final VoidCallback onPlay;
  final VoidCallback onDecreaseBpm;
  final VoidCallback onIncreaseBpm;
  final VoidCallback onEditBpm;
  final ValueChanged<_ScoreTimeSignature?> onSignatureChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: '返回首页',
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const Text(
            '鼓谱生成',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onDecreaseBpm,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded, color: Colors.white),
          ),
          InkWell(
            onTap: onEditBpm,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Text(
                '$bpm BPM',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onIncreaseBpm,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<_ScoreTimeSignature>(
              value: signature,
              dropdownColor: const Color(0xFF21152C),
              iconEnabledColor: const Color(0xFFB99CFF),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              items: _ScoreTimeSignature.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(),
              onChanged: onSignatureChanged,
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: onPlay,
            tooltip: isPlaying ? '停止' : '播放',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF8062C6),
            ),
            icon: Icon(
              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

class _ScoreMeasureBar extends StatelessWidget {
  const _ScoreMeasureBar({
    required this.count,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAdd,
    required this.onDuplicate,
    required this.onDelete,
  });

  final int count;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAdd;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            const Text(
              '小节',
              style: TextStyle(
                color: Color(0xFFB9ACC4),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: count,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (context, index) => Center(
                  child: InkWell(
                    onTap: () => onSelected(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 40,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index == selectedIndex
                            ? const Color(0xFF8062C6)
                            : const Color(0xFF21182A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: index == selectedIndex
                              ? const Color(0xFFB99CFF)
                              : const Color(0xFF3A2B46),
                        ),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onDuplicate,
              tooltip: '复制当前小节',
              icon: const Icon(
                Icons.copy_rounded,
                color: Color(0xFFB99CFF),
                size: 21,
              ),
            ),
            IconButton(
              onPressed: count > 1 ? onDelete : null,
              tooltip: '删除当前小节',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: count > 1
                    ? const Color(0xFFFF7A90)
                    : const Color(0xFF55475E),
                size: 22,
              ),
            ),
            IconButton(
              onPressed: onAdd,
              tooltip: '添加小节',
              icon: const Icon(
                Icons.add_box_outlined,
                color: Color(0xFFB99CFF),
                size: 23,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({
    required this.measure,
    required this.stepCount,
    required this.stepsPerBeat,
    required this.playingStep,
    required this.onHitChanged,
  });

  final List<List<bool>> measure;
  final int stepCount;
  final int stepsPerBeat;
  final int? playingStep;
  final void Function(int instrument, int step) onHitChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF181020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF382747)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '节奏编辑',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: _scoreInstruments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 5),
              itemBuilder: (context, instrumentIndex) {
                final instrument = _scoreInstruments[instrumentIndex];
                return SizedBox(
                  height: 39,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 66,
                        child: Text(
                          instrument.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: instrument.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: List.generate(stepCount, (stepIndex) {
                            final enabled = measure[instrumentIndex][stepIndex];
                            final current = playingStep == stepIndex;
                            final beatStart = stepIndex % stepsPerBeat == 0;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: beatStart && stepIndex > 0 ? 4 : 1.5,
                                  right: 1.5,
                                ),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      onHitChanged(instrumentIndex, stepIndex),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 80),
                                    decoration: BoxDecoration(
                                      color: enabled
                                          ? instrument.color.withValues(
                                              alpha: 0.82,
                                            )
                                          : const Color(0xFF251A2E),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: current
                                            ? Colors.white
                                            : enabled
                                            ? instrument.color
                                            : const Color(0xFF3A2B46),
                                        width: current ? 2 : 1,
                                      ),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorePreview extends StatefulWidget {
  const _ScorePreview({
    required this.measures,
    required this.signature,
    required this.bpm,
    required this.playingMeasure,
    required this.playingStep,
  });

  final List<List<List<bool>>> measures;
  final _ScoreTimeSignature signature;
  final int bpm;
  final int? playingMeasure;
  final int? playingStep;

  @override
  State<_ScorePreview> createState() => _ScorePreviewState();
}

class _ScorePreviewState extends State<_ScorePreview> {
  final ScrollController _scrollController = ScrollController();
  double _contentWidth = 0;
  double _viewportWidth = 0;

  @override
  void didUpdateWidget(covariant _ScorePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playingMeasure != oldWidget.playingMeasure ||
        widget.playingStep != oldWidget.playingStep) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _followPlayback());
    }
  }

  void _followPlayback() {
    final measureIndex = widget.playingMeasure;
    final stepIndex = widget.playingStep;
    if (!mounted ||
        measureIndex == null ||
        stepIndex == null ||
        !_scrollController.hasClients ||
        _contentWidth <= 0 ||
        _viewportWidth <= 0) {
      return;
    }

    const leftMargin = 62.0;
    const rightMargin = 22.0;
    final measureWidth =
        (_contentWidth - leftMargin - rightMargin) / widget.measures.length;
    final playheadX =
        leftMargin +
        measureWidth *
            (measureIndex + (stepIndex + 0.5) / widget.signature.stepCount);
    final target = (playheadX - _viewportWidth * 0.65).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('drum-score-preview'),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _viewportWidth = constraints.maxWidth;
            final width = math.max(
              constraints.maxWidth,
              90 + widget.measures.length * 230.0,
            );
            _contentWidth = width;
            return SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: constraints.maxHeight,
                child: CustomPaint(
                  painter: _DrumScorePainter(
                    measures: widget.measures,
                    signature: widget.signature,
                    bpm: widget.bpm,
                    playingMeasure: widget.playingMeasure,
                    playingStep: widget.playingStep,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DrumScorePainter extends CustomPainter {
  const _DrumScorePainter({
    required this.measures,
    required this.signature,
    required this.bpm,
    required this.playingMeasure,
    required this.playingStep,
  });

  final List<List<List<bool>>> measures;
  final _ScoreTimeSignature signature;
  final int bpm;
  final int? playingMeasure;
  final int? playingStep;

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 62.0;
    const rightMargin = 22.0;
    const staffSpacing = 15.0;
    final staffCenter = size.height / 2;
    final staffTop = staffCenter - staffSpacing * 2;
    final staffBottom = staffCenter + staffSpacing * 2;
    final measureWidth =
        (size.width - leftMargin - rightMargin) / measures.length;
    final ink = Paint()
      ..color = const Color(0xFF261E2A)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    _text(canvas, '鼓谱  ·  $bpm BPM', const Offset(18, 14), 15, FontWeight.w700);

    for (var line = 0; line < 5; line++) {
      final y = staffTop + line * staffSpacing;
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width - rightMargin, y),
        ink,
      );
    }

    _drawPercussionClef(canvas, Offset(26, staffCenter));
    _text(
      canvas,
      '${signature.beats}\n${signature == _ScoreTimeSignature.sixEight ? 8 : 4}',
      Offset(43, staffCenter - 25),
      18,
      FontWeight.w700,
      height: 0.85,
    );

    for (var measureIndex = 0; measureIndex < measures.length; measureIndex++) {
      final left = leftMargin + measureIndex * measureWidth;
      final right = left + measureWidth;
      canvas.drawLine(
        Offset(left, staffTop),
        Offset(left, staffBottom),
        ink..strokeWidth = measureIndex == 0 ? 1.5 : 1,
      );

      _text(
        canvas,
        '${measureIndex + 1}',
        Offset(left + 7, staffTop - 27),
        11,
        FontWeight.w600,
        color: const Color(0xFF746879),
      );

      for (var beat = 1; beat < signature.beats; beat++) {
        final beatX = left + measureWidth * beat / signature.beats;
        canvas.drawLine(
          Offset(beatX, staffTop),
          Offset(beatX, staffBottom),
          Paint()
            ..color = const Color(0x1F261E2A)
            ..strokeWidth = 1,
        );
      }

      for (var step = 0; step < signature.stepCount; step++) {
        final x = left + measureWidth * (step + 0.5) / signature.stepCount;
        final active = <int>[];
        for (
          var instrument = 0;
          instrument < _scoreInstruments.length;
          instrument++
        ) {
          if (measures[measureIndex][instrument][step]) {
            active.add(instrument);
          }
        }

        if (playingMeasure == measureIndex && playingStep == step) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(x, staffCenter),
              width: math.max(7, measureWidth / signature.stepCount),
              height: staffBottom - staffTop + 26,
            ),
            Paint()..color = const Color(0x338062C6),
          );
        }

        if (active.isEmpty) continue;
        final noteYs = <double>[];
        for (final instrumentIndex in active) {
          final instrument = _scoreInstruments[instrumentIndex];
          final y = staffCenter + instrument.staffOffset * staffSpacing / 2;
          noteYs.add(y);
          if (instrument.crossed) {
            _drawCrossNote(canvas, Offset(x, y));
          } else {
            _drawOvalNote(canvas, Offset(x, y));
          }
          if (instrumentIndex == 8) {
            canvas.drawCircle(
              Offset(x, y - 9),
              3,
              Paint()
                ..color = const Color(0xFF261E2A)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1,
            );
          }
          _drawLedgerLineIfNeeded(canvas, x, y, staffTop, staffBottom);
        }
        _drawSixteenthStem(canvas, x, noteYs.reduce(math.min));
      }

      if (measureIndex == measures.length - 1) {
        canvas.drawLine(
          Offset(right - 4, staffTop),
          Offset(right - 4, staffBottom),
          ink..strokeWidth = 1,
        );
        canvas.drawLine(
          Offset(right, staffTop),
          Offset(right, staffBottom),
          ink..strokeWidth = 3,
        );
      }
    }

    _drawLegend(canvas, size.height - 28);
  }

  void _drawPercussionClef(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = const Color(0xFF261E2A)
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(center.dx - 4, center.dy - 17),
      Offset(center.dx - 4, center.dy + 17),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 4, center.dy - 17),
      Offset(center.dx + 4, center.dy + 17),
      paint,
    );
  }

  void _drawOvalNote(Canvas canvas, Offset center) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.25);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 11, height: 7.5),
      Paint()
        ..color = const Color(0xFF261E2A)
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
  }

  void _drawCrossNote(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = const Color(0xFF261E2A)
      ..strokeWidth = 1.8;
    canvas.drawLine(center.translate(-5, -5), center.translate(5, 5), paint);
    canvas.drawLine(center.translate(-5, 5), center.translate(5, -5), paint);
  }

  void _drawSixteenthStem(Canvas canvas, double x, double highestY) {
    final paint = Paint()
      ..color = const Color(0xFF261E2A)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final stemX = x + 5;
    final top = highestY - 28;
    canvas.drawLine(Offset(stemX, highestY), Offset(stemX, top), paint);
    final path = Path()
      ..moveTo(stemX, top)
      ..quadraticBezierTo(stemX + 10, top + 5, stemX + 8, top + 14)
      ..moveTo(stemX, top + 7)
      ..quadraticBezierTo(stemX + 9, top + 11, stemX + 7, top + 20);
    canvas.drawPath(path, paint);
  }

  void _drawLedgerLineIfNeeded(
    Canvas canvas,
    double x,
    double y,
    double top,
    double bottom,
  ) {
    if (y >= top && y <= bottom) return;
    canvas.drawLine(
      Offset(x - 8, y),
      Offset(x + 8, y),
      Paint()
        ..color = const Color(0xFF261E2A)
        ..strokeWidth = 1,
    );
  }

  void _drawLegend(Canvas canvas, double y) {
    _text(
      canvas,
      '× 镲片/踩镲    ● 鼓面    每格为一个十六分时值',
      Offset(18, y),
      10,
      FontWeight.w500,
      color: const Color(0xFF746879),
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
    FontWeight weight, {
    Color color = const Color(0xFF261E2A),
    double? height,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          height: height,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DrumScorePainter oldDelegate) {
    return true;
  }
}
