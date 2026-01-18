import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  const exporter = DslExporter();

  group('Version Header', () {
    test('exports version header', () {
      final doc = _createSimpleDoc();
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, startsWith('dsl:1\n'));
    });
  });

  group('Frame Declaration', () {
    test('exports simple frame name', () {
      final doc = _createDocWithFrame('HomePage');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('frame HomePage'));
    });

    test('quotes frame name with spaces', () {
      final doc = _createDocWithFrame('Login Screen');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('frame "Login Screen"'));
    });

    test('quotes empty frame name', () {
      final doc = _createDocWithFrame('');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('frame ""'));
    });

    test('exports custom dimensions', () {
      final doc = _createDocWithDimensions(1920, 1080);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('w 1920'));
      expect(dsl, contains('h 1080'));
    });

    test('omits default dimensions', () {
      final doc = _createDocWithDimensions(375, 812);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('w 375')));
      expect(dsl, isNot(contains('h 812')));
    });
  });

  group('Node Type Export', () {
    test('exports horizontal container as row', () {
      final doc = _createDocWithAutoLayout(LayoutDirection.horizontal);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('row#'));
    });

    test('exports vertical container as column', () {
      final doc = _createDocWithAutoLayout(LayoutDirection.vertical);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('column#'));
    });

    test('exports container without autoLayout as container', () {
      final doc = _createSimpleDoc();
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('container#'));
    });

    test('exports text with content', () {
      final doc = _createDocWithText('Hello World');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('text#'));
      expect(dsl, contains('"Hello World"'));
    });

    test('exports image as img', () {
      final doc = _createDocWithImage('https://example.com/img.png');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('img#'));
    });

    test('exports instance as use', () {
      final doc = _createDocWithInstance('ButtonPrimary');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('use#'));
      expect(dsl, contains('"ButtonPrimary"'));
    });

    test('exports icon node', () {
      final doc = _createDocWithIcon('home');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('icon#'));
      expect(dsl, contains('"home"'));
    });

    test('exports spacer node', () {
      final doc = _createDocWithSpacer(2);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('spacer#'));
      expect(dsl, contains('flex 2'));
    });
  });

  group('Layout Property Export', () {
    test('exports fixed width', () {
      final doc = _createDocWithSize(const AxisSizeFixed(200), const AxisSizeHug());
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('w 200'));
    });

    test('exports fill width', () {
      final doc = _createDocWithSize(const AxisSizeFill(), const AxisSizeHug());
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('w fill'));
    });

    test('omits hug width (default)', () {
      final doc = _createDocWithSize(const AxisSizeHug(), const AxisSizeHug());
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('w hug')));
    });

    test('exports fixed height', () {
      final doc = _createDocWithSize(const AxisSizeHug(), const AxisSizeFixed(100));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('h 100'));
    });

    test('exports fill height', () {
      final doc = _createDocWithSize(const AxisSizeHug(), const AxisSizeFill());
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('h fill'));
    });

    test('exports absolute position', () {
      final doc = _createDocWithAbsolutePosition(10, 20);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('pos abs'));
      expect(dsl, contains('x 10'));
      expect(dsl, contains('y 20'));
    });

    test('exports gap with fixed value', () {
      final doc = _createDocWithGap(const FixedNumeric(16));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('gap 16'));
    });

    test('exports gap with token reference', () {
      final doc = _createDocWithGap(const TokenNumeric('spacing.md'));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('gap {spacing.md}'));
    });

    test('exports uniform padding', () {
      final doc = _createDocWithPadding(TokenEdgePadding.all(const FixedNumeric(16)));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('pad 16'));
    });

    test('exports symmetric padding', () {
      final doc = _createDocWithPadding(const TokenEdgePadding(
        top: FixedNumeric(8),
        right: FixedNumeric(16),
        bottom: FixedNumeric(8),
        left: FixedNumeric(16),
      ));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('pad 8,16'));
    });

    test('exports per-side padding', () {
      final doc = _createDocWithPadding(const TokenEdgePadding(
        top: FixedNumeric(1),
        right: FixedNumeric(2),
        bottom: FixedNumeric(3),
        left: FixedNumeric(4),
      ));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('pad 1,2,3,4'));
    });

    test('exports alignment when non-default', () {
      final doc = _createDocWithAlignment(MainAxisAlignment.center, CrossAxisAlignment.center);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('align center,center'));
    });

    test('omits default alignment', () {
      final doc = _createDocWithAlignment(MainAxisAlignment.start, CrossAxisAlignment.start);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('align')));
    });
  });

  group('Style Property Export', () {
    test('exports hex background', () {
      final doc = _createDocWithFill(SolidFill(const HexColor('#FF5500')));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('bg #FF5500'));
    });

    test('exports token background', () {
      final doc = _createDocWithFill(const TokenFill('color.primary'));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('bg {color.primary}'));
    });

    test('exports uniform radius', () {
      final doc = _createDocWithRadius(CornerRadius.circular(8));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('r 8'));
    });

    test('exports per-corner radius', () {
      final doc = _createDocWithRadius(const CornerRadius(
        topLeft: FixedNumeric(8),
        topRight: FixedNumeric(8),
        bottomRight: FixedNumeric(0),
        bottomLeft: FixedNumeric(0),
      ));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('r 8,8,0,0'));
    });

    test('exports radius with token', () {
      final doc = _createDocWithRadius(CornerRadius.all(const TokenNumeric('radius.md')));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('r {radius.md}'));
    });

    test('omits zero radius', () {
      final doc = _createDocWithRadius(CornerRadius.circular(0));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('r 0')));
    });

    test('exports border', () {
      final doc = _createDocWithStroke(Stroke(color: const HexColor('#CCCCCC'), width: 1));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('border 1 #CCCCCC'));
    });

    test('exports border with token color', () {
      final doc = _createDocWithStroke(Stroke(color: const TokenColor('color.border'), width: 2));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('border 2 {color.border}'));
    });

    test('exports opacity when less than 1', () {
      final doc = _createDocWithOpacity(0.5);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('opacity 0.5'));
    });

    test('omits default opacity', () {
      final doc = _createDocWithOpacity(1.0);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('opacity')));
    });

    test('exports visible false', () {
      final doc = _createDocWithVisibility(false);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('visible false'));
    });

    test('omits visible true (default)', () {
      final doc = _createDocWithVisibility(true);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('visible')));
    });
  });

  group('Text Property Export', () {
    test('exports non-default font size', () {
      final doc = _createDocWithTextProps(fontSize: 24);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('size 24'));
    });

    test('omits default font size', () {
      final doc = _createDocWithTextProps(fontSize: 14);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('size 14')));
    });

    test('exports non-default font weight', () {
      final doc = _createDocWithTextProps(fontWeight: 700);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('weight 700'));
    });

    test('omits default font weight', () {
      final doc = _createDocWithTextProps(fontWeight: 400);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('weight 400')));
    });

    test('exports text color', () {
      final doc = _createDocWithTextProps(color: '#333333');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('color #333333'));
    });

    test('exports non-default text align', () {
      final doc = _createDocWithTextProps(textAlign: TextAlign.center);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('textAlign center'));
    });

    test('omits default text align', () {
      final doc = _createDocWithTextProps(textAlign: TextAlign.left);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('textAlign')));
    });

    test('exports font family', () {
      final doc = _createDocWithTextProps(fontFamily: 'Inter');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('family "Inter"'));
    });
  });

  group('Icon Property Export', () {
    test('exports non-default icon set', () {
      final doc = _createDocWithIconProps(iconSet: 'lucide');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('iconSet lucide'));
    });

    test('omits default icon set', () {
      final doc = _createDocWithIconProps(iconSet: 'material');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('iconSet')));
    });

    test('exports non-default icon size', () {
      final doc = _createDocWithIconProps(size: 32);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('size 32'));
    });

    test('omits default icon size', () {
      final doc = _createDocWithIconProps(size: 24);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('size 24')));
    });

    test('exports icon color', () {
      final doc = _createDocWithIconProps(color: '#666666');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('color #666666'));
    });
  });

  group('Image Property Export', () {
    test('exports non-default image fit', () {
      final doc = _createDocWithImageProps(fit: ImageFit.contain);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('fit contain'));
    });

    test('omits default image fit', () {
      final doc = _createDocWithImageProps(fit: ImageFit.cover);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('fit')));
    });

    test('exports alt text', () {
      final doc = _createDocWithImageProps(alt: 'Profile picture');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('alt "Profile picture"'));
    });
  });

  group('Container Property Export', () {
    test('exports clip', () {
      final doc = _createDocWithContainerProps(clipContent: true);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('clip'));
    });

    test('omits clip when false', () {
      final doc = _createDocWithContainerProps(clipContent: false);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('clip')));
    });

    test('exports scroll direction', () {
      final doc = _createDocWithContainerProps(scrollDirection: 'vertical');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('scroll vertical'));
    });
  });

  group('Spacer Property Export', () {
    test('exports non-default flex', () {
      final doc = _createDocWithSpacer(2);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('flex 2'));
    });

    test('omits default flex', () {
      final doc = _createDocWithSpacer(1);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('flex')));
    });
  });

  group('Number Formatting', () {
    test('formats integers without decimal', () {
      final doc = _createDocWithSize(const AxisSizeFixed(100), const AxisSizeHug());
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('w 100'));
      expect(dsl, isNot(contains('w 100.0')));
    });

    test('preserves decimal when needed', () {
      final doc = _createDocWithSize(const AxisSizeFixed(100.5), const AxisSizeHug());
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('w 100.5'));
    });
  });

  group('ID Export', () {
    test('includes IDs by default', () {
      final doc = _createSimpleDoc();
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('#root'));
    });

    test('excludes IDs when disabled', () {
      final doc = _createSimpleDoc();
      final dsl = exporter.exportFrame(doc, 'frame1', includeIds: false);
      expect(dsl, isNot(contains('#root')));
    });
  });

  group('Hierarchy Export', () {
    test('exports children with proper indentation', () {
      final doc = _createDocWithChildren();
      final dsl = exporter.exportFrame(doc, 'frame1');
      final lines = dsl.split('\n');
      // Root at indent 2
      expect(lines.any((l) => l.startsWith('  column#root')), isTrue);
      // Children at indent 4
      expect(lines.any((l) => l.startsWith('    text#child')), isTrue);
    });

    test('exports multiple children in order', () {
      final doc = _createDocWithMultipleChildren();
      final dsl = exporter.exportFrame(doc, 'frame1');
      final child1Index = dsl.indexOf('child1');
      final child2Index = dsl.indexOf('child2');
      expect(child1Index, lessThan(child2Index));
    });
  });

  group('Export Methods', () {
    test('exportFrame throws on missing frame', () {
      final doc = EditorDocument(documentId: 'test', frames: {}, nodes: {});
      expect(
        () => exporter.exportFrame(doc, 'nonexistent'),
        throwsA(isA<DslExportException>()),
      );
    });

    test('exportFrames exports multiple frames', () {
      final doc = _createMultiFrameDoc();
      final dsl = exporter.exportFrames(doc, ['frame1', 'frame2']);
      expect(dsl, contains('frame Frame1'));
      expect(dsl, contains('frame Frame2'));
    });

    test('exportDocument exports all frames', () {
      final doc = _createMultiFrameDoc();
      final dsl = exporter.exportDocument(doc);
      expect(dsl, contains('frame Frame1'));
      expect(dsl, contains('frame Frame2'));
    });
  });
}

// ============================================================================
// Test Helpers - Document Builders
// ============================================================================

EditorDocument _createSimpleDoc() {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
      ),
    },
  );
}

EditorDocument _createDocWithFrame(String name) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: name,
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
      ),
    },
  );
}

EditorDocument _createDocWithDimensions(double w, double h) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: CanvasPlacement(position: Offset.zero, size: Size(w, h)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
      ),
    },
  );
}

EditorDocument _createDocWithAutoLayout(LayoutDirection direction) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          autoLayout: AutoLayout(direction: direction),
        ),
      ),
    },
  );
}

EditorDocument _createDocWithText(String text) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.text,
        props: TextProps(text: text),
      ),
    },
  );
}

EditorDocument _createDocWithImage(String src) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.image,
        props: ImageProps(src: src),
      ),
    },
  );
}

EditorDocument _createDocWithInstance(String componentId) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.instance,
        props: InstanceProps(componentId: componentId),
      ),
    },
  );
}

EditorDocument _createDocWithIcon(String icon) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.icon,
        props: IconProps(icon: icon),
      ),
    },
  );
}

EditorDocument _createDocWithSpacer(int flex) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.spacer,
        props: SpacerProps(flex: flex),
      ),
    },
  );
}

EditorDocument _createDocWithSize(AxisSize width, AxisSize height) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          size: SizeMode(width: width, height: height),
        ),
      ),
    },
  );
}

EditorDocument _createDocWithAbsolutePosition(double x, double y) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          position: PositionModeAbsolute(x: x, y: y),
        ),
      ),
    },
  );
}

EditorDocument _createDocWithGap(NumericValue gap) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          autoLayout: AutoLayout(
            direction: LayoutDirection.vertical,
            gap: gap,
          ),
        ),
      ),
    },
  );
}

EditorDocument _createDocWithPadding(TokenEdgePadding padding) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          autoLayout: AutoLayout(
            direction: LayoutDirection.vertical,
            padding: padding,
          ),
        ),
      ),
    },
  );
}

EditorDocument _createDocWithAlignment(MainAxisAlignment main, CrossAxisAlignment cross) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          autoLayout: AutoLayout(
            direction: LayoutDirection.horizontal,
            mainAlign: main,
            crossAlign: cross,
          ),
        ),
      ),
    },
  );
}

EditorDocument _createDocWithFill(Fill fill) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        style: NodeStyle(fill: fill),
      ),
    },
  );
}

EditorDocument _createDocWithRadius(CornerRadius radius) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        style: NodeStyle(cornerRadius: radius),
      ),
    },
  );
}

EditorDocument _createDocWithStroke(Stroke stroke) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        style: NodeStyle(stroke: stroke),
      ),
    },
  );
}

EditorDocument _createDocWithOpacity(double opacity) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        style: NodeStyle(opacity: opacity),
      ),
    },
  );
}

EditorDocument _createDocWithVisibility(bool visible) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        style: NodeStyle(visible: visible),
      ),
    },
  );
}

EditorDocument _createDocWithTextProps({
  double fontSize = 14,
  int fontWeight = 400,
  String? color,
  TextAlign textAlign = TextAlign.left,
  String? fontFamily,
}) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.text,
        props: TextProps(
          text: 'Hello',
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          textAlign: textAlign,
          fontFamily: fontFamily,
        ),
      ),
    },
  );
}

EditorDocument _createDocWithIconProps({
  String iconSet = 'material',
  double size = 24,
  String? color,
}) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.icon,
        props: IconProps(
          icon: 'home',
          iconSet: iconSet,
          size: size,
          color: color,
        ),
      ),
    },
  );
}

EditorDocument _createDocWithImageProps({
  ImageFit fit = ImageFit.cover,
  String? alt,
}) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.image,
        props: ImageProps(
          src: 'https://example.com/img.png',
          fit: fit,
          alt: alt,
        ),
      ),
    },
  );
}

EditorDocument _createDocWithContainerProps({
  bool clipContent = false,
  String? scrollDirection,
}) {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(
          clipContent: clipContent,
          scrollDirection: scrollDirection,
        ),
      ),
    },
  );
}

EditorDocument _createDocWithChildren() {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          autoLayout: const AutoLayout(direction: LayoutDirection.vertical),
        ),
        childIds: ['child'],
      ),
      'child': Node(
        id: 'child',
        type: NodeType.text,
        props: const TextProps(text: 'Hello'),
      ),
    },
  );
}

EditorDocument _createDocWithMultipleChildren() {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          autoLayout: const AutoLayout(direction: LayoutDirection.vertical),
        ),
        childIds: ['child1', 'child2'],
      ),
      'child1': Node(
        id: 'child1',
        type: NodeType.text,
        props: const TextProps(text: 'First'),
      ),
      'child2': Node(
        id: 'child2',
        type: NodeType.text,
        props: const TextProps(text: 'Second'),
      ),
    },
  );
}

EditorDocument _createMultiFrameDoc() {
  return EditorDocument(
    documentId: 'test',
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Frame1',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      'frame2': Frame(
        id: 'frame2',
        name: 'Frame2',
        canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
        rootNodeId: 'root2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    },
    nodes: {
      'root1': Node(
        id: 'root1',
        type: NodeType.container,
        props: ContainerProps(),
      ),
      'root2': Node(
        id: 'root2',
        type: NodeType.container,
        props: ContainerProps(),
      ),
    },
  );
}
