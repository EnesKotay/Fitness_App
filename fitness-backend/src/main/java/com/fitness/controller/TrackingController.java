package com.fitness.controller;

import java.util.List;

import com.fitness.dto.WeightRecordRequest;
import com.fitness.dto.WeightRecordResponse;
import com.fitness.service.AuthService;
import com.fitness.service.TrackingService;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.Context;

@ApplicationScoped
@Path("/api/tracking")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class TrackingController {
    
    @Inject
    TrackingService trackingService;

    @Inject
    AuthService authService;
    
    /**
     * Yeni kilo kaydı oluştur
     * POST /api/tracking/me/weight-records
     */
    @POST
    @Path("/me/weight-records")
    public Response createWeightRecord(
            @Context HttpHeaders headers,
            WeightRecordRequest request) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            WeightRecordResponse response = trackingService.createWeightRecord(userId, request);
            return Response.status(Response.Status.CREATED)
                    .entity(response)
                    .build();
        } catch (RuntimeException e) {
            if (isAuthFailure(e)) {
                return Response.status(Response.Status.UNAUTHORIZED).entity("{\"error\": \"Oturum geçersiz.\"}").build();
            }
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"" + escape(e.getMessage()) + "\"}")
                    .build();
        }
    }
    
    /**
     * Kullanıcının tüm kilo kayıtlarını getir
     * GET /api/tracking/me/weight-records
     */
    @GET
    @Path("/me/weight-records")
    public Response getUserWeightRecords(@Context HttpHeaders headers) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            List<WeightRecordResponse> records = trackingService.getUserWeightRecords(userId);
            return Response.ok()
                    .entity(records)
                    .build();
        } catch (RuntimeException e) {
            if (isAuthFailure(e)) {
                return Response.status(Response.Status.UNAUTHORIZED).entity("{\"error\": \"Oturum geçersiz.\"}").build();
            }
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("{\"error\": \"" + escape(e.getMessage()) + "\"}")
                    .build();
        }
    }
    
    /**
     * Kilo kaydını güncelle
     * PUT /api/tracking/me/weight-records/{recordId}
     */
    @PUT
    @Path("/me/weight-records/{recordId}")
    public Response updateWeightRecord(
            @Context HttpHeaders headers,
            @PathParam("recordId") Long recordId,
            WeightRecordRequest request) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            WeightRecordResponse response = trackingService.updateWeightRecord(userId, recordId, request);
            return Response.ok()
                    .entity(response)
                    .build();
        } catch (RuntimeException e) {
            if (isAuthFailure(e)) {
                return Response.status(Response.Status.UNAUTHORIZED).entity("{\"error\": \"Oturum geçersiz.\"}").build();
            }
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"" + escape(e.getMessage()) + "\"}")
                    .build();
        }
    }
    
    /**
     * Kilo kaydını sil
     * DELETE /api/tracking/me/weight-records/{recordId}
     */
    @DELETE
    @Path("/me/weight-records/{recordId}")
    public Response deleteWeightRecord(
            @Context HttpHeaders headers,
            @PathParam("recordId") Long recordId) {
        try {
            Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
            trackingService.deleteWeightRecord(userId, recordId);
            return Response.noContent()
                    .build();
        } catch (RuntimeException e) {
            if (isAuthFailure(e)) {
                return Response.status(Response.Status.UNAUTHORIZED).entity("{\"error\": \"Oturum geçersiz.\"}").build();
            }
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("{\"error\": \"" + escape(e.getMessage()) + "\"}")
                    .build();
        }
    }

    private static boolean isAuthFailure(RuntimeException e) {
        String m = e.getMessage();
        return m != null && (m.contains("Authorization") || m.contains("Token") || m.contains("Geçersiz token"));
    }

    private static String escape(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
    }
}
