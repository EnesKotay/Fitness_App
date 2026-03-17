package com.fitness.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public class ForgotPasswordRequest {
    @NotBlank(message = "Email alanı boş olamaz")
    @Email(message = "Geçerli bir email adresi giriniz")
    public String email;
}
