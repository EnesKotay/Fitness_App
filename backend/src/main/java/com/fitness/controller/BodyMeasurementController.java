package com.fitness.controller;

import com.fitness.dto.BodyMeasurementRequest;
import com.fitness.dto.BodyMeasurementResponse;
import com.fitness.service.AuthService;
import com.fitness.service.BodyMeasurementService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.validation.Valid;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.HttpHeaders;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.List;

@ApplicationScoped
@Path("/api/tracking")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class BodyMeasurementController {

    @Inject
    BodyMeasurementService measurementService;

    @Inject
    AuthService authService;

    @POST
    @Path("/me/measurements")
    public Response createMeasurement(@Context HttpHeaders headers, @Valid BodyMeasurementRequest request) {
        Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
        BodyMeasurementResponse response = measurementService.createMeasurement(userId, request);
        return Response.status(Response.Status.CREATED).entity(response).build();
    }

    @GET
    @Path("/me/measurements")
    public Response getUserMeasurements(
            @Context HttpHeaders headers,
            @QueryParam("startDate") String startDateStr,
            @QueryParam("endDate") String endDateStr,
            @QueryParam("page") @DefaultValue("0") Integer page,
            @QueryParam("size") @DefaultValue("50") Integer size) {
        
        Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
        
        java.time.LocalDate startDate = (startDateStr != null && !startDateStr.isEmpty()) ? java.time.LocalDate.parse(startDateStr) : null;
        java.time.LocalDate endDate = (endDateStr != null && !endDateStr.isEmpty()) ? java.time.LocalDate.parse(endDateStr) : null;
        
        List<BodyMeasurementResponse> records = measurementService.getUserMeasurements(userId, startDate, endDate, page, size);
        return Response.ok().entity(records).build();
    }

    @PUT
    @Path("/me/measurements/{id}")
    public Response updateMeasurement(@Context HttpHeaders headers, @PathParam("id") Long id,
            @Valid BodyMeasurementRequest request) {
        Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
        BodyMeasurementResponse response = measurementService.updateMeasurement(userId, id, request);
        return Response.ok().entity(response).build();
    }

    @DELETE
    @Path("/me/measurements/{id}")
    public Response deleteMeasurement(@Context HttpHeaders headers, @PathParam("id") Long id) {
        Long userId = authService.getUserIdFromToken(headers.getHeaderString(HttpHeaders.AUTHORIZATION));
        measurementService.deleteMeasurement(userId, id);
        return Response.noContent().build();
    }
}
