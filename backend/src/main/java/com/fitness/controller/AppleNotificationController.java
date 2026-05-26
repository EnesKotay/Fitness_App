package com.fitness.controller;

import com.fitness.service.AppleNotificationService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.jboss.logging.Logger;

import java.util.Map;

/**
 * Apple App Store Server Notifications V2 webhook endpoint.
 *
 * App Store Connect → Apps → [Uygulamanı] → Subscriptions →
 *   App Store Server Notifications → Production / Sandbox URL:
 *     https://<backend-domain>/api/apple/notifications
 *
 * Apple, bildirim gönderdiğinde hızlıca 200 döndürülmeli (5sn içinde).
 * Yeniden deneme: Apple başarısız istekleri üstel geri-çekilmeyle tekrar dener.
 */
@ApplicationScoped
@Path("/api/apple/notifications")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class AppleNotificationController {

    private static final Logger LOG = Logger.getLogger(AppleNotificationController.class);

    @Inject
    AppleNotificationService notificationService;

    @POST
    public Response receive(Map<String, Object> body) {
        try {
            Object signedPayload = body != null ? body.get("signedPayload") : null;
            if (signedPayload == null || signedPayload.toString().isBlank()) {
                LOG.warn("Apple bildirimi: signedPayload eksik");
                return Response.status(Response.Status.BAD_REQUEST)
                        .entity(Map.of("error", "signedPayload gerekli"))
                        .build();
            }

            // İşlemi asenkron değil senkron yap — Apple'ın zaman aşımı 5sn,
            // DB işlemi bunun içinde kalır.
            boolean ok = notificationService.process(signedPayload.toString());
            if (ok) {
                return Response.ok(Map.of("status", "ok")).build();
            } else {
                // 200 dön ama logla — Apple tekrar denemez, biz inceliyoruz.
                return Response.ok(Map.of("status", "skipped")).build();
            }
        } catch (Exception e) {
            LOG.errorf(e, "Apple bildirim endpoint hatası");
            // 500 → Apple tekrar dener (istenmiyorsa 200 dön)
            return Response.serverError()
                    .entity(Map.of("error", "İşlem başarısız"))
                    .build();
        }
    }
}
