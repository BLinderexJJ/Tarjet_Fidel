import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarjet_fidel/widgets/app_animations.dart';
import 'package:tarjet_fidel/widgets/confetti_burst.dart';

/// Envuelve el widget en un `MediaQuery` que puede pedir movimiento reducido.
Widget _host(Widget child, {bool reduceMotion = false}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child,
        );
      },
    ),
  );
}

void main() {
  group('AnimatedIndexedStack', () {
    testWidgets('mantiene el ticker saliente durante el fundido', (
      tester,
    ) async {
      Widget build(int index) => _host(
        AnimatedIndexedStack(
          index: index,
          duration: const Duration(milliseconds: 200),
          children: const [Text('A'), Text('B')],
        ),
      );

      List<bool> tickers() => tester
          .widgetList<TickerMode>(
            find.descendant(
              of: find.byType(AnimatedIndexedStack),
              matching: find.byType(TickerMode),
            ),
          )
          .map((widget) => widget.enabled)
          .toList();

      await tester.pumpWidget(build(0));
      await tester.pumpAndSettle();
      expect(tickers(), [true, false]);

      await tester.pumpWidget(build(1));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tickers(), [true, true]);

      await tester.pumpAndSettle();
      expect(tickers(), [false, true]);
    });

    testWidgets('sin animación usa IndexedStack', (tester) async {
      await tester.pumpWidget(
        _host(
          const AnimatedIndexedStack(
            index: 1,
            children: [Text('A'), Text('B')],
          ),
          reduceMotion: true,
        ),
      );

      expect(find.byType(IndexedStack), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AnimatedIndexedStack),
          matching: find.byType(AnimatedOpacity),
        ),
        findsNothing,
      );
    });
  });

  group('movimiento reducido', () {
    testWidgets('Reveal no crea animación', (tester) async {
      await tester.pumpWidget(_host(const Reveal(child: Text('hola'))));
      expect(find.byType(Animate), findsOneWidget);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _host(const Reveal(child: Text('hola')), reduceMotion: true),
      );
      expect(find.byType(Animate), findsNothing);
    });

    testWidgets('Pulse no anima el icono', (tester) async {
      await tester.pumpWidget(
        _host(const Pulse(child: Icon(Icons.star_rounded))),
      );
      expect(
        find.descendant(
          of: find.byType(Pulse),
          matching: find.byType(AnimatedBuilder),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _host(const Pulse(child: Icon(Icons.star_rounded)), reduceMotion: true),
      );
      expect(
        find.descendant(
          of: find.byType(Pulse),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );
    });

    testWidgets('CelebrationOnChange no lanza confeti', (tester) async {
      Widget build(int value) => _host(
        CelebrationOnChange(
          value: value,
          child: const SizedBox(width: 20, height: 20),
        ),
        reduceMotion: true,
      );

      await tester.pumpWidget(build(1));
      await tester.pumpWidget(build(2));

      final confetti = tester.widget<ConfettiBurst>(find.byType(ConfettiBurst));
      expect(confetti.trigger, 0);
    });

    testWidgets('CelebrationOnChange lanza confeti sin la preferencia', (
      tester,
    ) async {
      Widget build(int value) => _host(
        CelebrationOnChange(
          value: value,
          child: const SizedBox(width: 20, height: 20),
        ),
      );

      await tester.pumpWidget(build(1));
      await tester.pumpWidget(build(2));

      final confetti = tester.widget<ConfettiBurst>(find.byType(ConfettiBurst));
      expect(confetti.trigger, 1);

      await tester.pumpAndSettle();
    });
  });
}
