import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yun_drum_kit/main.dart';

void main() {
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
}
