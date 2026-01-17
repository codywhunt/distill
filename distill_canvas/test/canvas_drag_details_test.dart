import 'dart:ui';

import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasDragStartDetails', () {
    test('stores all properties', () {
      const details = CanvasDragStartDetails(
        worldPosition: Offset(100, 200),
        viewPosition: Offset(50, 100),
        kind: PointerDeviceKind.touch,
      );

      expect(details.worldPosition, equals(const Offset(100, 200)));
      expect(details.viewPosition, equals(const Offset(50, 100)));
      expect(details.kind, equals(PointerDeviceKind.touch));
    });

    test('kind is optional', () {
      const details = CanvasDragStartDetails(
        worldPosition: Offset(100, 200),
        viewPosition: Offset(50, 100),
      );

      expect(details.kind, isNull);
    });

    test('works with mouse kind', () {
      const details = CanvasDragStartDetails(
        worldPosition: Offset.zero,
        viewPosition: Offset.zero,
        kind: PointerDeviceKind.mouse,
      );

      expect(details.kind, equals(PointerDeviceKind.mouse));
    });

    test('works with stylus kind', () {
      const details = CanvasDragStartDetails(
        worldPosition: Offset.zero,
        viewPosition: Offset.zero,
        kind: PointerDeviceKind.stylus,
      );

      expect(details.kind, equals(PointerDeviceKind.stylus));
    });

    test('toString formats correctly', () {
      const details = CanvasDragStartDetails(
        worldPosition: Offset(100, 200),
        viewPosition: Offset(50, 100),
      );

      expect(details.toString(), contains('CanvasDragStartDetails'));
      expect(details.toString(), contains('world'));
      expect(details.toString(), contains('view'));
    });

    test('handles negative coordinates', () {
      const details = CanvasDragStartDetails(
        worldPosition: Offset(-100, -200),
        viewPosition: Offset(-50, -100),
      );

      expect(details.worldPosition, equals(const Offset(-100, -200)));
      expect(details.viewPosition, equals(const Offset(-50, -100)));
    });
  });

  group('CanvasDragUpdateDetails', () {
    test('stores all properties', () {
      const details = CanvasDragUpdateDetails(
        worldPosition: Offset(150, 250),
        worldDelta: Offset(10, 20),
        viewPosition: Offset(75, 125),
        viewDelta: Offset(5, 10),
      );

      expect(details.worldPosition, equals(const Offset(150, 250)));
      expect(details.worldDelta, equals(const Offset(10, 20)));
      expect(details.viewPosition, equals(const Offset(75, 125)));
      expect(details.viewDelta, equals(const Offset(5, 10)));
    });

    test('handles zero delta', () {
      const details = CanvasDragUpdateDetails(
        worldPosition: Offset(100, 200),
        worldDelta: Offset.zero,
        viewPosition: Offset(50, 100),
        viewDelta: Offset.zero,
      );

      expect(details.worldDelta, equals(Offset.zero));
      expect(details.viewDelta, equals(Offset.zero));
    });

    test('handles negative delta', () {
      const details = CanvasDragUpdateDetails(
        worldPosition: Offset(100, 200),
        worldDelta: Offset(-10, -20),
        viewPosition: Offset(50, 100),
        viewDelta: Offset(-5, -10),
      );

      expect(details.worldDelta, equals(const Offset(-10, -20)));
      expect(details.viewDelta, equals(const Offset(-5, -10)));
    });

    test('toString formats correctly', () {
      const details = CanvasDragUpdateDetails(
        worldPosition: Offset(100, 200),
        worldDelta: Offset(10, 20),
        viewPosition: Offset(50, 100),
        viewDelta: Offset(5, 10),
      );

      expect(details.toString(), contains('CanvasDragUpdateDetails'));
      expect(details.toString(), contains('world'));
      expect(details.toString(), contains('delta'));
    });

    test('delta and position are independent', () {
      const details = CanvasDragUpdateDetails(
        worldPosition: Offset(1000, 2000),
        worldDelta: Offset(1, 1),
        viewPosition: Offset(500, 1000),
        viewDelta: Offset(0.5, 0.5),
      );

      // Large position, small delta
      expect(details.worldPosition.dx, equals(1000));
      expect(details.worldDelta.dx, equals(1));
    });
  });

  group('CanvasDragEndDetails', () {
    test('stores all properties', () {
      const details = CanvasDragEndDetails(
        worldPosition: Offset(200, 300),
        viewPosition: Offset(100, 150),
        velocity: Offset(500, -200),
      );

      expect(details.worldPosition, equals(const Offset(200, 300)));
      expect(details.viewPosition, equals(const Offset(100, 150)));
      expect(details.velocity, equals(const Offset(500, -200)));
    });

    test('velocity defaults to zero', () {
      const details = CanvasDragEndDetails(
        worldPosition: Offset(200, 300),
        viewPosition: Offset(100, 150),
      );

      expect(details.velocity, equals(Offset.zero));
    });

    test('handles high velocity', () {
      const details = CanvasDragEndDetails(
        worldPosition: Offset(200, 300),
        viewPosition: Offset(100, 150),
        velocity: Offset(2000, 2000),
      );

      expect(details.velocity, equals(const Offset(2000, 2000)));
    });

    test('handles negative velocity', () {
      const details = CanvasDragEndDetails(
        worldPosition: Offset(200, 300),
        viewPosition: Offset(100, 150),
        velocity: Offset(-500, -500),
      );

      expect(details.velocity, equals(const Offset(-500, -500)));
    });

    test('toString formats correctly', () {
      const details = CanvasDragEndDetails(
        worldPosition: Offset(200, 300),
        viewPosition: Offset(100, 150),
        velocity: Offset(500, -200),
      );

      expect(details.toString(), contains('CanvasDragEndDetails'));
      expect(details.toString(), contains('world'));
      expect(details.toString(), contains('velocity'));
    });
  });
}
