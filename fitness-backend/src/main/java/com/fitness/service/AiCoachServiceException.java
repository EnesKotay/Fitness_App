package com.fitness.service;

public class AiCoachServiceException extends RuntimeException {

    private final int statusCode;
    private final Integer retryAfterSeconds;

    public AiCoachServiceException(int statusCode, String message) {
        this(statusCode, message, null, null);
    }

    public AiCoachServiceException(int statusCode, String message, Integer retryAfterSeconds) {
        this(statusCode, message, retryAfterSeconds, null);
    }

    public AiCoachServiceException(int statusCode, String message, Throwable cause) {
        this(statusCode, message, null, cause);
    }

    public AiCoachServiceException(int statusCode, String message, Integer retryAfterSeconds, Throwable cause) {
        super(message, cause);
        this.statusCode = statusCode;
        this.retryAfterSeconds = retryAfterSeconds;
    }

    public int getStatusCode() {
        return statusCode;
    }

    public Integer getRetryAfterSeconds() {
        return retryAfterSeconds;
    }
}
