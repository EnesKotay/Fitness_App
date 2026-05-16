package com.fitness.dto;

import jakarta.validation.constraints.NotBlank;

public class SocialLoginRequest {

    @NotBlank(message = "provider gerekli")
    public String provider;

    @NotBlank(message = "idToken gerekli")
    public String idToken;

    public String name;

    public String authorizationCode;
}
