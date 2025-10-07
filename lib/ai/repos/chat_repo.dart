class ChatRepository {
  static const String _apiKey =
      'sk-or-v1-your-api-key-here'; // Replace with actual API key
  static const String _baseUrl = 'https://openrouter.ai/api/v1';

  Future<String> sendMessage(String message, {String? threadId}) async {
    try {
      // For now, return a mock response based on keywords
      // In production, this would make an API call to OpenRouter
      return _generateMockResponse(message);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  String _generateMockResponse(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('hello') || lowerMessage.contains('hi')) {
      return "Hello! I'm the FBLA Assistant. I can help you with information about FBLA events, competitions, membership, and more. What would you like to know?";
    }

    if (lowerMessage.contains('fbla')) {
      return "FBLA (Future Business Leaders of America) is a national career and technical student organization that prepares students for careers in business and business-related fields. We offer competitions, leadership opportunities, and networking events.";
    }

    if (lowerMessage.contains('competition') ||
        lowerMessage.contains('compete')) {
      return "FBLA offers over 70 competitive events in areas like business, technology, and leadership. Popular competitions include Business Plan, Public Speaking, Website Design, and Digital Marketing. Check the Events section for upcoming competitions!";
    }

    if (lowerMessage.contains('event') || lowerMessage.contains('meeting')) {
      return "FBLA hosts various events including chapter meetings, state conferences, and national conferences. You can find upcoming events in the Events section of the app. Don't forget to RSVP!";
    }

    if (lowerMessage.contains('member') || lowerMessage.contains('join')) {
      return "To become an FBLA member, contact your local chapter advisor or visit connect.fbla.org. Membership gives you access to competitions, leadership opportunities, scholarships, and networking events.";
    }

    if (lowerMessage.contains('help')) {
      return "I can help you with:\n• FBLA information and history\n• Competition details and preparation\n• Event schedules and RSVPs\n• Membership information\n• Leadership opportunities\n• Study resources\n\nWhat specific topic interests you?";
    }

    if (lowerMessage.contains('scholarship')) {
      return "FBLA offers several scholarship opportunities for members, including the FBLA National Scholarship Program and various state-level scholarships. Check the Resources section for scholarship applications and requirements.";
    }

    if (lowerMessage.contains('leadership')) {
      return "FBLA provides many leadership opportunities including chapter officer positions, state officer roles, and national leadership positions. Leadership experience in FBLA looks great on college applications and resumes!";
    }

    // Default response
    return "That's an interesting question! While I'm still learning, I can help you with FBLA-related topics like competitions, events, membership, and leadership opportunities. Feel free to ask me about any of these topics!";
  }
}
