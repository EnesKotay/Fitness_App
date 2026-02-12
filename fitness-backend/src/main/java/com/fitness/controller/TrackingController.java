package com.fitness.controller;

import java.util.List;

import com.fitness.dto.WeightRecordRequest;
import com.fitness.dto.WeightRecordResponse;
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
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@ApplicationScoped
@Path("/api/tracking")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class TrackingController {
    
    @Inject
    TrackingService trackingService;
    
    /**
     * Yeni kilo kaydı oluştur
     * POST /api/tracking/users/{userId}/weight-records
     */
    @POST
    @Path("/users/{userId}/weight-records")
    public Response createWeightRecord(
            @PathParam("userId") Long userId,
            WeightRecordRequest request) {
        try {
            WeightRecordResponse response = trackingService.createWeightRecord(userId, request);
            return Response.status(Response.Status.CREATED)
                    .entity(response)
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }
    
    /**
     * Kullanıcının tüm kilo kayıtlarını getir
     * GET /api/tracking/users/{userId}/weight-records
     */
    @GET
    @Path("/users/{userId}/weight-records")
    public Response getUserWeightRecords(@PathParam("userId") Long userId) {
        try {
            List<WeightRecordResponse> records = trackingService.getUserWeightRecords(userId);
            return Response.ok()
                    .entity(records)
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }
    
    /**
     * Kilo kaydını güncelle
     * PUT /api/tracking/users/{userId}/weight-records/{recordId}
     */
    @PUT
    @Path("/users/{userId}/weight-records/{recordId}")
    public Response updateWeightRecord(
            @PathParam("userId") Long userId,
            @PathParam("recordId") Long recordId,
            WeightRecordRequest request) {
        try {
            WeightRecordResponse response = trackingService.updateWeightRecord(userId, recordId, request);
            return Response.ok()
                    .entity(response)
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }
    
    /**
     * Kilo kaydını sil
     * DELETE /api/tracking/users/{userId}/weight-records/{recordId}
     */
    @DELETE
    @Path("/users/{userId}/weight-records/{recordId}")
    public Response deleteWeightRecord(
            @PathParam("userId") Long userId,
            @PathParam("recordId") Long recordId) {
        try {
            trackingService.deleteWeightRecord(userId, recordId);
            return Response.noContent()
                    .build();
        } catch (RuntimeException e) {
            return Response.status(Response.Status.NOT_FOUND)
                    .entity("{\"error\": \"" + e.getMessage() + "\"}")
                    .build();
        }
    }
}