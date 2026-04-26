## 0.1.6

### Added

- Added support for JSON-backed serialization of nested model objects
- Added support for `List<T>` fields when `T` is a supported primitive or nested model type

### Changed

- Generator now encodes complex fields with `RelaxOrmJson.encode(...)` and decodes them with `RelaxOrmJson.decode(...)`
- Extended generated mapping support for nested values such as `DateTime` and `Uint8List` inside JSON-backed objects and lists

## 0.1.5

- Update dependencies

## 0.1.4

- Fixed conflict of analyser's version with other packages

## 0.1.3

### Fixed

- Fixed package repository accessibility on Github

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
