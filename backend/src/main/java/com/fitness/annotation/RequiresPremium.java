package com.fitness.annotation;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * JAX-RS endpoint'lere premium kontrolü ekler.
 *
 * Kullanım:
 * <pre>
 * {@code
 * @GET
 * @Path("/ai/coach")
 * @RequiresPremium
 * public Response getAiCoaching() {
 *     // Buraya sadece premium kullanıcılar erişebilir
 * }
 * }
 * </pre>
 *
 * Eğer kullanıcı premium değilse HTTP 402 Payment Required döner.
 */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface RequiresPremium {
    /**
     * Özellik adı (opsiyonel) - analytics ve logging için
     */
    String feature() default "";

    /**
     * Premium olmayan kullanıcılara gösterilecek mesaj
     */
    String message() default "Bu özellik premium üyelik gerektirir.";
}
