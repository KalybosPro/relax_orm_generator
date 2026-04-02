import 'package:test/test.dart';
import 'package:relax_orm_generator/src/type_mapper.dart';

void main() {
  group('getTypeMapping', () {
    test('maps String to text', () {
      final m = getTypeMapping('String')!;
      expect(m.columnConstructor, 'text');
      expect(m.dartCastType, 'String');
    });

    test('maps int to integer', () {
      expect(getTypeMapping('int')!.columnConstructor, 'integer');
    });

    test('maps double to real', () {
      expect(getTypeMapping('double')!.columnConstructor, 'real');
    });

    test('maps bool to boolean', () {
      expect(getTypeMapping('bool')!.columnConstructor, 'boolean');
    });

    test('maps DateTime to dateTime', () {
      expect(getTypeMapping('DateTime')!.columnConstructor, 'dateTime');
    });

    test('maps Uint8List to blob', () {
      expect(getTypeMapping('Uint8List')!.columnConstructor, 'blob');
    });

    test('handles nullable types', () {
      final m = getTypeMapping('String?');
      expect(m, isNotNull);
      expect(m!.columnConstructor, 'text');
    });

    test('returns null for unsupported types', () {
      expect(getTypeMapping('List<String>'), isNull);
      expect(getTypeMapping('Map'), isNull);
      expect(getTypeMapping('CustomClass'), isNull);
    });
  });

  group('isSupportedType', () {
    test('returns true for supported types', () {
      expect(isSupportedType('String'), isTrue);
      expect(isSupportedType('int'), isTrue);
      expect(isSupportedType('DateTime?'), isTrue);
    });

    test('returns false for unsupported types', () {
      expect(isSupportedType('Object'), isFalse);
    });
  });
}
