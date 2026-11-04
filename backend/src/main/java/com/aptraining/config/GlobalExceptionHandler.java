package com.aptraining.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import software.amazon.awssdk.core.exception.SdkException;
import jakarta.servlet.http.HttpServletRequest;

import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger logger = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<?> handleAccessDenied(
            AccessDeniedException ex,
            HttpServletRequest request
    ) {
        String requestId = requestId(request);
        logger.warn("Request denied requestId={} method={} path={} exception={} message={}",
                requestId, request.getMethod(), request.getRequestURI(),
                ex.getClass().getSimpleName(), ex.getMessage());
        return ResponseEntity.status(403).body(errorBody(
                safeMessage(ex.getMessage(), "Access denied"), requestId));
    }

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<?> handleRuntime(
            RuntimeException ex,
            HttpServletRequest request
    ) {
        String requestId = requestId(request);
        logger.warn("Request rejected requestId={} method={} path={} exception={} message={}",
                requestId, request.getMethod(), request.getRequestURI(),
                ex.getClass().getSimpleName(), ex.getMessage());
        return ResponseEntity.badRequest().body(errorBody(
                safeMessage(ex.getMessage(), "Invalid request"), requestId));
    }

    @ExceptionHandler(UsernameNotFoundException.class)
    public ResponseEntity<?> handleUserNotFound(
            Exception ex,
            HttpServletRequest request
    ) {
        String requestId = requestId(request);
        logger.warn("User not found requestId={} method={} path={} exception={} message={}",
                requestId, request.getMethod(), request.getRequestURI(),
                ex.getClass().getSimpleName(), ex.getMessage());
        return ResponseEntity.status(404).body(errorBody(
                safeMessage(ex.getMessage(), "User not found"), requestId));
    }

    @ExceptionHandler({StorageOperationException.class, SdkException.class})
    public ResponseEntity<?> handleStorageFailure(
            RuntimeException ex,
            HttpServletRequest request
    ) {
        String requestId = requestId(request);
        logger.error("Storage operation failed requestId={} method={} path={} exception={} message={}",
                requestId, request.getMethod(), request.getRequestURI(),
                ex.getClass().getSimpleName(), ex.getMessage(), ex);
        return ResponseEntity.status(502).body(errorBody(
                "No se pudo completar la operación de almacenamiento", requestId));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<?> handleGeneric(
            Exception ex,
            HttpServletRequest request
    ) {
        String requestId = requestId(request);
        logger.error("Unhandled request failure requestId={} method={} path={} exception={} message={}",
                requestId, request.getMethod(), request.getRequestURI(),
                ex.getClass().getSimpleName(), ex.getMessage(), ex);
        return ResponseEntity.internalServerError().body(errorBody("Internal error", requestId));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<?> handleMaxSize(
            MaxUploadSizeExceededException ex,
            HttpServletRequest request
    ) {
        String requestId = requestId(request);
        logger.warn("Upload exceeds configured size limit requestId={} method={} path={} exception={} message={}",
                requestId, request.getMethod(), request.getRequestURI(),
                ex.getClass().getSimpleName(), ex.getMessage());
        return ResponseEntity.status(413).body(errorBody("File too large", requestId));
    }

    private String requestId(HttpServletRequest request) {
        Object requestId = request.getAttribute(RequestLoggingFilter.REQUEST_ID_ATTRIBUTE);
        return requestId instanceof String value ? value : "unknown";
    }

    private Map<String, String> errorBody(String message, String requestId) {
        return Map.of("error", message, "requestId", requestId);
    }

    private String safeMessage(String message, String fallback) {
        return message == null || message.isBlank() ? fallback : message;
    }
}
