// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
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
    final tableName = customTableName ?? classNameToTableName(className);

    // Resolve schema variable name.
    final schemaVar = classNameToSchemaVar(className);

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

      if (mapping == null) {
        throw InvalidGenerationSourceError(
          'Unsupported type "$dartTypeName" on field "${field.name}" '
          'in class "${classElement.name}". '
          'Supported types: String, int, double, bool, DateTime, Uint8List.',
          element: field,
        );
      }

      final isPrimaryKey = _hasAnnotation(field, 'PrimaryKey');
      final isNullable = dartType.nullabilitySuffix == NullabilitySuffix.question;

      // Check for @Column annotation for custom name / default value.
      final columnAnnotation = _getAnnotation(field, 'Column');
      String? customColumnName;
      String? defaultValue;
      if (columnAnnotation != null) {
        customColumnName =
            columnAnnotation.peek('name')?.stringValue;
        defaultValue =
            columnAnnotation.peek('defaultValue')?.stringValue;
      }

      final columnName = customColumnName ?? toSnakeCase(field.name);

      fields.add(_FieldInfo(
        fieldName: field.name,
        columnName: columnName,
        dartTypeName: dartTypeName,
        mapping: mapping,
        isPrimaryKey: isPrimaryKey,
        isNullable: isNullable,
        defaultValue: defaultValue,
      ));
    }

    return fields;
  }

  void _validateConstructor(ClassElement classElement, List<_FieldInfo> fields) {
    final constructor = classElement.unnamedConstructor;
    if (constructor == null) {
      throw InvalidGenerationSourceError(
        '@RelaxTable class ${classElement.name} must have an unnamed constructor.',
        element: classElement,
      );
    }

    final paramNames = constructor.parameters.map((p) => p.name).toSet();
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

  /// Generates a `ColumnDef.xxx(...)` expression.
  String _generateColumnDef(_FieldInfo field) {
    final ctor = field.mapping.columnConstructor;
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
    final castType = field.mapping.dartCastType;
    final nullable = field.isNullable ? '?' : '';
    return "${field.fieldName}: map['${field.columnName}'] as $castType$nullable";
  }

  /// Generates a `'column_name': entity.fieldName` expression.
  String _generateToMapEntry(_FieldInfo field) {
    return "'${field.columnName}': entity.${field.fieldName}";
  }

  bool _hasAnnotation(FieldElement field, String name) {
    return field.metadata.any((m) {
      final value = m.computeConstantValue();
      if (value == null) return false;
      final typeName = value.type?.getDisplayString();
      return typeName == name;
    });
  }

  ConstantReader? _getAnnotation(FieldElement field, String name) {
    for (final meta in field.metadata) {
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
  final String dartTypeName;
  final TypeMapping mapping;
  final bool isPrimaryKey;
  final bool isNullable;
  final String? defaultValue;

  _FieldInfo({
    required this.fieldName,
    required this.columnName,
    required this.dartTypeName,
    required this.mapping,
    required this.isPrimaryKey,
    required this.isNullable,
    this.defaultValue,
  });
}
