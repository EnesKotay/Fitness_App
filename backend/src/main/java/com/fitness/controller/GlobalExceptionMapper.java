package com.fitness.controller;

import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;
import org.jboss.logging.Logger;

@Provider
public class GlobalExceptionMapper implements ExceptionMapper<RuntimeException> {

    private static final Logger LOG = Logger.getLogger(GlobalExceptionMapper.class);

    @Override
    public Response toResponse(RuntimeException exception) {
        LOG.errorf("Uncaught Exception: %s", exception.getMessage(), exception);
        
        // Return 400 Bad Request by default for our custom validation exceptions mapped as RuntimeException
        // You might want to distinguish between 400 and 500 later with custom Exception classes.
        int status = Response.Status.BAD_REQUEST.getStatusCode();

        String msg = exception.getMessage();
        String msgLower = msg != null ? msg.toLowerCase() : "";

        if (msg != null && msg.contains("bulunamadı")) {
            status = Response.Status.NOT_FOUND.getStatusCode();
        } else if (msgLower.contains("yetki") || msgLower.contains("unauthorized")
                || msgLower.contains("geçersiz token") || msgLower.contains("gecersiz token")
                || msgLower.contains("jwt expired") || msgLower.contains("token expired")
                || msgLower.contains("token subject") || msgLower.contains("token boş")) {
            status = Response.Status.UNAUTHORIZED.getStatusCode();
        }

        String jsonError = String.format("{\"error\": \"%s\"}", escapeJson(exception.getMessage()));
        
        return Response.status(status)
                .entity(jsonError)
                .type("application/json")
                .build();
    }

    private String escapeJson(String s) {
        if (s == null) return "Bilinmeyen hata oluştu.";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
    }
}
