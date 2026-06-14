import 'package:flutter_test/flutter_test.dart';
import 'package:fbla_member_app/models/video_model.dart';
import 'package:fbla_member_app/models/practice_record.dart';
import 'package:fbla_member_app/ai/models/chat_message_model.dart';

void main() {
  group('Video.fromPlaylistItem', () {
    test('parses a well-formed playlist item', () {
      final video = Video.fromPlaylistItem({
        'contentDetails': {'videoId': 'abc123'},
        'snippet': {
          'title': 'FBLA Nationals Recap',
          'description': 'Highlights',
          'publishedAt': '2026-06-01T12:00:00Z',
          'thumbnails': {
            'high': {'url': 'https://img/high.jpg'},
            'default': {'url': 'https://img/default.jpg'},
          },
        },
      });

      expect(video.id, 'abc123');
      expect(video.title, 'FBLA Nationals Recap');
      expect(video.description, 'Highlights');
      expect(video.thumbnailUrl, 'https://img/high.jpg');
      expect(video.publishedAt.toUtc().year, 2026);
    });

    test('falls back to resourceId videoId and lower thumbnails', () {
      final video = Video.fromPlaylistItem({
        'snippet': {
          'title': 'No content details',
          'resourceId': {'videoId': 'fromResource'},
          'thumbnails': {
            'default': {'url': 'https://img/default.jpg'},
          },
        },
      });

      expect(video.id, 'fromResource');
      expect(video.thumbnailUrl, 'https://img/default.jpg');
    });

    test('tolerates missing fields without throwing', () {
      final video = Video.fromPlaylistItem({});
      expect(video.id, '');
      expect(video.title, '');
      expect(video.thumbnailUrl, '');
      // Invalid/absent publishedAt falls back to "now" — just ensure non-null.
      expect(video.publishedAt, isA<DateTime>());
    });
  });

  group('ChatMessageModel serialization', () {
    test('toJson maps the "model" role to "assistant"', () {
      final msg = ChatMessageModel(role: 'model', content: 'hi');
      expect(msg.toJson(), {'role': 'assistant', 'content': 'hi'});
    });

    test('round-trips user and assistant messages', () {
      final user = ChatMessageModel.user('Hello');
      final back = ChatMessageModel.fromJson(user.toJson());
      expect(back.role, 'user');
      expect(back.content, 'Hello');

      final assistant = ChatMessageModel.assistant('Hi there');
      final back2 = ChatMessageModel.fromJson(assistant.toJson());
      expect(back2.role, 'assistant');
      expect(back2.content, 'Hi there');
    });
  });

  group('PracticeRecord serialization', () {
    test('round-trips a coach record', () {
      final record = PracticeRecord(
        eventName: 'Public Speaking',
        category: 'Presentation',
        type: 'coach',
        timestamp: DateTime.parse('2026-06-14T10:30:00'),
        aiFeedback: 'Great hook.',
      );
      final back = PracticeRecord.fromJson(record.toJson());

      expect(back.eventName, 'Public Speaking');
      expect(back.category, 'Presentation');
      expect(back.isCoach, isTrue);
      expect(back.aiFeedback, 'Great hook.');
      expect(back.timestamp, DateTime.parse('2026-06-14T10:30:00'));
    });

    test('round-trips a record (self-assessment) with rubric scores', () {
      final record = PracticeRecord(
        eventName: 'Marketing',
        category: 'Roleplay',
        type: 'record',
        timestamp: DateTime.parse('2026-06-14T11:00:00'),
        rubricChecked: 4,
        rubricTotal: 6,
      );
      final back = PracticeRecord.fromJson(record.toJson());

      expect(back.isRecord, isTrue);
      expect(back.rubricChecked, 4);
      expect(back.rubricTotal, 6);
    });
  });
}
