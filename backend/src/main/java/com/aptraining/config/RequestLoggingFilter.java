package com.aptraining.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;
import java.util.regex.Pattern;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestLoggingFilter extends OncePerRequestFilter {

    public static final String REQUEST_ID_ATTRIBUTE = RequestLoggingFilter.class.getName() + ".requestId";
    public static final String REQUEST_ID_HEADER = "X-Request-Id";

    private static final Logger logger = LoggerFactory.getLogger(RequestLoggingFilter.class);
    private static final Pattern SAFE_REQUEST_ID = Pattern.compile("[A-Za-z0-9-]{1,64}");

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String requestId = getOrCreateRequestId(request);
        long startedAt = System.nanoTime();
        MDC.put("requestId", requestId);
        request.setAttribute(REQUEST_ID_ATTRIBUTE, requestId);
        response.setHeader(REQUEST_ID_HEADER, requestId);

        try {
            filterChain.doFilter(request, response);
        } finally {
            long durationMs = (System.nanoTime() - startedAt) / 1_000_000;
            int status = response.getStatus();
            if (status >= 500) {
                logger.error("HTTP request completed method={} path={} status={} durationMs={}",
                        request.getMethod(), request.getRequestURI(), status, durationMs);
            } else if (status >= 400) {
                logger.warn("HTTP request completed method={} path={} status={} durationMs={}",
                        request.getMethod(), request.getRequestURI(), status, durationMs);
            } else if (logger.isDebugEnabled()) {
                logger.debug("HTTP request completed method={} path={} status={} durationMs={}",
                        request.getMethod(), request.getRequestURI(), status, durationMs);
            }
            MDC.remove("requestId");
        }
    }

    private String getOrCreateRequestId(HttpServletRequest request) {
        String suppliedRequestId = request.getHeader(REQUEST_ID_HEADER);
        if (suppliedRequestId != null && SAFE_REQUEST_ID.matcher(suppliedRequestId).matches()) {
            return suppliedRequestId;
        }
        return UUID.randomUUID().toString();
    }
}
