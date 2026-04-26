import 'dart:convert';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:relax_orm_generator/builder.dart';
import 'package:test/test.dart';

void main() {
  test('generates JSON-backed mappings for nested models and lists', () async {
    await testBuilder(
      relaxOrmBuilder(BuilderOptions.empty),
      {
        'relax_orm|lib/relax_orm_annotations.dart': r'''
library;

class RelaxTable {
  final String? name;
  const RelaxTable({this.name});
}

class PrimaryKey {
  const PrimaryKey();
}

class Ignore {
  const Ignore();
}

class Column {
  final String? name;
  final bool? nullable;
  final String? defaultValue;

  const Column({this.name, this.nullable, this.defaultValue});
}
''',
        'relax_orm_generator|lib/auth_user.dart': r'''
import 'package:relax_orm/relax_orm_annotations.dart';

part 'auth_user.g.dart';

class User {
  User({
    this.id,
    this.name,
    this.createdAt,
  });

  String? id;
  String? name;
  DateTime? createdAt;
}

@RelaxTable()
class AuthUser {
  AuthUser({
    this.id,
    this.user,
    this.tags,
    this.friends,
  });

  @PrimaryKey()
  String? id;
  User? user;
  List<String>? tags;
  List<User>? friends;
}
''',
      },
      outputs: {
        'relax_orm_generator|lib/auth_user.relax_orm.g.part': predicate<Object?>(
          (output) {
            final content = output is List<int> ? utf8.decode(output) : '$output';
            return content.contains("ColumnDef.text('user', isNullable: true)") &&
                content.contains("ColumnDef.text('tags', isNullable: true)") &&
                content.contains("ColumnDef.text('friends', isNullable: true)") &&
                content.contains("'user': RelaxOrmJson.encode(") &&
                content.contains("'tags': RelaxOrmJson.encode(") &&
                content.contains("'friends': RelaxOrmJson.encode(") &&
                content.contains('User(') &&
                content.contains('RelaxOrmJson.asList(') &&
                content.contains('DateTime.parse(');
          },
        ),
      },
    );
  });
}
