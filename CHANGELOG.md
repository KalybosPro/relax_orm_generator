## 0.1.2

### Fixed

- Fixed package publication metadata validation

## 0.1.1

### Changed

- Annotations are no longer duplicated in this package — now imported from `package:relax_orm/relax_orm_annotations.dart` (single source of truth)
- Added `relax_orm: ^0.1.0` as a dependency
- Added `issue_tracker`, `platforms` metadata to pubspec

### Removed

- Removed local `lib/src/annotations/` directory (duplicate of `relax_orm`)
- Removed `lib/relax_orm_annotations.dart` re-export (no longer needed)

## 0.1.0

- Initial release
- `RelaxTableGenerator` generates `TableSchema<T>` from `@RelaxTable()` annotated classes
- Automatic camelCase to snake_case conversion for table and column names
- Support for `@PrimaryKey()`, `@Column(name:, nullable:, defaultValue:)`, `@Ignore()`
- Supported types: `String`, `int`, `double`, `bool`, `DateTime`, `Uint8List` (+ nullable)
