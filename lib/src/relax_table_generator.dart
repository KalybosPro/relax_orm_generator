// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'package:relax_orm/relax_orm_annotations.dart';
import 'naming_utils.dart';
import 'type_mapper.dart';

/// Generates `TableSchema<T>` instances from classes annotated with `@RelaxTable()`.
///
/// For a class like:
/// ```dart
/// @RelaxTable()
/// class User {
///   @PrimaryKey()
///   final String id;
///   final String name;
///   final int age;
///
///   User({required this.id, required this.name, required this.age});
/// }
/// ```
///
/// Generates (in the `.g.dart` part file):
/// ```dart
/// final userSchema = TableSchema<User>( ... );
/// ```
class RelaxTableGenerator extends GeneratorForAnnotation<RelaxTable> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@RelaxTable can only be applied to classes.',
        element: element,
      );
    }

    final classElement = element;
    final className = classElement.name;

    // Resolve table name.
    final customTableName = annotation.peek('name')?.stringValue;
    final tableName = customTableName ?? classNameToTableName(className!);

    // Resolve schema variable name.
    final schemaVar = classNameToSchemaVar(className!);

    // Collect fields, skipping @Ignore'd ones.
    final fields = _collectFields(classElement);

    if (fields.isEmpty) {
      throw InvalidGenerationSourceError(
        '@RelaxTable class $className has no usable fields.',
        element: element,
      );
    }

    // Verify at least one primary key exists.
    final hasPrimaryKey = fields.any((f) => f.isPrimaryKey);
    if (!hasPrimaryKey) {
      throw InvalidGenerationSourceError(
        '@RelaxTable class $className has no @PrimaryKey() field. '
        'Add @PrimaryKey() to one field.',
        element: element,
      );
    }

    // Verify constructor exists with named parameters matching all fields.
    _validateConstructor(classElement, fields);

    // Generate the code.
    final buffer = StringBuffer();
    buffer.writeln('// Schema for $className');
    buffer.writeln('final $schemaVar = TableSchema<$className>(');
    buffer.writeln("  tableName: '$tableName',");
    buffer.writeln('  columns: [');
    for (final field in fields) {
      buffer.writeln('    ${_generateColumnDef(field)},');
    }
    buffer.writeln('  ],');
    buffer.writeln('  fromMap: (map) => $className(');
    for (final field in fields) {
      buffer.writeln('    ${_generateFromMapEntry(field)},');
    }
    buffer.writeln('  ),');
    buffer.writeln('  toMap: (entity) => {');
    for (final field in fields) {
      buffer.writeln('    ${_generateToMapEntry(field)},');
    }
    buffer.writeln('  },');
    buffer.writeln(');');

    return buffer.toString();
  }

  /// Collects all annotated/eligible fields from the class.
  List<_FieldInfo> _collectFields(ClassElement classElement) {
    final fields = <_FieldInfo>[];

    for (final field in classElement.fields) {
      // Skip static fields, synthetic fields, and @Ignore'd fields.
      if (field.isStatic || field.isSynthetic) continue;
      if (_hasAnnotation(field, 'Ignore')) continue;

      final dartType = field.type;
      final dartTypeName = dartType.getDisplayString();
      final mapping = getTypeMapping(dartTypeName);
      final isJsonBacked = mapping == null && _isJsonSupportedType(dartType);

      if (mapping == null && !isJsonBacked) {
        throw InvalidGenerationSourceError(
          'Unsupported type "$dartTypeName" on field "${field.name}" '
          'in class "${classElement.name}". '
          'Supported types: String, int, double, bool, DateTime, Uint8List, '
          'other model classes, and List<T> variants of those types.',
          element: field,
        );
      }

      final isPrimaryKey = _hasAnnotation(field, 'PrimaryKey');
      final isNullable =
          dartType.nullabilitySuffix == NullabilitySuffix.question;

      // Check for @Column annotation for custom name / default value.
      final columnAnnotation = _getAnnotation(field, 'Column');
      String? customColumnName;
      String? defaultValue;
      if (columnAnnotation != null) {
        customColumnName = columnAnnotation.peek('name')?.stringValue;
        defaultValue = columnAnnotation.peek('defaultValue')?.stringValue;
      }

      final columnName = customColumnName ?? toSnakeCase(field.name!);

      fields.add(
        _FieldInfo(
          fieldName: field.name!,
          columnName: columnName,
          columnConstructor: mapping?.columnConstructor ?? 'text',
          isPrimaryKey: isPrimaryKey,
          isNullable: isNullable,
          defaultValue: defaultValue,
          fromMapExpression: _buildFromMapExpression(dartType, columnName),
          toMapExpression: _buildToMapExpression(dartType, field.name!),
        ),
      );
    }

    return fields;
  }

  void _validateConstructor(
    ClassElement classElement,
    List<_FieldInfo> fields,
  ) {
    final constructor = classElement.unnamedConstructor;
    if (constructor == null) {
      throw InvalidGenerationSourceError(
        '@RelaxTable class ${classElement.name} must have an unnamed constructor.',
        element: classElement,
      );
    }

    final paramNames = constructor.formalParameters.map((p) => p.name).toSet();
    for (final field in fields) {
      if (!paramNames.contains(field.fieldName)) {
        throw InvalidGenerationSourceError(
          'Constructor of ${classElement.name} is missing parameter '
          '"${field.fieldName}" (needed for field → column mapping).',
          element: classElement,
        );
      }
    }
  }

  void _validateObjectConstructor(
    ClassElement classElement,
    List<FieldElement> fields,
  ) {
    final constructor = classElement.unnamedConstructor;
    if (constructor == null) {
      throw InvalidGenerationSourceError(
        'Class ${classElement.name} must have an unnamed constructor to be '
        'used as a nested RelaxORM model.',
        element: classElement,
      );
    }

    final paramNames = constructor.formalParameters.map((p) => p.name).toSet();
    for (final field in fields) {
      if (!paramNames.contains(field.name)) {
        throw InvalidGenerationSourceError(
          'Constructor of ${classElement.name} is missing parameter '
          '"${field.name}" required for nested model serialization.',
          element: classElement,
        );
      }
    }
  }

  /// Generates a `ColumnDef.xxx(...)` expression.
  String _generateColumnDef(_FieldInfo field) {
    final ctor = field.columnConstructor;
    final parts = <String>["'${field.columnName}'"];
    if (field.isPrimaryKey) parts.add('isPrimaryKey: true');
    if (field.isNullable) parts.add('isNullable: true');
    if (field.defaultValue != null) {
      parts.add("defaultValue: '${field.defaultValue}'");
    }
    return 'ColumnDef.$ctor(${parts.join(', ')})';
  }

  /// Generates a `fieldName: map['column_name'] as Type` expression.
  String _generateFromMapEntry(_FieldInfo field) {
    return '${field.fieldName}: ${field.fromMapExpression}';
  }

  /// Generates a `'column_name': entity.fieldName` expression.
  String _generateToMapEntry(_FieldInfo field) {
    return "'${field.columnName}': ${field.toMapExpression}";
  }

  String _buildFromMapExpression(DartType type, String columnName) {
    final mapping = getTypeMapping(type.getDisplayString());
    if (mapping != null) {
      final nullable =
          type.nullabilitySuffix == NullabilitySuffix.question ? '?' : '';
      return "map['$columnName'] as ${mapping.dartCastType}$nullable";
    }
    return _buildDecodedValueExpression(
      type,
      "RelaxOrmJson.decode(map['$columnName'])",
    );
  }

  String _buildToMapExpression(DartType type, String fieldName) {
    final mapping = getTypeMapping(type.getDisplayString());
    if (mapping != null) {
      return 'entity.$fieldName';
    }
    return 'RelaxOrmJson.encode(${_buildEncodedValueExpression(type, 'entity.$fieldName')})';
  }

  String _buildDecodedValueExpression(DartType type, String source) {
    final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;
    final baseType = _withoutNullability(type);

    final decoded = _buildNonNullableDecodedValueExpression(baseType, source);
    if (isNullable) {
      return '$source == null ? null : $decoded';
    }
    return '($source == null ? null : $decoded)!';
  }

  String _buildNonNullableDecodedValueExpression(DartType type, String source) {
    final typeName = type.getDisplayString();
    final mapping = getTypeMapping(typeName);
    if (mapping != null) {
      switch (typeName) {
        case 'DateTime':
          return 'DateTime.parse($source as String)';
        case 'Uint8List':
          return 'RelaxOrmJson.base64ToBytes($source as String)';
        default:
          return '$source as ${mapping.dartCastType}';
      }
    }

    if (type is InterfaceType &&
        type.element.name == 'List' &&
        type.typeArguments.length == 1) {
      final itemType = type.typeArguments.first;
      final itemValue = _buildDecodedValueExpression(itemType, 'item');
      return 'RelaxOrmJson.asList($source).map((item) => $itemValue).toList()';
    }

    if (type is InterfaceType) {
      final classElement = type.element;
      if (classElement is! ClassElement) {
        throw InvalidGenerationSourceError(
          'Unsupported nested type "$typeName".',
        );
      }
      final fields = _collectSerializableObjectFields(classElement);
      _validateObjectConstructor(classElement, fields);

      final buffer = StringBuffer();
      buffer.writeln('(() {');
      buffer.writeln('  final data = RelaxOrmJson.asMap($source);');
      buffer.writeln('  return ${classElement.name}(');
      for (final field in fields) {
        final fieldType = field.type;
        final fieldExpression = _buildDecodedValueExpression(
          fieldType,
          "data['${field.name}']",
        );
        buffer.writeln('    ${field.name}: $fieldExpression,');
      }
      buffer.write('  );');
      buffer.write('})()');
      return buffer.toString();
    }

    throw InvalidGenerationSourceError(
      'Unsupported JSON-backed type "$typeName".',
    );
  }

  String _buildEncodedValueExpression(DartType type, String source) {
    final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;
    final baseType = _withoutNullability(type);

    final encoded = _buildNonNullableEncodedValueExpression(baseType, source);
    if (isNullable) {
      return '$source == null ? null : $encoded';
    }
    return encoded;
  }

  String _buildNonNullableEncodedValueExpression(DartType type, String source) {
    final typeName = type.getDisplayString();
    final mapping = getTypeMapping(typeName);
    if (mapping != null) {
      switch (typeName) {
        case 'DateTime':
          return '$source.toIso8601String()';
        case 'Uint8List':
          return 'RelaxOrmJson.bytesToBase64($source)';
        default:
          return source;
      }
    }

    if (type is InterfaceType &&
        type.element.name == 'List' &&
        type.typeArguments.length == 1) {
      final itemType = type.typeArguments.first;
      final itemValue = _buildEncodedValueExpression(itemType, 'item');
      return '$source.map((item) => $itemValue).toList()';
    }

    if (type is InterfaceType) {
      final classElement = type.element;
      if (classElement is! ClassElement) {
        throw InvalidGenerationSourceError(
          'Unsupported nested type "$typeName".',
        );
      }
      final fields = _collectSerializableObjectFields(classElement);
      final entries = fields
          .map((field) {
            final fieldValue = _buildEncodedValueExpression(
              field.type,
              '$source.${field.name}',
            );
            return "'${field.name}': $fieldValue";
          })
          .join(', ');
      return '{$entries}';
    }

    throw InvalidGenerationSourceError(
      'Unsupported JSON-backed type "$typeName".',
    );
  }

  bool _isJsonSupportedType(DartType type) {
    if (getTypeMapping(type.getDisplayString()) != null) return true;

    final baseType = _withoutNullability(type);
    if (baseType is InterfaceType &&
        baseType.element.name == 'List' &&
        baseType.typeArguments.length == 1) {
      return _isJsonSupportedType(baseType.typeArguments.first);
    }

    if (baseType is InterfaceType) {
      final classElement = baseType.element;
      if (classElement is! ClassElement) return false;
      final fields = _collectSerializableObjectFields(classElement);
      if (fields.isEmpty) return false;
      return fields.every((field) => _isJsonSupportedType(field.type));
    }

    return false;
  }

  List<FieldElement> _collectSerializableObjectFields(
    ClassElement classElement,
  ) {
    return classElement.fields.where((field) {
      if (field.isStatic || field.isSynthetic) return false;
      if (_hasAnnotation(field, 'Ignore')) return false;
      return true;
    }).toList();
  }

  DartType _withoutNullability(DartType type) {
    return type is InterfaceType
        ? type.element.instantiate(
            typeArguments: type.typeArguments,
            nullabilitySuffix: NullabilitySuffix.none,
          )
        : type;
  }

  bool _hasAnnotation(FieldElement field, String name) {
    return field.metadata.annotations.any((m) {
      final value = m.computeConstantValue();
      if (value == null) return false;
      final typeName = value.type?.getDisplayString();
      return typeName == name;
    });
  }

  ConstantReader? _getAnnotation(FieldElement field, String name) {
    for (final meta in field.metadata.annotations) {
      final value = meta.computeConstantValue();
      if (value == null) continue;
      final typeName = value.type?.getDisplayString();
      if (typeName == name) return ConstantReader(value);
    }
    return null;
  }
}

/// Internal representation of a field to generate code for.
class _FieldInfo {
  final String fieldName;
  final String columnName;
  final String columnConstructor;
  final bool isPrimaryKey;
  final bool isNullable;
  final String? defaultValue;
  final String fromMapExpression;
  final String toMapExpression;

  _FieldInfo({
    required this.fieldName,
    required this.columnName,
    required this.columnConstructor,
    required this.isPrimaryKey,
    required this.isNullable,
    this.defaultValue,
    required this.fromMapExpression,
    required this.toMapExpression,
  });
}
