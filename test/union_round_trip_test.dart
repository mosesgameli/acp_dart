import 'dart:convert';

import 'package:acp_dart/acp_dart.dart';
import 'package:acp_dart/src/content_block_converter.dart';
import 'package:acp_dart/src/mcp_server_converter.dart';
import 'package:acp_dart/src/request_permission_converter.dart';
import 'package:acp_dart/src/session_update_converter.dart';
import 'package:acp_dart/src/tool_call_content_converter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:test/test.dart';

/// Serialisation round-trip coverage for the discriminated unions.
///
/// The existing union tests only parse hand-written JSON, which always has a
/// `type` field because a human typed it. That left a gap: a variant could fail
/// to *emit* its discriminator and every test would still pass, while nothing
/// could actually cross the wire. ToolCallContent did exactly that.
///
/// These tests go the other way - build a Dart object, serialise it through the
/// converter, encode to a real JSON string, and read it back.
void main() {
  /// Encodes through the converter and decodes back, via a real JSON string so
  /// nothing survives on object identity.
  T roundTrip<T, J>(JsonConverter<T, J> converter, T value) {
    final encoded = jsonDecode(jsonEncode(converter.toJson(value)));
    return converter.fromJson(encoded as J);
  }

  group('ToolCallContent', () {
    const converter = ToolCallContentConverter();

    test('content variant keeps its discriminator', () {
      final original = ContentToolCallContent(
        content: TextContentBlock(text: 'hello'),
      );

      expect(converter.toJson(original)['type'], 'content');

      final result = roundTrip(converter, original);
      expect(result, isA<ContentToolCallContent>());
      expect(
        ((result as ContentToolCallContent).content as TextContentBlock).text,
        'hello',
      );
    });

    test('diff variant keeps its discriminator and payload', () {
      final original = DiffToolCallContent(
        path: 'config.json',
        oldText: 'old',
        newText: 'new',
      );

      expect(converter.toJson(original)['type'], 'diff');

      final result = roundTrip(converter, original);
      expect(result, isA<DiffToolCallContent>());
      final diff = result as DiffToolCallContent;
      expect(diff.path, 'config.json');
      expect(diff.oldText, 'old');
      expect(diff.newText, 'new');
    });

    test('terminal variant keeps its discriminator', () {
      final original = TerminalToolCallContent(terminalId: 'term-1');

      expect(converter.toJson(original)['type'], 'terminal');

      final result = roundTrip(converter, original);
      expect(result, isA<TerminalToolCallContent>());
      expect((result as TerminalToolCallContent).terminalId, 'term-1');
    });

    test('survives nesting inside a session update', () {
      // The path that actually broke: tool output travelling inside
      // session/update, which is how every agent reports a tool result.
      final update = ToolCallUpdateSessionUpdate(
        toolCallId: 'call_1',
        status: ToolCallStatus.completed,
        content: [
          ContentToolCallContent(content: TextContentBlock(text: 'output')),
          DiffToolCallContent(path: 'a.txt', newText: 'x'),
        ],
      );

      final decoded = ToolCallUpdateSessionUpdate.fromJson(
        jsonDecode(jsonEncode(update.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.content, hasLength(2));
      expect(decoded.content!.first, isA<ContentToolCallContent>());
      expect(decoded.content!.last, isA<DiffToolCallContent>());
    });

    test('survives nesting inside a permission request', () {
      // The other path that broke: the diff a user is being asked to approve.
      final request = RequestPermissionRequest(
        sessionId: 's1',
        toolCall: ToolCallUpdate(
          toolCallId: 'call_1',
          content: [DiffToolCallContent(path: 'a.txt', newText: 'x')],
        ),
        options: [
          PermissionOption(
            optionId: 'allow',
            name: 'Allow',
            kind: PermissionOptionKind.allowOnce,
          ),
        ],
      );

      final decoded = RequestPermissionRequest.fromJson(
        jsonDecode(jsonEncode(request.toJson())) as Map<String, dynamic>,
      );

      expect(decoded.toolCall.content!.single, isA<DiffToolCallContent>());
    });
  });

  group('ContentBlock', () {
    const converter = ContentBlockConverter();

    final variants = <String, ContentBlock>{
      'text': TextContentBlock(text: 'hi'),
      'image': ImageContentBlock(data: 'AAAA', mimeType: 'image/png'),
      'audio': AudioContentBlock(data: 'AAAA', mimeType: 'audio/wav'),
      'resource_link': ResourceLinkContentBlock(
        name: 'readme',
        uri: 'file:///README.md',
      ),
      'resource': ResourceContentBlock(
        resource: EmbeddedResource(
          resource: TextResourceContents(text: 'body', uri: 'file:///a.txt'),
        ),
      ),
    };

    variants.forEach((discriminator, original) {
      test('$discriminator round-trips', () {
        expect(converter.toJson(original)['type'], discriminator);
        expect(roundTrip(converter, original).runtimeType, original.runtimeType);
      });
    });
  });

  group('RequestPermissionOutcome', () {
    const converter = RequestPermissionOutcomeConverter();

    test('selected round-trips with its option id', () {
      final original = SelectedOutcome(optionId: 'allow-once');

      expect(converter.toJson(original)['outcome'], 'selected');

      final result = roundTrip(converter, original);
      expect(result, isA<SelectedOutcome>());
      expect((result as SelectedOutcome).optionId, 'allow-once');
    });

    test('cancelled round-trips', () {
      final original = CancelledOutcome();

      expect(converter.toJson(original)['outcome'], 'cancelled');
      expect(roundTrip(converter, original), isA<CancelledOutcome>());
    });
  });

  group('McpServer', () {
    const converter = McpServerConverter();

    final variants = <McpServerBase>[
      HttpMcpServer(name: 'docs', url: 'https://example.com', headers: const []),
      SseMcpServer(
        name: 'events',
        url: 'https://example.com/sse',
        headers: const [],
      ),
      StdioMcpServer(
        name: 'local',
        command: 'server',
        args: const [],
        env: const [],
      ),
    ];

    for (final original in variants) {
      test('${original.runtimeType} round-trips', () {
        expect(roundTrip(converter, original).runtimeType, original.runtimeType);
      });
    }
  });

  group('SessionUpdate', () {
    const converter = SessionUpdateConverter();

    final variants = <SessionUpdate>[
      AgentMessageChunkSessionUpdate(content: TextContentBlock(text: 'a')),
      AgentThoughtChunkSessionUpdate(content: TextContentBlock(text: 'b')),
      UserMessageChunkSessionUpdate(content: TextContentBlock(text: 'c')),
      ToolCallSessionUpdate(toolCallId: 't1', title: 'Read'),
      ToolCallUpdateSessionUpdate(toolCallId: 't1'),
      PlanSessionUpdate(
        entries: [
          PlanEntry(
            content: 'step',
            priority: PlanEntryPriority.medium,
            status: PlanEntryStatus.pending,
          ),
        ],
      ),
      CurrentModeUpdateSessionUpdate(currentModeId: 'default'),
      AvailableCommandsUpdateSessionUpdate(availableCommands: const []),
    ];

    for (final original in variants) {
      test('${original.runtimeType} round-trips', () {
        expect(roundTrip(converter, original).runtimeType, original.runtimeType);
      });
    }
  });
}
