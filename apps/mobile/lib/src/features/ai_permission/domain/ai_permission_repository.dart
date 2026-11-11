/// AI processing permission is separate from optional learning enrollment.
abstract class AiPermissionRepository {
  Future<bool> load(String ownerId);
  bool isAllowed(String ownerId);
  Future<void> allow(String ownerId);
  Future<void> revoke(String ownerId);
}

abstract final class AiProcessingPolicy {
  static const version = 'openai-processing-2026-11-11-v1';
  static final privacyUri = Uri.parse('https://www.musicdna.fm/privacy');
  static const title = 'Before the Critic joins in';
  static const disclosure =
      'MusicDNA sends your song titles, music choices, reactions, reading '
      'context and any messages you write to OpenAI to generate and check '
      'the Critic’s responses. Messages may include personal information '
      'you choose to share. Don’t include sensitive information.';
  static const explanation =
      'This permission is for AI-powered readings and conversations. It '
      'doesn’t enroll you in optional learning or publish your reading. '
      'You can turn it off in Account → AI permission on this device.';
}
