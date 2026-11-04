/// YouTube Shorts are vertical videos; their URLs use the `/shorts/` path.
bool isYoutubeShortsUrl(String? value) {
  if (youtubeVideoIdFromUrl(value) == null) return false;
  final segments = Uri.parse(value!.trim()).pathSegments;
  return segments.isNotEmpty && segments.first == 'shorts';
}

String? youtubeVideoIdFromUrl(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    return null;
  }

  final host = uri.host.toLowerCase();
  String? videoId;

  if (host == 'youtu.be' || host == 'www.youtu.be') {
    videoId = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  } else if (host == 'youtube.com' ||
      host == 'www.youtube.com' ||
      host == 'm.youtube.com' ||
      host == 'music.youtube.com') {
    if (uri.path == '/watch') {
      videoId = uri.queryParameters['v'];
    } else if (uri.pathSegments.length >= 2 &&
        const {'embed', 'shorts', 'live', 'v'}.contains(uri.pathSegments[0])) {
      videoId = uri.pathSegments[1];
    }
  }

  if (videoId == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) {
    return null;
  }
  return videoId;
}