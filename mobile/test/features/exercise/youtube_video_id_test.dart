import 'package:flutter_test/flutter_test.dart';
import 'package:ap_training/features/exercise/utils/youtube_video_id.dart';

void main() {
  group('youtubeVideoIdFromUrl', () {
    test('accepts common YouTube video URL forms', () {
      expect(
        youtubeVideoIdFromUrl(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        'dQw4w9WgXcQ',
      );
      expect(
        youtubeVideoIdFromUrl('https://youtu.be/dQw4w9WgXcQ?t=15'),
        'dQw4w9WgXcQ',
      );
      expect(
        youtubeVideoIdFromUrl(
          'https://m.youtube.com/shorts/dQw4w9WgXcQ',
        ),
        'dQw4w9WgXcQ',
      );
      expect(
        youtubeVideoIdFromUrl(
          'https://www.youtube.com/embed/dQw4w9WgXcQ',
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('rejects non-YouTube or malformed URLs', () {
      expect(youtubeVideoIdFromUrl(null), isNull);
      expect(youtubeVideoIdFromUrl(''), isNull);
      expect(
        youtubeVideoIdFromUrl('https://example.com/watch?v=dQw4w9WgXcQ'),
        isNull,
      );
      expect(
        youtubeVideoIdFromUrl('http://youtube.com/watch?v=dQw4w9WgXcQ'),
        isNull,
      );
      expect(
        youtubeVideoIdFromUrl(
            'https://youtube.com.evil.test/watch?v=dQw4w9WgXcQ'),
        isNull,
      );
      expect(
        youtubeVideoIdFromUrl('https://youtube.com/watch?v=invalid'),
        isNull,
      );
    });
  });
}
