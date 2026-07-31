import 'dart:convert';

import 'package:acp_dart/acp_dart.dart';
import 'package:test/test.dart';

/// Capability wiring is what makes a method *discoverable*. A method can be
/// fully dispatched and still be unusable in practice if the peer has no way
/// to learn it exists — which is exactly the gap these tests pin.
Map<String, dynamic> _wire(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group('AgentCapabilities', () {
    test('advertises providers, nes, auth, and position encoding', () {
      final caps = AgentCapabilities(
        loadSession: true,
        auth: AgentAuthCapabilities(logout: LogoutCapabilities()),
        providers: ProvidersCapabilities(),
        nes: NesCapabilities(
          context: NesContextCapabilities(
            diagnostics: NesDiagnosticsCapabilities(),
          ),
        ),
        positionEncoding: PositionEncodingKind.utf16,
      );

      final json = _wire(caps.toJson());
      expect(json['providers'], isNotNull);
      expect(json['nes'], isNotNull);
      expect(json['auth']['logout'], isNotNull);
      expect(json['positionEncoding'], equals('utf-16'));

      final decoded = AgentCapabilities.fromJson(json);
      expect(decoded.providers, isNotNull);
      expect(decoded.nes?.context?.diagnostics, isNotNull);
      expect(decoded.auth?.logout, isNotNull);
      expect(decoded.positionEncoding, equals(PositionEncodingKind.utf16));
    });

    test('an agent offering nothing extra leaves them null', () {
      final decoded = AgentCapabilities.fromJson(
        _wire(AgentCapabilities().toJson()),
      );

      expect(decoded.providers, isNull);
      expect(decoded.nes, isNull);
      expect(decoded.auth, isNull);
      expect(decoded.positionEncoding, isNull);
    });
  });

  group('ClientCapabilities', () {
    test('advertises session, plan, auth, nes, and position encodings', () {
      final caps = ClientCapabilities(
        fs: FileSystemCapability(readTextFile: true),
        terminal: true,
        session: ClientSessionCapabilities(
          configOptions: SessionConfigOptionsCapabilities(
            boolean: BooleanConfigOptionCapabilities(),
          ),
        ),
        plan: PlanCapabilities(),
        auth: AuthCapabilities(terminal: true),
        nes: ClientNesCapabilities(jump: NesJumpCapabilities()),
        elicitation: ElicitationCapabilities(
          form: ElicitationFormCapabilities(),
        ),
        positionEncodings: const [
          PositionEncodingKind.utf16,
          PositionEncodingKind.utf8,
        ],
      );

      final json = _wire(caps.toJson());
      expect(json['positionEncodings'], equals(['utf-16', 'utf-8']));

      final decoded = ClientCapabilities.fromJson(json);
      expect(decoded.session?.configOptions?.boolean, isNotNull);
      expect(decoded.plan, isNotNull);
      expect(decoded.auth?.terminal, isTrue);
      expect(decoded.nes?.jump, isNotNull);
      expect(decoded.nes?.rename, isNull);
      expect(decoded.elicitation?.form, isNotNull);
      expect(
        decoded.positionEncodings,
        equals([PositionEncodingKind.utf16, PositionEncodingKind.utf8]),
      );
    });

    test('a minimal client leaves the new capabilities null', () {
      final decoded = ClientCapabilities.fromJson(
        _wire(ClientCapabilities().toJson()),
      );

      expect(decoded.session, isNull);
      expect(decoded.plan, isNull);
      expect(decoded.auth, isNull);
      expect(decoded.nes, isNull);
      expect(decoded.positionEncodings, isNull);
    });
  });

  group('SessionCapabilities', () {
    test('advertises delete, close, and additional directories', () {
      final caps = SessionCapabilities(
        list: SessionListCapabilities(),
        fork: SessionForkCapabilities(),
        resume: SessionResumeCapabilities(),
        delete: SessionDeleteCapabilities(),
        close: SessionCloseCapabilities(),
        additionalDirectories: SessionAdditionalDirectoriesCapabilities(),
      );

      final decoded = SessionCapabilities.fromJson(_wire(caps.toJson()));

      expect(decoded.delete, isNotNull);
      expect(decoded.close, isNotNull);
      expect(decoded.additionalDirectories, isNotNull);
    });

    test('omitted lifecycle capabilities stay null', () {
      final decoded = SessionCapabilities.fromJson(
        _wire(SessionCapabilities().toJson()),
      );

      expect(decoded.delete, isNull);
      expect(decoded.close, isNull);
      expect(decoded.additionalDirectories, isNull);
    });
  });

  group('PositionEncodingKind', () {
    test('serializes to the hyphenated wire values', () {
      final json = _wire(
        ClientCapabilities(
          positionEncodings: PositionEncodingKind.values,
        ).toJson(),
      );

      expect(
        json['positionEncodings'],
        equals(['utf-8', 'utf-16', 'utf-32']),
      );
    });
  });

  group('Initialize handshake carries the full capability set', () {
    test('agent and client capabilities survive the round-trip', () {
      final request = InitializeRequest(
        protocolVersion: 1,
        clientCapabilities: ClientCapabilities(
          nes: ClientNesCapabilities(rename: NesRenameCapabilities()),
          elicitation: ElicitationCapabilities(
            url: ElicitationUrlCapabilities(),
          ),
        ),
      );
      final response = InitializeResponse(
        protocolVersion: 1,
        agentCapabilities: AgentCapabilities(
          providers: ProvidersCapabilities(),
          nes: NesCapabilities(events: NesEventCapabilities()),
          sessionCapabilities: SessionCapabilities(
            delete: SessionDeleteCapabilities(),
          ),
        ),
        authMethods: const [],
      );

      final decodedRequest = InitializeRequest.fromJson(
        _wire(request.toJson()),
      );
      final decodedResponse = InitializeResponse.fromJson(
        _wire(response.toJson()),
      );

      expect(decodedRequest.clientCapabilities?.nes?.rename, isNotNull);
      expect(decodedRequest.clientCapabilities?.elicitation?.url, isNotNull);
      expect(decodedResponse.agentCapabilities?.providers, isNotNull);
      expect(decodedResponse.agentCapabilities?.nes?.events, isNotNull);
      expect(
        decodedResponse.agentCapabilities?.sessionCapabilities?.delete,
        isNotNull,
      );
    });
  });
}
