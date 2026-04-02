import 'package:test/test.dart';
import 'package:relax_orm_generator/src/naming_utils.dart';

void main() {
  group('toSnakeCase', () {
    test('simple camelCase', () {
      expect(toSnakeCase('createdAt'), 'created_at');
      expect(toSnakeCase('firstName'), 'first_name');
    });

    test('single word', () {
      expect(toSnakeCase('id'), 'id');
      expect(toSnakeCase('name'), 'name');
    });

    test('uppercase abbreviations', () {
      expect(toSnakeCase('userID'), 'user_i_d');
    });

    test('already snake_case', () {
      expect(toSnakeCase('already_snake'), 'already_snake');
    });

    test('starts with lowercase', () {
      expect(toSnakeCase('isDraft'), 'is_draft');
    });
  });

  group('classNameToTableName', () {
    test('pluralizes and snake_cases', () {
      expect(classNameToTableName('User'), 'users');
      expect(classNameToTableName('BlogPost'), 'blog_posts');
      expect(classNameToTableName('Category'), 'categorys');
    });
  });

  group('classNameToSchemaVar', () {
    test('produces camelCase schema variable', () {
      expect(classNameToSchemaVar('User'), 'userSchema');
      expect(classNameToSchemaVar('BlogPost'), 'blogPostSchema');
    });
  });
}
