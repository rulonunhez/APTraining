package com.aptraining.config;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class GlobalExceptionHandlerTest {

    @Test
    void accessDeniedIsMappedToForbidden() {
        GlobalExceptionHandler handler = new GlobalExceptionHandler();
        MockHttpServletRequest request = requestWithId("request-123");

        ResponseEntity<?> response = handler.handleAccessDenied(
                new AccessDeniedException("You cannot delete this exercise"),
                request
        );

        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        assertEquals(
                Map.of("error", "You cannot delete this exercise", "requestId", "request-123"),
                response.getBody()
        );
    }

    @Test
    void storageFailuresReturnGatewayErrorAndRequestId() {
        GlobalExceptionHandler handler = new GlobalExceptionHandler();
        MockHttpServletRequest request = requestWithId("upload-123");

        ResponseEntity<?> response = handler.handleStorageFailure(
                new StorageOperationException("storage failure", new IllegalStateException()),
                request
        );

        assertEquals(HttpStatus.BAD_GATEWAY, response.getStatusCode());
        assertEquals(
                Map.of(
                        "error", "No se pudo completar la operación de almacenamiento",
                        "requestId", "upload-123"
                ),
                response.getBody()
        );
    }

    @Test
    void runtimeExceptionLogIncludesExceptionClassAndMessage() {
        ListAppender<ILoggingEvent> appender = attachLogAppender();

        try {
            GlobalExceptionHandler handler = new GlobalExceptionHandler();
            MockHttpServletRequest request = requestWithId("request-456");

            ResponseEntity<?> response = handler.handleRuntime(
                    new RuntimeException("Plan name is required and must not exceed 255 characters"),
                    request
            );

            assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        } finally {
            detachLogAppender(appender);
        }

        assertEquals(1, appender.list.size());
        String loggedMessage = appender.list.get(0).getFormattedMessage();
        assertTrue(loggedMessage.contains("exception=RuntimeException"));
        assertTrue(loggedMessage.contains(
                "message=Plan name is required and must not exceed 255 characters"));
    }

    @Test
    void storageFailureLogRetainsStackTrace() {
        ListAppender<ILoggingEvent> appender = attachLogAppender();

        try {
            GlobalExceptionHandler handler = new GlobalExceptionHandler();
            handler.handleStorageFailure(
                    new StorageOperationException("storage failure", new IllegalStateException()),
                    requestWithId("upload-123")
            );
        } finally {
            detachLogAppender(appender);
        }

        assertEquals(1, appender.list.size());
        ILoggingEvent event = appender.list.get(0);
        assertTrue(event.getFormattedMessage().contains("exception=StorageOperationException"));
        assertTrue(event.getFormattedMessage().contains("message=storage failure"));
        assertNotNull(event.getThrowableProxy());
    }

    private ListAppender<ILoggingEvent> attachLogAppender() {
        Logger logger = (Logger) LoggerFactory.getLogger(GlobalExceptionHandler.class);
        ListAppender<ILoggingEvent> appender = new ListAppender<>();
        appender.start();
        logger.addAppender(appender);
        return appender;
    }

    private void detachLogAppender(ListAppender<ILoggingEvent> appender) {
        ((Logger) LoggerFactory.getLogger(GlobalExceptionHandler.class)).detachAppender(appender);
        appender.stop();
    }

    private MockHttpServletRequest requestWithId(String requestId) {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/exercises");
        request.setAttribute(RequestLoggingFilter.REQUEST_ID_ATTRIBUTE, requestId);
        return request;
    }
}