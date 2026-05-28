package com.fitness.controller;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.fitness.entity.Notification;
import com.fitness.entity.NotificationDevice;
import com.fitness.entity.User;
import com.fitness.service.AuthService;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.PATCH;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@ApplicationScoped
@Path("/api/notifications")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class NotificationController {

    @Inject
    AuthService authService;

    @GET
    public Response getNotifications(
            @Context HttpHeaders headers,
            @QueryParam("limit") @DefaultValue("50") int limit) {
        try {
            Long userId = resolveUserId(headers);
            int safeLimit = Math.max(1, Math.min(limit, 100));
            List<Notification> notifications = Notification.find(
                    "user.id = ?1 order by createdAt desc", userId)
                    .page(0, safeLimit)
                    .list();
            List<Map<String, Object>> result = notifications.stream()
                    .map(this::toMap)
                    .collect(Collectors.toList());
            return Response.ok(result).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
    }

    @Transactional
    @POST
    @Path("/devices")
    public Response registerDevice(@Context HttpHeaders headers, Map<String, Object> body) {
        try {
            Long userId = resolveUserId(headers);
            String token = stringValue(body, "token");
            String platform = stringValue(body, "platform");
            String appVersion = stringValue(body, "appVersion");
            if (token.isBlank() || platform.isBlank()) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(Map.of("message", "token and platform are required"))
                        .build();
            }

            NotificationDevice device = NotificationDevice.find("token", token).firstResult();
            if (device == null) {
                device = new NotificationDevice();
                device.token = token;
            }
            device.user = User.findById(userId);
            device.platform = platform;
            device.appVersion = appVersion.isBlank() ? null : appVersion;
            device.active = true;
            device.persist();
            return Response.noContent().build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
    }

    @Transactional
    @DELETE
    @Path("/devices")
    public Response unregisterDevice(@Context HttpHeaders headers, Map<String, Object> body) {
        try {
            Long userId = resolveUserId(headers);
            String token = stringValue(body, "token");
            if (token.isBlank()) {
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(Map.of("message", "token is required"))
                        .build();
            }
            NotificationDevice device = NotificationDevice
                    .find("token = ?1 and user.id = ?2", token, userId)
                    .firstResult();
            if (device != null) {
                device.active = false;
                device.persist();
            }
            return Response.noContent().build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
    }

    @GET
    @Path("/unread-count")
    public Response getUnreadCount(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);
            long count = Notification.findUnreadByUser(userId).size();
            return Response.ok(Map.of("count", count)).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
    }

    @Transactional
    @PATCH
    @Path("/{id}/read")
    public Response markAsRead(@Context HttpHeaders headers, @PathParam("id") Long id) {
        try {
            Long userId = resolveUserId(headers);
            Notification n = Notification.findById(id);
            if (n == null || !n.user.id.equals(userId)) {
                return Response.status(Response.Status.NOT_FOUND).build();
            }
            n.isRead = true;
            n.persist();
            return Response.noContent().build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
    }

    private Long resolveUserId(HttpHeaders headers) {
        String authStr = headers.getHeaderString(HttpHeaders.AUTHORIZATION);
        return authService.getUserIdFromToken(authStr);
    }

    private Map<String, Object> toMap(Notification n) {
        Map<String, Object> m = new HashMap<>();
        m.put("id", n.id);
        m.put("title", n.title);
        m.put("message", n.message);
        m.put("isRead", n.isRead);
        m.put("createdAt", n.createdAt != null ? n.createdAt.toString() : null);
        m.put("type", n.type);
        return m;
    }

    private String stringValue(Map<String, Object> body, String key) {
        if (body == null || body.get(key) == null) return "";
        return body.get(key).toString().trim();
    }
}
