# RelaxORM Generator

Code generator for [relax_orm](https://pub.dev/packages/relax_orm). Generates `TableSchema` definitions from annotated Dart classes.

## Setup

```yaml
dependencies:
  relax_orm: ^0.1.0

dev_dependencies:
  relax_orm_generator: ^0.1.0
  build_runner: ^2.4.0
```

## Usage

Annotate your model classes with `@RelaxTable()`:

```dart
import 'package:relax_orm/relax_orm.dart';

part 'user.g.dart';

@RelaxTable()
class User {
  @PrimaryKey()
  final String id;
  final String name;
  final int age;
  final DateTime createdAt;

  User({required this.id, required this.name, required this.age, required this.createdAt});
}
```

Run the generator:

```bash
dart run build_runner build
```

This generates `user.g.dart`:

```dart
final userSchema = TableSchema<User>(
  tableName: 'users',
  columns: [
    ColumnDef.text('id', isPrimaryKey: true),
    ColumnDef.text('name'),
    ColumnDef.integer('age'),
    ColumnDef.dateTime('created_at'),
  ],
  fromMap: (map) => User(
    id: map['id'] as String,
    name: map['name'] as String,
    age: map['age'] as int,
    createdAt: map['created_at'] as DateTime,
  ),
  toMap: (entity) => {
    'id': entity.id,
    'name': entity.name,
    'age': entity.age,
    'created_at': entity.createdAt,
  },
);
```

## Annotations

| Annotation | Effect |
|---|---|
| `@RelaxTable()` | Generates a schema for the class |
| `@RelaxTable(name: 'custom')` | Custom table name |
| `@PrimaryKey()` | Marks the primary key |
| `@Column(name: 'col')` | Custom column name |
| `@Ignore()` | Excludes a field |

## Naming conventions

- **Table names**: `User` -> `users`, `BlogPost` -> `blog_posts`
- **Column names**: `createdAt` -> `created_at`, `firstName` -> `first_name`

Override with `@RelaxTable(name: ...)` or `@Column(name: ...)`.

## Supported types

`String`, `int`, `double`, `bool`, `DateTime`, `Uint8List` (and nullable variants).

## License

MIT
