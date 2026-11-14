class GuestReading {
  const GuestReading({
    required this.sourceUserId,
    required this.sessionId,
    required this.resultVersion,
    this.promptDismissed = false,
    this.emailRequested = false,
  });
  final String sourceUserId, sessionId;
  final int resultVersion;
  final bool promptDismissed, emailRequested;
  String get readingPath => '/session/$sessionId?version=$resultVersion';
  String get savePath =>
      '/save-reading?session=$sessionId&version=$resultVersion';
  GuestReading copyWith({bool? promptDismissed, bool? emailRequested}) =>
      GuestReading(
        sourceUserId: sourceUserId,
        sessionId: sessionId,
        resultVersion: resultVersion,
        promptDismissed: promptDismissed ?? this.promptDismissed,
        emailRequested: emailRequested ?? this.emailRequested,
      );
  Map<String, dynamic> toJson() => {
    'source_user_id': sourceUserId,
    'session_id': sessionId,
    'result_version': resultVersion,
    'prompt_dismissed': promptDismissed,
    'email_requested': emailRequested,
  };
  factory GuestReading.fromJson(Map<String, dynamic> json) => GuestReading(
    sourceUserId: json['source_user_id'] as String,
    sessionId: json['session_id'] as String,
    resultVersion: json['result_version'] as int,
    promptDismissed: json['prompt_dismissed'] == true,
    emailRequested: json['email_requested'] == true,
  );
}

class GuestSaveFailure implements Exception {
  const GuestSaveFailure(this.message);
  final String message;
}
