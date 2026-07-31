import 'package:acp_dart/src/schema.dart';
import 'package:json_annotation/json_annotation.dart';

/// Converts a session config option, discriminated on `type`.
///
/// `select` is the wire default, so an option with no `type` is treated as a
/// select rather than falling back to [UnknownSessionConfigOption] — older
/// agents predating the boolean variant omit the field entirely.
class SessionConfigOptionConverter
    implements JsonConverter<SessionConfigOption, Map<String, dynamic>> {
  const SessionConfigOptionConverter();

  @override
  SessionConfigOption fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'select';
    final data = Map<String, dynamic>.from(json)..remove('type');
    switch (type) {
      case 'select':
        return SelectSessionConfigOption.fromJson(data);
      case 'boolean':
        return BooleanSessionConfigOption.fromJson(data);
      default:
        return UnknownSessionConfigOption(rawJson: json);
    }
  }

  @override
  Map<String, dynamic> toJson(SessionConfigOption object) {
    if (object is SelectSessionConfigOption) {
      return {'type': 'select', ...object.toJson()};
    }
    if (object is BooleanSessionConfigOption) {
      return {'type': 'boolean', ...object.toJson()};
    }
    if (object is UnknownSessionConfigOption) {
      return object.rawJson;
    }
    throw ArgumentError.value(
      object,
      'object',
      'Unknown SessionConfigOption variant',
    );
  }
}

/// Converts a required list of session config options.
class SessionConfigOptionListConverter
    implements JsonConverter<List<SessionConfigOption>, List<dynamic>> {
  const SessionConfigOptionListConverter();

  static const _entry = SessionConfigOptionConverter();

  @override
  List<SessionConfigOption> fromJson(List<dynamic> json) => json
      .map((value) => _entry.fromJson(value as Map<String, dynamic>))
      .toList();

  @override
  List<dynamic> toJson(List<SessionConfigOption> object) =>
      object.map(_entry.toJson).toList();
}

/// Converts an optional list of session config options.
///
/// Deliberately self-contained rather than delegating to
/// [SessionConfigOptionListConverter]: json_serializable reconstructs the
/// converter as a const expression, and a `static const` field referencing a
/// sibling list converter makes it emit a mangled type name.
class NullableSessionConfigOptionListConverter
    implements JsonConverter<List<SessionConfigOption>?, List<dynamic>?> {
  const NullableSessionConfigOptionListConverter();

  static const _entry = SessionConfigOptionConverter();

  @override
  List<SessionConfigOption>? fromJson(List<dynamic>? json) => json
      ?.map((value) => _entry.fromJson(value as Map<String, dynamic>))
      .toList();

  @override
  List<dynamic>? toJson(List<SessionConfigOption>? object) =>
      object?.map(_entry.toJson).toList();
}
