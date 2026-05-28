package com.fitness.service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fitness.entity.NotificationDevice;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@ApplicationScoped
public class PushNotificationService {

    private static final Logger LOG = Logger.getLogger(PushNotificationService.class);

    @ConfigProperty(name = "push.fcm.server-key")
    Optional<String> fcmServerKey;

    @ConfigProperty(name = "push.fcm.endpoint", defaultValue = "https://fcm.googleapis.com/fcm/send")
    String fcmEndpoint;

    @Inject
    ObjectMapper objectMapper;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    @Transactional(Transactional.TxType.NOT_SUPPORTED)
    public void sendToUser(Long userId, Long notificationId, String title, String body, String type) {
        String serverKey = fcmServerKey.orElse("").trim();
        if (serverKey.isBlank()) {
            LOG.debug("Push notification skipped: push.fcm.server-key is not configured");
            return;
        }

        List<NotificationDevice> devices = NotificationDevice
                .find("user.id = ?1 and active = true", userId)
                .list();
        for (NotificationDevice device : devices) {
            sendToDevice(device, notificationId, title, body, type, serverKey);
        }
    }

    private void sendToDevice(
            NotificationDevice device,
            Long notificationId,
            String title,
            String body,
            String type,
            String serverKey) {
        try {
            String payload = objectMapper.writeValueAsString(Map.of(
                    "to", device.token,
                    "notification", Map.of(
                            "title", title,
                            "body", body),
                    "data", Map.of(
                            "type", type == null ? "SYSTEM" : type,
                            "notificationId", notificationId == null ? "" : String.valueOf(notificationId))));

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(fcmEndpoint))
                    .timeout(Duration.ofSeconds(8))
                    .header("Content-Type", "application/json")
                    .header("Authorization", "key=" + serverKey)
                    .POST(HttpRequest.BodyPublishers.ofString(payload))
                    .build();

            HttpResponse<String> response = httpClient.send(
                    request,
                    HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() >= 400) {
                LOG.warnf("FCM push failed deviceId=%d status=%d body=%s",
                        device.id, response.statusCode(), response.body());
            }
        } catch (Exception e) {
            LOG.warnf("FCM push failed deviceId=%d: %s", device.id, e.getMessage());
        }
    }
}
