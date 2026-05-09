class TemplateEngine {
  static final RegExp _placeholderRegExp = RegExp(r'{{\s*([a-zA-Z0-9_]+)\s*}}');

  Set<String> extractPlaceholders(String source) {
    return _placeholderRegExp
        .allMatches(source)
        .map((match) => match.group(1) ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  String render(String source, Map<String, String> values) {
    return source.replaceAllMapped(_placeholderRegExp, (match) {
      final key = match.group(1);
      if (key == null) {
        return match.group(0) ?? '';
      }
      return values[key] ?? match.group(0) ?? '';
    });
  }
}
