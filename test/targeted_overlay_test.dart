import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:targeted_overlay/targeted_overlay.dart';

// Test class that uses the TargetedOverlayMixin
class TestOverlayManager with Diagnosticable, TargetedOverlayMixin {}

void main() {
  group('TargetedOverlayMixin', () {
    late TestOverlayManager manager;

    setUp(() {
      manager = TestOverlayManager();
    });

    group('registerTargets', () {
      testWidgets('should register a single target widget', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                key: key,
                width: 100,
                height: 50,
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        // Verify the target is registered by trying to insert an overlay
        bool builderCalled = false;
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) {
            builderCalled = true;
            return Container();
          },
          attachPoint: AttachPoint.center,
        );

        expect(builderCalled, isFalse);
        await tester.pump();
        expect(builderCalled, isTrue);
      });

      testWidgets('should register multiple target widgets', (WidgetTester tester) async {
        final key1 = GlobalKey();
        final key2 = GlobalKey();
        final key3 = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(key: key1, width: 100, height: 50),
                  SizedBox(key: key2, width: 200, height: 75),
                  SizedBox(key: key3, width: 150, height: 100),
                ],
              ),
            ),
          ),
        );

        manager.registerTargets([key1, key2, key3]);

        // Verify all targets are registered
        for (final key in [key1, key2, key3]) {
          bool builderCalled = false;
          manager.insertOverlay(
            context: tester.element(find.byType(Scaffold)),
            key: key,
            builder: (remove) {
              builderCalled = true;
              return Container();
            },
            attachPoint: AttachPoint.center,
          );
          expect(builderCalled, isFalse);
          await tester.pump();
          expect(builderCalled, isTrue);
        }
      });

      testWidgets('should handle registering key with no render box gracefully', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Container(),
            ),
          ),
        );

        // Try to register a key that isn't attached to any widget
        expect(() => manager.registerTargets([key]), returnsNormally);
      });
    });

    group('insertOverlay', () {
      testWidgets('should insert overlay at correct position', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.only(left: 50, top: 100),
                child: SizedBox(
                  key: key,
                  width: 100,
                  height: 50,
                ),
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        const overlayKey = Key('overlay');
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) {
            return Container(
              key: overlayKey,
              width: 50,
              height: 25,
              color: Colors.red,
            );
          },
          attachPoint: AttachPoint.topLeft,
        );

        await tester.pump();

        // Verify overlay exists
        expect(find.byKey(overlayKey), findsOneWidget);

        // Verify position - target at (50, 100) with size (100, 50)
        // Without mirrors, uses right and bottom positioning
        final overlayWidget = tester.widget<Positioned>(
          find.ancestor(
            of: find.byKey(overlayKey),
            matching: find.byType(Positioned),
          ),
        );

        final screenSize =
            tester.binding.platformDispatcher.views.first.physicalSize /
            tester.binding.platformDispatcher.views.first.devicePixelRatio;

        // For topLeft with no mirrors: right and bottom are set
        expect(overlayWidget.left, isNull);
        expect(overlayWidget.top, isNull);
        expect(overlayWidget.right, isNotNull);
        expect(overlayWidget.bottom, isNotNull);

        // Right should be: screenWidth - (50 + 0) = screenWidth - 50
        expect(overlayWidget.right, equals(screenSize.width - 50.0));
      });

      testWidgets('should apply offset correctly', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.only(left: 50, top: 100),
                child: SizedBox(
                  key: key,
                  width: 100,
                  height: 50,
                ),
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        const overlayKey = Key('overlay-with-offset');
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => Container(
            key: overlayKey,
            width: 20,
            height: 20,
            color: Colors.green,
          ),
          attachPoint: AttachPoint.topLeft,
          offset: const Offset(10, 20),
        );

        await tester.pump();

        // Verify overlay exists
        expect(find.byKey(overlayKey), findsOneWidget);

        final screenSize =
            tester.binding.platformDispatcher.views.first.physicalSize /
            tester.binding.platformDispatcher.views.first.devicePixelRatio;

        // Verify offset is applied: target at (50, 100) + offset (10, 20) = (60, 120)
        // Without mirrors, uses right positioning: screenWidth - 60
        final positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byKey(overlayKey),
            matching: find.byType(Positioned),
          ),
        );

        expect(positioned.right, equals(screenSize.width - 60.0)); // screenWidth - (50 + 10)
        expect(positioned.left, isNull);
      });

      testWidgets('should apply axis mirrors correctly', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.only(left: 50, top: 100),
                child: SizedBox(
                  key: key,
                  width: 100,
                  height: 50,
                ),
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        // Test vertical mirror - uses top instead of bottom
        const verticalKey = Key('vertical-mirror');
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => Container(
            key: verticalKey,
            width: 20,
            height: 20,
            color: Colors.yellow,
          ),
          attachPoint: AttachPoint.topLeft,
          axisMirrors: const AxisMirrors(vertical: true),
        );

        await tester.pump();

        var positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byKey(verticalKey),
            matching: find.byType(Positioned),
          ),
        );

        // Vertical mirror: uses top instead of bottom
        expect(positioned.top, isNotNull);
        expect(positioned.bottom, isNull);
        expect(positioned.left, isNull); // Still uses right for horizontal

        manager.hideOverlays(context: tester.element(find.byType(Scaffold)), keys: [key]);
        await tester.pumpAndSettle();

        // Test horizontal mirror - uses left instead of right
        const horizontalKey = Key('horizontal-mirror');
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => Container(
            key: horizontalKey,
            width: 20,
            height: 20,
            color: Colors.purple,
          ),
          attachPoint: AttachPoint.topLeft,
          axisMirrors: const AxisMirrors(horizontal: true),
        );

        await tester.pump();

        positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byKey(horizontalKey),
            matching: find.byType(Positioned),
          ),
        );

        // Horizontal mirror: uses left instead of right
        expect(positioned.left, equals(50.0));
        expect(positioned.right, isNull);
        expect(positioned.top, isNull); // Still uses bottom for vertical

        manager.hideOverlays(context: tester.element(find.byType(Scaffold)), keys: [key]);
        await tester.pumpAndSettle();

        // Test both mirrors - uses top and left
        const bothKey = Key('both-mirrors');
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => Container(
            key: bothKey,
            width: 20,
            height: 20,
            color: Colors.orange,
          ),
          attachPoint: AttachPoint.topLeft,
          axisMirrors: const AxisMirrors(vertical: true, horizontal: true),
        );

        await tester.pump();

        positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byKey(bothKey),
            matching: find.byType(Positioned),
          ),
        );

        // Both mirrors: uses top and left
        expect(positioned.top, equals(100.0));
        expect(positioned.left, equals(50.0));
        expect(positioned.bottom, isNull);
        expect(positioned.right, isNull);

        manager.hideOverlays(context: tester.element(find.byType(Scaffold)), keys: [key]);
        await tester.pumpAndSettle();
      });

      testWidgets('should replace existing overlay for same key', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                key: key,
                width: 100,
                height: 50,
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => const Text('First'),
          attachPoint: AttachPoint.center,
        );

        await tester.pump();
        expect(find.text('First'), findsOneWidget);

        // Insert another overlay with the same key
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => const Text('Second'),
          attachPoint: AttachPoint.center,
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300)); // Wait for fade

        expect(find.text('Second'), findsOneWidget);
      });

      testWidgets('should not insert overlay for unregistered key', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                key: key,
                width: 100,
                height: 50,
              ),
            ),
          ),
        );

        // Don't register the target
        bool builderCalled = false;
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) {
            builderCalled = true;
            return Container();
          },
          attachPoint: AttachPoint.center,
        );

        await tester.pump();
        expect(builderCalled, isFalse);
      });

      testWidgets('should call remove callback when overlay is removed', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: key,
                  width: 100,
                  height: 50,
                ),
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        VoidCallback? removeCallback;
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) {
            removeCallback = remove;
            return const SizedBox(
              width: 50,
              height: 50,
              child: Text('Overlay'),
            );
          },
          attachPoint: AttachPoint.center,
        );

        await tester.pump();
        expect(find.text('Overlay'), findsOneWidget);

        // Call remove callback
        removeCallback!();
        await tester.pumpAndSettle();

        // The overlay should be removed
        expect(find.text('Overlay'), findsNothing);
      });
    });

    group('hideOverlays', () {
      testWidgets('should hide single overlay', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                key: key,
                width: 100,
                height: 50,
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => const Text('Hide Me'),
          attachPoint: AttachPoint.center,
        );

        await tester.pump();
        expect(find.text('Hide Me'), findsOneWidget);

        manager.hideOverlays(
          context: tester.element(find.byType(Scaffold)),
          keys: [key],
        );

        await tester.pumpAndSettle();

        expect(find.text('Hide Me'), findsNothing);
      });

      testWidgets('should hide multiple overlays', (WidgetTester tester) async {
        final key1 = GlobalKey();
        final key2 = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(key: key1, width: 100, height: 50),
                  SizedBox(key: key2, width: 100, height: 50),
                ],
              ),
            ),
          ),
        );

        manager.registerTargets([key1, key2]);

        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key1,
          builder: (remove) => const Text('Overlay 1'),
          attachPoint: AttachPoint.center,
        );

        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key2,
          builder: (remove) => const Text('Overlay 2'),
          attachPoint: AttachPoint.center,
        );

        await tester.pump();
        expect(find.text('Overlay 1'), findsOneWidget);
        expect(find.text('Overlay 2'), findsOneWidget);

        manager.hideOverlays(
          context: tester.element(find.byType(Scaffold)),
          keys: [key1, key2],
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Overlay 1'), findsNothing);
        expect(find.text('Overlay 2'), findsNothing);
      });

      testWidgets('should keep target registered after hiding', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                key: key,
                width: 100,
                height: 50,
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => const Text('First Show'),
          attachPoint: AttachPoint.center,
        );

        await tester.pump();

        manager.hideOverlays(
          context: tester.element(find.byType(Scaffold)),
          keys: [key],
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Should be able to show again without re-registering
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => const Text('Second Show'),
          attachPoint: AttachPoint.center,
        );

        await tester.pump();
        expect(find.text('Second Show'), findsOneWidget);
      });
    });

    group('clearOverlays', () {
      testWidgets('should clear single overlay', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                key: key,
                width: 100,
                height: 50,
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => const Text('Clear Me'),
          attachPoint: AttachPoint.center,
        );

        await tester.pump();
        expect(find.text('Clear Me'), findsOneWidget);

        manager.clearOverlays(
          context: tester.element(find.byType(Scaffold)),
          keys: [key],
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Clear Me'), findsNothing);
      });

      testWidgets('should remove target registration after clearing', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                key: key,
                width: 100,
                height: 50,
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => const Text('Will Clear'),
          attachPoint: AttachPoint.center,
        );

        await tester.pump();

        manager.clearOverlays(
          context: tester.element(find.byType(Scaffold)),
          keys: [key],
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Try to insert overlay - should fail since target is cleared
        bool builderCalled = false;
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) {
            builderCalled = true;
            return Container();
          },
          attachPoint: AttachPoint.center,
        );

        await tester.pump();
        expect(builderCalled, isFalse);
      });

      testWidgets('should clear multiple overlays', (WidgetTester tester) async {
        final key1 = GlobalKey();
        final key2 = GlobalKey();
        final key3 = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(key: key1, width: 100, height: 50),
                  SizedBox(key: key2, width: 100, height: 50),
                  SizedBox(key: key3, width: 100, height: 50),
                ],
              ),
            ),
          ),
        );

        manager.registerTargets([key1, key2, key3]);

        for (var i = 0; i < 3; i++) {
          final key = [key1, key2, key3][i];
          manager.insertOverlay(
            context: tester.element(find.byType(Scaffold)),
            key: key,
            builder: (remove) => Text('Overlay $i'),
            attachPoint: AttachPoint.center,
          );
        }

        await tester.pump();

        manager.clearOverlays(
          context: tester.element(find.byType(Scaffold)),
          keys: [key1, key2, key3],
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Overlay 0'), findsNothing);
        expect(find.text('Overlay 1'), findsNothing);
        expect(find.text('Overlay 2'), findsNothing);
      });
    });

    group('updateTargets', () {
      testWidgets('should update target positions', (WidgetTester tester) async {
        final key = GlobalKey();

        // First layout: widget at y=100
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const SizedBox(height: 100),
                  SizedBox(
                    key: key,
                    width: 100,
                    height: 50,
                  ),
                ],
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        const firstOverlayKey = Key('first-overlay');
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => Container(
            key: firstOverlayKey,
            width: 20,
            height: 20,
            color: Colors.blue,
          ),
          attachPoint: AttachPoint.topLeft,
        );

        await tester.pump();

        final screenSize =
            tester.binding.platformDispatcher.views.first.physicalSize /
            tester.binding.platformDispatcher.views.first.devicePixelRatio;

        // Get initial position - target at y=100
        var positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byKey(firstOverlayKey),
            matching: find.byType(Positioned),
          ),
        );

        final initialBottom = positioned.bottom!;
        // Initial: screenHeight - 100 (target Y position)
        expect(initialBottom, equals(screenSize.height - 100.0));

        // Change layout - remove the spacer so widget moves to y=0
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    key: key,
                    width: 100,
                    height: 50,
                  ),
                ],
              ),
            ),
          ),
        );

        manager.updateTargets(context: tester.element(find.byType(Scaffold)));

        // Re-insert overlay to verify new position
        manager.hideOverlays(context: tester.element(find.byType(Scaffold)), keys: [key]);
        await tester.pumpAndSettle();

        const newOverlayKey = Key('new-overlay');
        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => Container(
            key: newOverlayKey,
            width: 20,
            height: 20,
            color: Colors.green,
          ),
          attachPoint: AttachPoint.topLeft,
        );

        await tester.pump();

        // Get new position - target should now be at y=0
        positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byKey(newOverlayKey),
            matching: find.byType(Positioned),
          ),
        );

        final newBottom = positioned.bottom!;
        // New: screenHeight - 0 (target moved to top)
        expect(newBottom, equals(screenSize.height));

        // Verify the position actually changed
        expect(newBottom, isNot(equals(initialBottom)));
      });

      testWidgets('should handle updating non-existent targets gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(),
            ),
          ),
        );

        // Should not throw even with no registered targets
        expect(
          () => manager.updateTargets(context: tester.element(find.byType(Scaffold))),
          returnsNormally,
        );
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle rapid overlay insertions', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                key: key,
                width: 100,
                height: 50,
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        // Insert multiple overlays rapidly
        for (var i = 0; i < 5; i++) {
          manager.insertOverlay(
            context: tester.element(find.byType(Scaffold)),
            key: key,
            builder: (remove) => Text('Overlay $i'),
            attachPoint: AttachPoint.center,
          );
        }

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Should only show the last overlay
        expect(find.text('Overlay 4'), findsOneWidget);
      });

      testWidgets('should handle overlay with zero fade duration', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                key: key,
                width: 100,
                height: 50,
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        manager.insertOverlay(
          context: tester.element(find.byType(Scaffold)),
          key: key,
          builder: (remove) => const Text('No Fade'),
          attachPoint: AttachPoint.center,
          fadeDuration: Duration.zero,
        );

        await tester.pump();
        expect(find.text('No Fade'), findsOneWidget);

        manager.hideOverlays(context: tester.element(find.byType(Scaffold)), keys: [key]);
        await tester.pumpAndSettle();

        expect(find.text('No Fade'), findsNothing);
      });

      testWidgets('should handle clearing already cleared overlays', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                key: key,
                width: 100,
                height: 50,
              ),
            ),
          ),
        );

        manager.registerTargets([key]);
        manager.clearOverlays(context: tester.element(find.byType(Scaffold)), keys: [key]);

        // Clear again - should not throw
        expect(
          () => manager.clearOverlays(context: tester.element(find.byType(Scaffold)), keys: [key]),
          returnsNormally,
        );
      });

      testWidgets('should handle hiding non-existent overlays', (WidgetTester tester) async {
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                key: key,
                width: 100,
                height: 50,
              ),
            ),
          ),
        );

        manager.registerTargets([key]);

        // Hide without inserting - should not throw
        expect(
          () => manager.hideOverlays(context: tester.element(find.byType(Scaffold)), keys: [key]),
          returnsNormally,
        );
      });
    });
  });
}
