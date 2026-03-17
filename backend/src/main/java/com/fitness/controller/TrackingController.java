package com.fitness.controller;

import java.util.List;

import com.fitness.dto.WeightRecordRequest;
import com.fitness.dto.WeightRecordResponse;
import com.fitness.service.AuthService;
import com.fitness.service.TrackingService;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.DefaultValue;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.PUT;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
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
            @Valid WeightRecordRequest request) {
        Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
        WeightRecordResponse response = trackingService.createWeightRecord(userId, request);
        return Response.status(Response.Status.CREATED)
                .entity(response)
                .build();
    }
    
    @GET
    @Path("/me/weight-records")
    public Response getUserWeightRecords(
            @Context HttpHeaders headers,
            @QueryParam("startDate") String startDateStr,
            @QueryParam("endDate") String endDateStr,
            @QueryParam("page") @DefaultValue("0") Integer page,
            @QueryParam("size") @DefaultValue("50") Integer size) {
        
        Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
        
        java.time.LocalDateTime startDate = (startDateStr != null && !startDateStr.isEmpty()) ? java.time.LocalDateTime.parse(startDateStr) : null;
        java.time.LocalDateTime endDate = (endDateStr != null && !endDateStr.isEmpty()) ? java.time.LocalDateTime.parse(endDateStr) : null;
        
        List<WeightRecordResponse> records = trackingService.getUserWeightRecords(userId, startDate, endDate, page, size);
        return Response.ok()
                .entity(records)
                .build();
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
            @Valid WeightRecordRequest request) {
        Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
        WeightRecordResponse response = trackingService.updateWeightRecord(userId, recordId, request);
        return Response.ok()
                .entity(response)
                .build();
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
        Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
        trackingService.deleteWeightRecord(userId, recordId);
        return Response.noContent()
                .build();
    }
}
