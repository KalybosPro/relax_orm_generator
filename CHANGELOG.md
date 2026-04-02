## 0.1.0

- Initial release
- `RelaxTableGenerator` generates `TableSchema<T>` from `@RelaxTable()` annotated classes
- Automatic camelCase to snake_case conversion for table and column names
- Support for `@PrimaryKey()`, `@Column(name:, nullable:, defaultValue:)`, `@Ignore()`
- Supported types: `String`, `int`, `double`, `bool`, `DateTime`, `Uint8List` (+ nullable)
