package com.aptraining.config;

import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class RequestLoggingFilterTest {

    private final RequestLoggingFilter filter = new RequestLoggingFilter();

    @Test
    void echoesSafeClientRequestIdAndClearsMdcAfterRequest() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/exercises");
        request.addHeader(RequestLoggingFilter.REQUEST_ID_HEADER, "mobile-request-123");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, successfulChain());

        assertEquals("mobile-request-123",
                response.getHeader(RequestLoggingFilter.REQUEST_ID_HEADER));
        assertEquals("mobile-request-123",
                request.getAttribute(RequestLoggingFilter.REQUEST_ID_ATTRIBUTE));
        assertNull(MDC.get("requestId"));
    }

    @Test
    void replacesInvalidClientRequestIdWithGeneratedId() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/exercises");
        request.addHeader(RequestLoggingFilter.REQUEST_ID_HEADER, "invalid\nid");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, successfulChain());

        String requestId = response.getHeader(RequestLoggingFilter.REQUEST_ID_HEADER);
        UUID.fromString(requestId);
        assertEquals(requestId, request.getAttribute(RequestLoggingFilter.REQUEST_ID_ATTRIBUTE));
        assertNull(MDC.get("requestId"));
    }

    private FilterChain successfulChain() {
        return (request, response) -> ((MockHttpServletResponse) response).setStatus(200);
    }
}
