/// Converts a camelCase string to snake_case.
///
/// Examples:
/// - `createdAt` → `created_at`
/// - `firstName` → `first_name`
/// - `id` → `id`
/// - `userID` → `user_id`
String toSnakeCase(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == char.toUpperCase() && char != char.toLowerCase()) {
      // It's an uppercase letter.
      if (i > 0) buffer.write('_');
      buffer.write(char.toLowerCase());
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// Derives a table name from a class name.
///
/// Converts to snake_case and appends 's' for a naive pluralization.
///
/// Examples:
/// - `User` → `users`
/// - `BlogPost` → `blog_posts`
/// - `Category` → `categorys` (naive — custom name recommended)
String classNameToTableName(String className) {
  final snake = toSnakeCase(className);
  return '${snake}s';
}

/// Derives a schema variable name from a class name.
///
/// Examples:
/// - `User` → `userSchema`
/// - `BlogPost` → `blogPostSchema`
String classNameToSchemaVar(String className) {
  final first = className[0].toLowerCase();
  final rest = className.substring(1);
  return '$first${rest}Schema';
}
