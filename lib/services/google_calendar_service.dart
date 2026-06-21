import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Google Calendar and builds add-event URLs (no extra OAuth scopes).
class GoogleCalendarService {
  static Future<bool> openCalendar() async {
    final uri = Uri.parse('https://calendar.google.com/calendar/r');
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> addEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
    String? location,
  }) async {
    final fmt = DateFormat("yyyyMMdd'T'HHmmss'Z'");
    final startStr = fmt.format(start.toUtc());
    final endStr = fmt.format(end.toUtc());
    final params = <String, String>{
      'action': 'TEMPLATE',
      'text': title,
      'dates': '$startStr/$endStr',
    };
    if (description != null && description.isNotEmpty) {
      params['details'] = description;
    }
    if (location != null && location.isNotEmpty) {
      params['location'] = location;
    }
    final uri = Uri.https('calendar.google.com', '/calendar/render', params);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
