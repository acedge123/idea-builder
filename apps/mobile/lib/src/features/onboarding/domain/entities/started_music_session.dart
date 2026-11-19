import 'package:equatable/equatable.dart';
import '../../../session/domain/entities/interview_flow.dart';
import '../../../session/domain/entities/session_mode.dart';

class StartedMusicSession extends Equatable {
  const StartedMusicSession({
    required this.sessionId,
    required this.sessionLane,
    required this.sessionLaneConfidence,
    required this.analysisLane,
    required this.analysisConfidence,
    required this.hypothesis,
    required this.reaction,
    required this.reasoning,
    required this.secondaryLanes,
    required this.songs,
    this.flow,
    this.mode,
    this.parentSessionId,
    this.decade,
  });

  factory StartedMusicSession.reference(
    String sessionId, {
    String? mode,
    String? parentSessionId,
    int? decade,
  }) => StartedMusicSession(
    sessionId: sessionId,
    sessionLane: '',
    sessionLaneConfidence: 0,
    analysisLane: '',
    analysisConfidence: 0,
    hypothesis: '',
    reaction: '',
    reasoning: const [],
    secondaryLanes: const [],
    songs: const [],
    mode: mode,
    parentSessionId: parentSessionId,
    decade: decade,
  );

  final String sessionId;
  final String sessionLane;
  final double sessionLaneConfidence;
  final String analysisLane;
  final double analysisConfidence;
  final String hypothesis;
  final String reaction;
  final List<String> reasoning;
  final List<String> secondaryLanes;
  final List<String> songs;
  final InterviewFlow? flow;
  final String? mode, parentSessionId;
  final int? decade;
  SessionMode get sessionMode => SessionMode.fromWire(mode);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'sessionLane': sessionLane,
      'sessionLaneConfidence': sessionLaneConfidence,
      'analysisLane': analysisLane,
      'analysisConfidence': analysisConfidence,
      'hypothesis': hypothesis,
      'reaction': reaction,
      'reasoning': reasoning,
      'secondaryLanes': secondaryLanes,
      'songs': songs,
      if (flow != null) 'flow': flow!.wireName,
      if (mode != null) 'mode': mode,
      if (parentSessionId != null) 'parentSessionId': parentSessionId,
      if (decade != null) 'decade': decade,
    };
  }

  static StartedMusicSession? fromJson(Map<String, dynamic> json) {
    final sessionId = json['sessionId'];
    if (sessionId is! String || sessionId.isEmpty) {
      return null;
    }

    return StartedMusicSession(
      sessionId: sessionId,
      sessionLane: json['sessionLane'] as String? ?? '',
      sessionLaneConfidence: _readDouble(json['sessionLaneConfidence']),
      analysisLane: json['analysisLane'] as String? ?? '',
      analysisConfidence: _readDouble(json['analysisConfidence']),
      hypothesis: json['hypothesis'] as String? ?? '',
      reaction: json['reaction'] as String? ?? '',
      reasoning: _readStringList(json['reasoning']),
      secondaryLanes: _readStringList(json['secondaryLanes']),
      songs: _readStringList(json['songs']),
      flow: InterviewFlow.fromWire(json['flow']),
      mode: json['mode'] as String?,
      parentSessionId: json['parentSessionId'] as String?,
      decade: json['decade'] as int?,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    sessionId,
    sessionLane,
    sessionLaneConfidence,
    analysisLane,
    analysisConfidence,
    hypothesis,
    reaction,
    reasoning,
    secondaryLanes,
    songs,
    flow,
    mode,
    parentSessionId,
    decade,
  ];

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  static List<String> _readStringList(Object? value) {
    if (value is List) {
      return value.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }
}
