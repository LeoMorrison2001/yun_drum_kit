import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yun_drum_kit/audio/sample_accurate_rhythm_player.dart';
import 'package:yun_drum_kit/main.dart';

void main() {
  test('节奏循环按采样位置生成', () async {
    final rendered = await renderRhythmLoop(
      RhythmLoopSpec(
        measures: [
          [
            [true, ...List.filled(15, false)],
          ],
        ],
        assetPaths: const ['assets/audio/drums/kick.wav'],
        bpm: 120,
        stepCount: 16,
        subdivisionsPerBeat: 4,
      ),
    );

    expect(String.fromCharCodes(rendered.wavBytes.take(4)), 'RIFF');
    expect(rendered.duration, const Duration(seconds: 2));
    expect(rendered.stepDuration, const Duration(milliseconds: 125));
  });

  testWidgets('应用可以正常启动', (tester) async {
    await tester.pumpWidget(const YunDrumKitApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('虚拟鼓'), findsOneWidget);
    expect(find.text('节奏创作'), findsOneWidget);
    expect(find.text('鼓谱'), findsOneWidget);
  });

  testWidgets('新触摸会替换正在播放的波纹', (tester) async {
    await tester.pumpWidget(const YunDrumKitApp());

    await tester.tapAt(const Offset(100, 100));
    await tester.tapAt(const Offset(200, 100));
    await tester.pump();

    expect(find.byType(TouchRipple), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TouchRipple), findsNothing);
  });

  testWidgets('可以进入独立鼓谱编辑页面', (tester) async {
    await tester.pumpWidget(const YunDrumKitApp());

    await tester.tap(find.text('鼓谱'));
    await tester.pumpAndSettle();

    expect(find.text('鼓谱生成'), findsOneWidget);
    expect(find.text('节奏编辑'), findsOneWidget);
    expect(find.byKey(const Key('drum-score-preview')), findsOneWidget);

    await tester.tap(find.text('120 BPM'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '60');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('60 BPM'), findsOneWidget);
  });
}
