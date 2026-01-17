import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ZoomLevel', () {
    test('enum has expected values', () {
      expect(ZoomLevel.values.length, equals(3));
      expect(ZoomLevel.values, contains(ZoomLevel.overview));
      expect(ZoomLevel.values, contains(ZoomLevel.normal));
      expect(ZoomLevel.values, contains(ZoomLevel.detail));
    });
  });

  group('ZoomThresholds', () {
    test('default values are reasonable', () {
      const thresholds = ZoomThresholds();

      expect(thresholds.overviewBelow, equals(0.3));
      expect(thresholds.detailAbove, equals(2.0));
      expect(thresholds.hysteresis, equals(0.05));
    });

    test('none disables all thresholds', () {
      const thresholds = ZoomThresholds.none;

      expect(thresholds.overviewBelow, equals(0));
      expect(thresholds.detailAbove, equals(double.infinity));
    });

    test('custom thresholds are preserved', () {
      const thresholds = ZoomThresholds(
        overviewBelow: 0.5,
        detailAbove: 3.0,
        hysteresis: 0.1,
      );

      expect(thresholds.overviewBelow, equals(0.5));
      expect(thresholds.detailAbove, equals(3.0));
      expect(thresholds.hysteresis, equals(0.1));
    });
  });

  group('InfiniteCanvasController zoom level', () {
    test('starts at normal level', () {
      final controller = InfiniteCanvasController();
      addTearDown(controller.dispose);

      expect(controller.currentZoomLevel, equals(ZoomLevel.normal));
    });

    test('starts at normal level even with custom initial zoom', () {
      // Initial zoom of 1.0 should be normal
      final controller = InfiniteCanvasController(initialZoom: 1.0);
      addTearDown(controller.dispose);

      expect(controller.currentZoomLevel, equals(ZoomLevel.normal));
    });

    test('zoomLevel ValueListenable provides same value', () {
      final controller = InfiniteCanvasController();
      addTearDown(controller.dispose);

      expect(controller.zoomLevel.value, equals(controller.currentZoomLevel));
    });

    group('threshold crossing', () {
      test('setZoom below overviewBelow triggers overview', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        // Default thresholds: overviewBelow = 0.3, hysteresis = 0.05
        // Must go below 0.3 - 0.05 = 0.25 to trigger overview
        controller.setZoom(0.2);

        expect(controller.currentZoomLevel, equals(ZoomLevel.overview));
      });

      test('setZoom above detailAbove triggers detail', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        // Default thresholds: detailAbove = 2.0, hysteresis = 0.05
        // Must go above 2.0 + 0.05 = 2.05 to trigger detail
        controller.setZoom(2.1);

        expect(controller.currentZoomLevel, equals(ZoomLevel.detail));
      });

      test('setZoom in middle stays normal', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        controller.setZoom(1.0);
        expect(controller.currentZoomLevel, equals(ZoomLevel.normal));

        controller.setZoom(0.5);
        expect(controller.currentZoomLevel, equals(ZoomLevel.normal));

        controller.setZoom(1.5);
        expect(controller.currentZoomLevel, equals(ZoomLevel.normal));
      });
    });

    group('hysteresis prevents flickering', () {
      test('overview to normal requires passing hysteresis band', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        // Go to overview
        controller.setZoom(0.2);
        expect(controller.currentZoomLevel, equals(ZoomLevel.overview));

        // Go to 0.3 (at threshold, but not past hysteresis)
        controller.setZoom(0.3);
        expect(controller.currentZoomLevel, equals(ZoomLevel.overview));

        // Go to 0.34 (still within hysteresis band of 0.35)
        controller.setZoom(0.34);
        expect(controller.currentZoomLevel, equals(ZoomLevel.overview));

        // Go past hysteresis band (0.3 + 0.05 = 0.35)
        controller.setZoom(0.36);
        expect(controller.currentZoomLevel, equals(ZoomLevel.normal));
      });

      test('normal to overview requires passing hysteresis band', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        // Start at normal
        expect(controller.currentZoomLevel, equals(ZoomLevel.normal));

        // Go to 0.28 (at threshold minus small amount)
        controller.setZoom(0.28);
        expect(controller.currentZoomLevel, equals(ZoomLevel.normal));

        // Go below hysteresis band (0.3 - 0.05 = 0.25)
        controller.setZoom(0.24);
        expect(controller.currentZoomLevel, equals(ZoomLevel.overview));
      });

      test('detail to normal requires passing hysteresis band', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        // Go to detail
        controller.setZoom(2.1);
        expect(controller.currentZoomLevel, equals(ZoomLevel.detail));

        // Go to 2.0 (at threshold, but not past hysteresis)
        controller.setZoom(2.0);
        expect(controller.currentZoomLevel, equals(ZoomLevel.detail));

        // Go below hysteresis band (2.0 - 0.05 = 1.95)
        controller.setZoom(1.94);
        expect(controller.currentZoomLevel, equals(ZoomLevel.normal));
      });

      test('normal to detail requires passing hysteresis band', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        // Start at normal
        expect(controller.currentZoomLevel, equals(ZoomLevel.normal));

        // Go to 2.03 (just above threshold, within hysteresis)
        controller.setZoom(2.03);
        expect(controller.currentZoomLevel, equals(ZoomLevel.normal));

        // Go above hysteresis band (2.0 + 0.05 = 2.05)
        controller.setZoom(2.06);
        expect(controller.currentZoomLevel, equals(ZoomLevel.detail));
      });
    });

    group('direct overview↔detail transitions', () {
      test('overview to detail skips hysteresis', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        // Go to overview
        controller.setZoom(0.2);
        expect(controller.currentZoomLevel, equals(ZoomLevel.overview));

        // Jump directly to detail (extreme zoom)
        controller.setZoom(5.0);
        expect(controller.currentZoomLevel, equals(ZoomLevel.detail));
      });

      test('detail to overview skips hysteresis', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        // Go to detail
        controller.setZoom(5.0);
        expect(controller.currentZoomLevel, equals(ZoomLevel.detail));

        // Jump directly to overview
        controller.setZoom(0.1);
        expect(controller.currentZoomLevel, equals(ZoomLevel.overview));
      });
    });

    group('setZoomThresholds', () {
      test('recalculates level with new thresholds', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        // Set zoom to 0.4 - normal with default thresholds
        controller.setZoom(0.4);
        expect(controller.currentZoomLevel, equals(ZoomLevel.normal));

        // Change thresholds so 0.4 is now overview
        controller.setZoomThresholds(const ZoomThresholds(overviewBelow: 0.5));
        expect(controller.currentZoomLevel, equals(ZoomLevel.overview));
      });

      test('ZoomThresholds.none keeps everything at normal', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        controller.setZoomThresholds(ZoomThresholds.none);

        // Even extreme zoom values stay at normal
        controller.setZoom(0.01);
        expect(controller.currentZoomLevel, equals(ZoomLevel.normal));

        controller.setZoom(100.0);
        expect(controller.currentZoomLevel, equals(ZoomLevel.normal));
      });
    });

    group('ValueListenable notifications', () {
      test('notifies when zoom level changes', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        var notificationCount = 0;
        ZoomLevel? lastLevel;

        controller.zoomLevel.addListener(() {
          notificationCount++;
          lastLevel = controller.zoomLevel.value;
        });

        // Change to overview
        controller.setZoom(0.2);
        expect(notificationCount, equals(1));
        expect(lastLevel, equals(ZoomLevel.overview));

        // Change to detail
        controller.setZoom(2.1);
        expect(notificationCount, equals(2));
        expect(lastLevel, equals(ZoomLevel.detail));

        // Change to normal
        controller.setZoom(1.0);
        expect(notificationCount, equals(3));
        expect(lastLevel, equals(ZoomLevel.normal));
      });

      test('does not notify when zoom changes but level stays same', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        var notificationCount = 0;
        controller.zoomLevel.addListener(() {
          notificationCount++;
        });

        // Multiple zoom changes within normal range
        controller.setZoom(0.5);
        controller.setZoom(0.8);
        controller.setZoom(1.2);
        controller.setZoom(1.8);

        expect(notificationCount, equals(0));
      });
    });
  });
}
