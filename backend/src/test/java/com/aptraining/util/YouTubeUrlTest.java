package com.aptraining.util;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class YouTubeUrlTest {

    @Test
    void acceptsSupportedYouTubeUrlFormats() {
        assertTrue(YouTubeUrl.isValid("https://www.youtube.com/watch?v=dQw4w9WgXcQ"));
        assertTrue(YouTubeUrl.isValid("https://youtu.be/dQw4w9WgXcQ?t=15"));
        assertTrue(YouTubeUrl.isValid("https://m.youtube.com/shorts/dQw4w9WgXcQ"));
        assertTrue(YouTubeUrl.isValid("https://youtube.com/embed/dQw4w9WgXcQ"));
        assertEquals("dQw4w9WgXcQ",
                YouTubeUrl.extractVideoId("https://www.youtube.com/watch?v=dQw4w9WgXcQ"));
    }

    @Test
    void rejectsNonYouTubeAndMalformedUrls() {
        assertFalse(YouTubeUrl.isValid("https://example.com/watch?v=dQw4w9WgXcQ"));
        assertFalse(YouTubeUrl.isValid("http://youtube.com/watch?v=dQw4w9WgXcQ"));
        assertFalse(YouTubeUrl.isValid("https://youtube.com.evil.test/watch?v=dQw4w9WgXcQ"));
        assertFalse(YouTubeUrl.isValid("https://youtube.com/watch?v=invalid"));
        assertFalse(YouTubeUrl.isValid(null));
    }
}