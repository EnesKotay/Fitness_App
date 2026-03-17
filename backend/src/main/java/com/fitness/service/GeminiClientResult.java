package com.fitness.service;

import java.time.Instant;

/**
 * Result object returned by GeminiClient after a generation call.
 * Contains the generated text, metadata about the call, and any error information.
 */
public class GeminiClientResult {

    private String modelUsed;
    private String outputText;
    private long latencyMs;
    private int statusCode;
    private String error;
    private Integer retryAfterSeconds;
    private Instant timestamp;

    public GeminiClientResult() {
        this.timestamp = Instant.now();
    }

    public static Builder builder() {
        return new Builder();
    }

    // Getters and setters
    public String getModelUsed() {
        return modelUsed;
    }

    public void setModelUsed(String modelUsed) {
        this.modelUsed = modelUsed;
    }

    public String getOutputText() {
        return outputText;
    }

    public void setOutputText(String outputText) {
        this.outputText = outputText;
    }

    public long getLatencyMs() {
        return latencyMs;
    }

    public void setLatencyMs(long latencyMs) {
        this.latencyMs = latencyMs;
    }

    public int getStatusCode() {
        return statusCode;
    }

    public void setStatusCode(int statusCode) {
        this.statusCode = statusCode;
    }

    public String getError() {
        return error;
    }

    public void setError(String error) {
        this.error = error;
    }

    public Instant getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(Instant timestamp) {
        this.timestamp = timestamp;
    }

    public Integer getRetryAfterSeconds() {
        return retryAfterSeconds;
    }

    public void setRetryAfterSeconds(Integer retryAfterSeconds) {
        this.retryAfterSeconds = retryAfterSeconds;
    }

    public boolean isSuccess() {
        return error == null && statusCode >= 200 && statusCode < 300;
    }

    public static class Builder {
        private final GeminiClientResult result = new GeminiClientResult();

        public Builder modelUsed(String modelUsed) {
            result.modelUsed = modelUsed;
            return this;
        }

        public Builder outputText(String outputText) {
            result.outputText = outputText;
            return this;
        }

        public Builder latencyMs(long latencyMs) {
            result.latencyMs = latencyMs;
            return this;
        }

        public Builder statusCode(int statusCode) {
            result.statusCode = statusCode;
            return this;
        }

        public Builder error(String error) {
            result.error = error;
            return this;
        }

        public Builder retryAfterSeconds(Integer retryAfterSeconds) {
            result.retryAfterSeconds = retryAfterSeconds;
            return this;
        }

        public Builder success(String modelUsed, String outputText, long latencyMs) {
            result.modelUsed = modelUsed;
            result.outputText = outputText;
            result.latencyMs = latencyMs;
            result.statusCode = 200;
            result.retryAfterSeconds = null;
            return this;
        }

        public Builder failure(String modelUsed, int statusCode, String error, long latencyMs) {
            return failure(modelUsed, statusCode, error, latencyMs, null);
        }

        public Builder failure(String modelUsed, int statusCode, String error, long latencyMs, Integer retryAfterSeconds) {
            result.modelUsed = modelUsed;
            result.statusCode = statusCode;
            result.error = error;
            result.latencyMs = latencyMs;
            result.retryAfterSeconds = retryAfterSeconds;
            return this;
        }

        public GeminiClientResult build() {
            return result;
        }
    }
}
