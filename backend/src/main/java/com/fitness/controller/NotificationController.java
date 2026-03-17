package com.fitness.controller;

import java.util.List;

import com.fitness.entity.Notification;
import com.fitness.service.AuthService;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.PATCH;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
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
    public Response getNotifications(@Context HttpHeaders headers) {
        try {
            Long userId = resolveUserId(headers);
            List<Notification> notifications = Notification.find("user.id = ?1 order by createdAt desc", userId).list();
            return Response.ok(notifications).build();
        } catch (SecurityException e) {
            return Response.status(Response.Status.UNAUTHORIZED).build();
        }
    }

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
}
