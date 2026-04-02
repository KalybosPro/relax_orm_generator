/// Maps Dart type names to RelaxORM ColumnDef constructor names and cast expressions.
class TypeMapping {
  /// The ColumnDef constructor name (e.g., 'text', 'integer').
  final String columnConstructor;

  /// The Dart type to cast from the map (e.g., 'String', 'int').
  final String dartCastType;

  const TypeMapping(this.columnConstructor, this.dartCastType);
}

/// Known type mappings from Dart types to SQLite column types.
const _typeMappings = <String, TypeMapping>{
  'String': TypeMapping('text', 'String'),
  'int': TypeMapping('integer', 'int'),
  'double': TypeMapping('real', 'double'),
  'bool': TypeMapping('boolean', 'bool'),
  'DateTime': TypeMapping('dateTime', 'DateTime'),
  'Uint8List': TypeMapping('blob', 'Uint8List'),
};

/// Returns the [TypeMapping] for a Dart type name, or `null` if unsupported.
TypeMapping? getTypeMapping(String dartTypeName) {
  // Strip nullable suffix for lookup.
  final baseName = dartTypeName.endsWith('?')
      ? dartTypeName.substring(0, dartTypeName.length - 1)
      : dartTypeName;
  return _typeMappings[baseName];
}

/// Returns `true` if the given Dart type name is supported by RelaxORM.
bool isSupportedType(String dartTypeName) {
  return getTypeMapping(dartTypeName) != null;
}
