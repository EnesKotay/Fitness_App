package com.fitness.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class ChangePasswordRequest {
    @NotBlank(message = "Mevcut şifre boş olamaz")
    public String currentPassword;
    
    @NotBlank(message = "Yeni şifre boş olamaz")
    @Size(min = 6, message = "Yeni şifre en az 6 karakter olmalıdır")
    public String newPassword;
}
