# Fitness Uygulamasını Başlatma

İki terminal: önce backend, sonra frontend.

---

## 1. Backend

```bash
cd fitness-backend && ./mvnw quarkus:dev
```

(“Listening on: http://0.0.0.0:8080” görünene kadar bekleyin.)

---

## 2. Frontend

```bash
cd Frontend && flutter run
```

Bağlı tek cihaz varsa otomatik seçilir; birden fazlaysa listeden seçersiniz.

---

Telefon–backend için: `Frontend/.env` ve `Frontend/assets/.env` içinde `API_BASE_URL=http://MAC_IP:8080` (Mac’in yerel IP’si) olsun.
