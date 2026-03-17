package com.fitness.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class ResetPasswordRequest {
    @NotBlank(message = "Email boş olamaz")
    @Email(message = "Geçerli bir email adresi giriniz")
    public String email;

    @NotBlank(message = "Doğrulama kodu boş olamaz")
    @Size(min = 6, max = 6, message = "Kod 6 haneli olmalıdır")
    public String code;

    @NotBlank(message = "Yeni şifre boş olamaz")
    @Size(min = 6, message = "Şifre en az 6 karakter olmalıdır")
    public String newPassword;
}
