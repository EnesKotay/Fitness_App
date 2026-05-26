-- V18: App Store Server Notifications için originalTransactionId alanı
-- Apple'ın S2S bildirimlerinde gelen originalTransactionId ile kullanıcıyı eşleştirmek için.
ALTER TABLE users
    ADD COLUMN iap_original_transaction_id VARCHAR(255),
    ADD CONSTRAINT uq_users_iap_original_tx UNIQUE (iap_original_transaction_id);
