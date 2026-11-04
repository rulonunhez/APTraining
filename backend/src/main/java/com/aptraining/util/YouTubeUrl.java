package com.aptraining.util;

import java.net.URI;
import java.net.URISyntaxException;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;

public final class YouTubeUrl {

    private static final Pattern VIDEO_ID = Pattern.compile("[A-Za-z0-9_-]{11}");
    private static final Set<String> YOUTUBE_HOSTS = Set.of(
            "youtube.com",
            "www.youtube.com",
            "m.youtube.com",
            "music.youtube.com",
            "youtu.be",
            "www.youtu.be"
    );

    private YouTubeUrl() {
    }

    public static boolean isValid(String value) {
        return extractVideoId(value) != null;
    }

    public static String extractVideoId(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }

        try {
            URI uri = new URI(value.trim());
            if (!"https".equalsIgnoreCase(uri.getScheme())
                    || uri.getUserInfo() != null
                    || uri.getPort() != -1
                    || uri.getHost() == null
                    || !YOUTUBE_HOSTS.contains(uri.getHost().toLowerCase(Locale.ROOT))) {
                return null;
            }

            String videoId = null;
            String host = uri.getHost().toLowerCase(Locale.ROOT);
            String[] pathSegments = uri.getPath().split("/");
            if (host.equals("youtu.be") || host.equals("www.youtu.be")) {
                videoId = pathSegments.length > 1 ? pathSegments[1] : null;
            } else if ("/watch".equals(uri.getPath())) {
                String query = uri.getRawQuery();
                if (query != null) {
                    for (String parameter : query.split("&")) {
                        String[] pair = parameter.split("=", 2);
                        if (pair.length == 2 && "v".equals(pair[0])) {
                            videoId = pair[1];
                            break;
                        }
                    }
                }
            } else if (pathSegments.length > 2
                    && Set.of("embed", "shorts", "live", "v").contains(pathSegments[1])) {
                videoId = pathSegments[2];
            }

            return videoId != null && VIDEO_ID.matcher(videoId).matches() ? videoId : null;
        } catch (URISyntaxException exception) {
            return null;
        }
    }
}