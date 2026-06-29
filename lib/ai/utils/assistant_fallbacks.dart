/// Canned replies for the global FBLA AI Assistant (`app_assistant` thread).
/// Used silently when the live API is unavailable — no error text is shown.
class AssistantFallbacks {
  AssistantFallbacks._();

  static const String appAssistantThreadId = 'app_assistant';

  static const Map<String, String> _byQuestion = {
    'how do i upload a video?':
        'Open the **Social** tab, then tap **Video Studio**. Record a new video or '
        'choose one from your gallery, add a title and description, and tap '
        '**Publish to FBLA**. Your post appears in the feed and under **View Your Posts**. '
        'You can also choose **Upload to YouTube** to share on your channel.',
    'what events are coming up?':
        'Go to the **Events** tab to see upcoming FBLA events on the calendar. '
        'Use filters for chapter, state, or national events. Tap an event to **RSVP**, '
        'set a **reminder**, or add it to **Google Calendar**. Upcoming events also '
        'appear on the **Home** screen.',
    'where is the resource library?':
        'Open the **Resources** tab. Add a competitive event as a course, then access '
        '**guidelines and PDFs**, **Cybersecurity levels**, and **AI Coach** practice. '
        'Use **More** inside a course for study notes, the question bank, vocabulary, '
        'and official documents.',
  };

  static const String _generic =
      'I can help with **events**, **resources**, **Social**, and **competitions**. '
      'Try asking how to upload a video, what events are coming up, or where to find '
      'the resource library.';

  static bool isAppAssistantThread(String threadId) =>
      threadId == appAssistantThreadId;

  /// Returns a canned reply for [userMessage], or the generic assistant reply.
  static String resolve(String userMessage) {
    final key = userMessage.trim().toLowerCase();
    return _byQuestion[key] ?? _generic;
  }

  /// True when [text] looks like an API/transport failure rather than a real answer.
  static bool looksLikeError(String text) {
    final lower = text.toLowerCase();
    const markers = [
      'ai assistant error',
      'openrouter',
      'quota',
      'sign in to use',
      'request failed',
      'failed to send',
      'failed to load',
      'http 4',
      'http 5',
      'temporarily busy',
      'empty response',
      'invalid response',
      'api key',
      'token limit',
      'connection error',
      'cannot connect',
      'encountered an error',
    ];
    for (final marker in markers) {
      if (lower.contains(marker)) return true;
    }
    if (lower.startsWith('❌')) return true;
    return false;
  }
}
