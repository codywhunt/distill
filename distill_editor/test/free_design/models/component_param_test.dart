import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('ParamType', () {
    test('all types serialize correctly', () {
      for (final type in ParamType.values) {
        final json = type.toJson();
        final restored = ParamType.fromJson(json);
        expect(restored, type);
      }
    });

    test('fromJson returns string for unknown value', () {
      final restored = ParamType.fromJson('unknownType');
      expect(restored, ParamType.string);
    });
  });

  group('OverrideBucket', () {
    test('all buckets serialize correctly', () {
      for (final bucket in OverrideBucket.values) {
        final json = bucket.toJson();
        final restored = OverrideBucket.fromJson(json);
        expect(restored, bucket);
      }
    });

    test('fromJson returns props for unknown value', () {
      final restored = OverrideBucket.fromJson('unknownBucket');
      expect(restored, OverrideBucket.props);
    });
  });

  group('ParamField', () {
    test('all fields serialize correctly', () {
      for (final field in ParamField.values) {
        final json = field.toJson();
        final restored = ParamField.fromJson(json);
        expect(restored, field);
      }
    });

    test('fromJson returns text for unknown value', () {
      final restored = ParamField.fromJson('unknownField');
      expect(restored, ParamField.text);
    });
  });

  group('ParamBinding', () {
    test('creates with required fields', () {
      const binding = ParamBinding(
        targetTemplateUid: 'tpl_button_label',
        bucket: OverrideBucket.props,
        field: ParamField.text,
      );

      expect(binding.targetTemplateUid, 'tpl_button_label');
      expect(binding.bucket, OverrideBucket.props);
      expect(binding.field, ParamField.text);
    });

    test('JSON round-trip preserves data', () {
      const binding = ParamBinding(
        targetTemplateUid: 'tpl_icon',
        bucket: OverrideBucket.style,
        field: ParamField.fillColor,
      );

      final json = binding.toJson();
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = ParamBinding.fromJson(decoded);

      expect(restored.targetTemplateUid, binding.targetTemplateUid);
      expect(restored.bucket, binding.bucket);
      expect(restored.field, binding.field);
    });

    test('equality works correctly', () {
      const binding1 = ParamBinding(
        targetTemplateUid: 'tpl_text',
        bucket: OverrideBucket.props,
        field: ParamField.text,
      );

      const binding2 = ParamBinding(
        targetTemplateUid: 'tpl_text',
        bucket: OverrideBucket.props,
        field: ParamField.text,
      );

      const binding3 = ParamBinding(
        targetTemplateUid: 'tpl_other',
        bucket: OverrideBucket.props,
        field: ParamField.text,
      );

      expect(binding1, equals(binding2));
      expect(binding1, isNot(equals(binding3)));
      expect(binding1.hashCode, binding2.hashCode);
    });
  });

  group('ComponentParamDef', () {
    test('creates with required fields', () {
      const param = ComponentParamDef(
        key: 'label',
        type: ParamType.string,
        defaultValue: 'Button',
        binding: ParamBinding(
          targetTemplateUid: 'tpl_label',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      );

      expect(param.key, 'label');
      expect(param.type, ParamType.string);
      expect(param.defaultValue, 'Button');
      expect(param.group, isNull);
      expect(param.enumOptions, isNull);
    });

    test('creates with all optional fields', () {
      const param = ComponentParamDef(
        key: 'variant',
        type: ParamType.enumValue,
        defaultValue: 'primary',
        group: 'Style',
        binding: ParamBinding(
          targetTemplateUid: 'tpl_container',
          bucket: OverrideBucket.style,
          field: ParamField.fillColor,
        ),
        enumOptions: ['primary', 'secondary', 'outline'],
      );

      expect(param.group, 'Style');
      expect(param.enumOptions, ['primary', 'secondary', 'outline']);
    });

    test('JSON round-trip preserves data for string param', () {
      const param = ComponentParamDef(
        key: 'label',
        type: ParamType.string,
        defaultValue: 'Click Me',
        group: 'Content',
        binding: ParamBinding(
          targetTemplateUid: 'tpl_text',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      );

      final json = param.toJson();
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = ComponentParamDef.fromJson(decoded);

      expect(restored.key, param.key);
      expect(restored.type, param.type);
      expect(restored.defaultValue, param.defaultValue);
      expect(restored.group, param.group);
      expect(restored.binding.targetTemplateUid, 'tpl_text');
    });

    test('JSON round-trip preserves data for number param', () {
      const param = ComponentParamDef(
        key: 'size',
        type: ParamType.number,
        defaultValue: 24.0,
        binding: ParamBinding(
          targetTemplateUid: 'tpl_icon',
          bucket: OverrideBucket.layout,
          field: ParamField.width,
        ),
      );

      final json = param.toJson();
      final restored = ComponentParamDef.fromJson(json);

      expect(restored.type, ParamType.number);
      expect(restored.defaultValue, 24.0);
    });

    test('JSON round-trip preserves data for boolean param', () {
      const param = ComponentParamDef(
        key: 'disabled',
        type: ParamType.boolean,
        defaultValue: false,
        binding: ParamBinding(
          targetTemplateUid: 'tpl_button',
          bucket: OverrideBucket.style,
          field: ParamField.opacity,
        ),
      );

      final json = param.toJson();
      final restored = ComponentParamDef.fromJson(json);

      expect(restored.type, ParamType.boolean);
      expect(restored.defaultValue, false);
    });

    test('JSON round-trip preserves data for color param', () {
      const param = ComponentParamDef(
        key: 'backgroundColor',
        type: ParamType.color,
        defaultValue: '#007AFF',
        binding: ParamBinding(
          targetTemplateUid: 'tpl_container',
          bucket: OverrideBucket.style,
          field: ParamField.fillColor,
        ),
      );

      final json = param.toJson();
      final restored = ComponentParamDef.fromJson(json);

      expect(restored.type, ParamType.color);
      expect(restored.defaultValue, '#007AFF');
    });

    test('JSON round-trip preserves data for enum param', () {
      const param = ComponentParamDef(
        key: 'variant',
        type: ParamType.enumValue,
        defaultValue: 'primary',
        enumOptions: ['primary', 'secondary', 'ghost'],
        binding: ParamBinding(
          targetTemplateUid: 'tpl_button',
          bucket: OverrideBucket.style,
          field: ParamField.fillColor,
        ),
      );

      final json = param.toJson();
      final restored = ComponentParamDef.fromJson(json);

      expect(restored.type, ParamType.enumValue);
      expect(restored.defaultValue, 'primary');
      expect(restored.enumOptions, ['primary', 'secondary', 'ghost']);
    });

    test('copyWith creates modified copy', () {
      const original = ComponentParamDef(
        key: 'label',
        type: ParamType.string,
        defaultValue: 'Original',
        binding: ParamBinding(
          targetTemplateUid: 'tpl_text',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      );

      final modified = original.copyWith(defaultValue: 'Modified');

      expect(modified.defaultValue, 'Modified');
      expect(modified.key, original.key);
      expect(original.defaultValue, 'Original'); // Original unchanged
    });

    test('equality works correctly', () {
      const param1 = ComponentParamDef(
        key: 'label',
        type: ParamType.string,
        defaultValue: 'Test',
        binding: ParamBinding(
          targetTemplateUid: 'tpl_text',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      );

      const param2 = ComponentParamDef(
        key: 'label',
        type: ParamType.string,
        defaultValue: 'Test',
        binding: ParamBinding(
          targetTemplateUid: 'tpl_text',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      );

      const param3 = ComponentParamDef(
        key: 'title', // Different key
        type: ParamType.string,
        defaultValue: 'Test',
        binding: ParamBinding(
          targetTemplateUid: 'tpl_text',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      );

      expect(param1, equals(param2));
      expect(param1, isNot(equals(param3)));
      expect(param1.hashCode, param2.hashCode);
    });

    test('equality handles enumOptions correctly', () {
      const param1 = ComponentParamDef(
        key: 'variant',
        type: ParamType.enumValue,
        defaultValue: 'a',
        enumOptions: ['a', 'b', 'c'],
        binding: ParamBinding(
          targetTemplateUid: 'tpl',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      );

      const param2 = ComponentParamDef(
        key: 'variant',
        type: ParamType.enumValue,
        defaultValue: 'a',
        enumOptions: ['a', 'b', 'c'],
        binding: ParamBinding(
          targetTemplateUid: 'tpl',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      );

      const param3 = ComponentParamDef(
        key: 'variant',
        type: ParamType.enumValue,
        defaultValue: 'a',
        enumOptions: ['a', 'b'], // Different options
        binding: ParamBinding(
          targetTemplateUid: 'tpl',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      );

      expect(param1, equals(param2));
      expect(param1, isNot(equals(param3)));
    });

    test('JSON omits null optional fields', () {
      const param = ComponentParamDef(
        key: 'label',
        type: ParamType.string,
        defaultValue: 'Test',
        binding: ParamBinding(
          targetTemplateUid: 'tpl_text',
          bucket: OverrideBucket.props,
          field: ParamField.text,
        ),
      );

      final json = param.toJson();

      expect(json.containsKey('group'), false);
      expect(json.containsKey('enumOptions'), false);
    });
  });

  group('ParamTarget typedef', () {
    test('can be used as map key', () {
      final map = <ParamTarget, dynamic>{};

      const target1 = (bucket: OverrideBucket.props, field: ParamField.text);
      const target2 = (bucket: OverrideBucket.style, field: ParamField.fillColor);

      map[target1] = 'Hello';
      map[target2] = '#FF0000';

      expect(map[target1], 'Hello');
      expect(map[target2], '#FF0000');
      expect(map.length, 2);
    });

    test('same bucket and field equal each other', () {
      const target1 = (bucket: OverrideBucket.props, field: ParamField.text);
      const target2 = (bucket: OverrideBucket.props, field: ParamField.text);

      expect(target1, equals(target2));
    });
  });
}
