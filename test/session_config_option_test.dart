import 'dart:convert';

import 'package:acp_dart/acp_dart.dart';
import 'package:acp_dart/src/session_config_option_converter.dart';
import 'package:test/test.dart';

Map<String, dynamic> _wire(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  const converter = SessionConfigOptionConverter();

  group('Boolean config options', () {
    test('round-trip with a bool currentValue', () {
      // This is the shape that could not be represented before: `options` was
      // required and `currentValue` was typed as a String.
      final option = BooleanSessionConfigOption(
        id: 'auto_accept',
        name: 'Auto-accept edits',
        description: 'Apply edits without asking',
        currentValue: true,
      );

      final encoded = _wire(converter.toJson(option));
      expect(encoded['type'], equals('boolean'));
      expect(encoded['currentValue'], isTrue);
      expect(encoded.containsKey('options'), isFalse);

      final decoded = converter.fromJson(encoded);
      expect(decoded, isA<BooleanSessionConfigOption>());
      expect((decoded as BooleanSessionConfigOption).currentValue, isTrue);
      expect(decoded.id, equals('auto_accept'));
      expect(decoded.description, equals('Apply edits without asking'));
    });

    test('false round-trips as false, not as absent', () {
      final decoded =
          converter.fromJson(
                _wire(
                  converter.toJson(
                    BooleanSessionConfigOption(
                      id: 'x',
                      name: 'X',
                      currentValue: false,
                    ),
                  ),
                ),
              )
              as BooleanSessionConfigOption;

      expect(decoded.currentValue, isFalse);
    });
  });

  group('Select config options', () {
    test('round-trip with ungrouped options', () {
      final option = SelectSessionConfigOption(
        id: 'mode',
        name: 'Mode',
        category: SessionConfigOptionCategories.mode,
        currentValue: 'code',
        options: UngroupedSessionConfigSelectOptions(
          options: [
            SessionConfigSelectOption(value: 'code', name: 'Code'),
            SessionConfigSelectOption(value: 'ask', name: 'Ask'),
          ],
        ),
      );

      final encoded = _wire(converter.toJson(option));
      expect(encoded['type'], equals('select'));

      final decoded = converter.fromJson(encoded);
      expect(decoded, isA<SelectSessionConfigOption>());
      final typed = decoded as SelectSessionConfigOption;
      expect(typed.currentValue, equals('code'));
      expect(typed.category, equals('mode'));
      expect(typed.options, isA<UngroupedSessionConfigSelectOptions>());
    });

    test('an option with no type is read as select', () {
      // Agents predating the boolean variant omit `type` entirely; treating
      // that as unknown would break every one of them.
      final decoded = converter.fromJson({
        'id': 'mode',
        'name': 'Mode',
        'currentValue': 'code',
        'options': [
          {'value': 'code', 'name': 'Code'},
        ],
      });

      expect(decoded, isA<SelectSessionConfigOption>());
    });

    test('an unknown type is preserved rather than dropped', () {
      final raw = {'type': '_vendor', 'id': 'x', 'name': 'X', 'extra': 1};
      final decoded = converter.fromJson(raw);

      expect(decoded, isA<UnknownSessionConfigOption>());
      expect(decoded.id, equals('x'));
      expect(decoded.name, equals('X'));
      expect(converter.toJson(decoded), equals(raw));
    });
  });

  group('Mixed lists', () {
    test('a response carries select and boolean options side by side', () {
      final response = SetSessionConfigOptionResponse(
        configOptions: [
          SelectSessionConfigOption(
            id: 'mode',
            name: 'Mode',
            currentValue: 'code',
            options: UngroupedSessionConfigSelectOptions(
              options: [SessionConfigSelectOption(value: 'code', name: 'Code')],
            ),
          ),
          BooleanSessionConfigOption(
            id: 'verbose',
            name: 'Verbose',
            currentValue: true,
          ),
        ],
      );

      final decoded = SetSessionConfigOptionResponse.fromJson(
        _wire(response.toJson()),
      );

      expect(decoded.configOptions, hasLength(2));
      expect(decoded.configOptions[0], isA<SelectSessionConfigOption>());
      expect(decoded.configOptions[1], isA<BooleanSessionConfigOption>());
    });

    test('the config_option_update session update carries both', () {
      final notification = SessionNotification(
        sessionId: 's1',
        update: ConfigOptionUpdate(
          configOptions: [
            BooleanSessionConfigOption(
              id: 'b',
              name: 'B',
              currentValue: false,
            ),
          ],
        ),
      );

      final decoded = SessionNotification.fromJson(
        _wire(notification.toJson()),
      );
      final update = decoded.update as ConfigOptionUpdate;

      expect(update.configOptions.single, isA<BooleanSessionConfigOption>());
    });
  });

  group('SetSessionConfigOptionRequest', () {
    test('the boolean form carries a bool value and the discriminator', () {
      final request = SetSessionConfigOptionRequest.boolean(
        sessionId: 's1',
        configId: 'verbose',
        value: true,
      );

      final json = _wire(request.toJson());
      expect(json['value'], isTrue);
      expect(json['type'], equals('boolean'));

      final decoded = SetSessionConfigOptionRequest.fromJson(json);
      expect(decoded.value, isTrue);
      expect(decoded.type, equals('boolean'));
    });

    test('the select form omits the discriminator', () {
      final request = SetSessionConfigOptionRequest.select(
        sessionId: 's1',
        configId: 'mode',
        value: 'code',
      );

      final json = _wire(request.toJson());
      expect(json['value'], equals('code'));
      expect(
        json.containsKey('type'),
        isFalse,
        reason: 'select is the wire default and carries no type field',
      );

      expect(SetSessionConfigOptionRequest.fromJson(json).value, equals('code'));
    });
  });

  group('Category constants', () {
    test('match the schema values', () {
      expect(SessionConfigOptionCategories.mode, equals('mode'));
      expect(SessionConfigOptionCategories.model, equals('model'));
      expect(SessionConfigOptionCategories.modelConfig, equals('model_config'));
      expect(
        SessionConfigOptionCategories.thoughtLevel,
        equals('thought_level'),
      );
    });

    test('an unrecognised category passes through', () {
      final decoded =
          converter.fromJson({
                'type': 'boolean',
                'id': 'x',
                'name': 'X',
                'category': 'some_future_category',
                'currentValue': true,
              })
              as BooleanSessionConfigOption;

      expect(decoded.category, equals('some_future_category'));
    });
  });
}
