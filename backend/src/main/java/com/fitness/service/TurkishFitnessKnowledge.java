package com.fitness.service;

import jakarta.enterprise.context.ApplicationScoped;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Keyword-based Turkish fitness knowledge retrieval.
 * When the user's question matches a topic, injects 1-2 evidence-based
 * sentences so the AI answers accurately without hallucinating.
 */
@ApplicationScoped
public class TurkishFitnessKnowledge {

    // topic keywords → evidence-based Turkish fact (max 2 sentences)
    private static final Map<String[], String> KNOWLEDGE = new LinkedHashMap<>();

    static {
        KNOWLEDGE.put(
            new String[]{"kreatin", "creatine"},
            "Kreatin monohidrat günde 3-5g alındığında kas kuvvetini ve hacmini artırır; yükleme fazı şart değildir. Antrenman öncesi veya sonrası alınabilir, zamanlama ikincil öneme sahiptir.");

        KNOWLEDGE.put(
            new String[]{"intermittent fasting", "aralıklı oruç", "16:8", "18:6"},
            "Aralıklı oruç (16:8 protokolü) toplam kalori alımını kısıtlamanın bir yöntemidir; kasları doğrudan yakmaz. Yeterli protein (kg başına 1.6-2.2g) alındığında kas kaybı riski minimumdur.");

        KNOWLEDGE.put(
            new String[]{"whey", "protein tozu", "protein takviyesi"},
            "Whey protein hızlı emilen, BCAA açısından zengin bir protein kaynağıdır. Antrenman sonrası 20-40g alınması kas protein sentezini optimize eder; gıdadan karşılanamayan protein açığını kapatmak için kullanılır.");

        KNOWLEDGE.put(
            new String[]{"bcaa", "amino asit"},
            "BCAA takviyeleri yeterli protein alındığında ek fayda sağlamaz. Günlük protein hedefi (kg başına 1.6-2.2g) sağlandığında BCAA takviyesi gereksizdir.");

        KNOWLEDGE.put(
            new String[]{"yağ yakma", "yağ yak", "fat burn", "yağ kaybı"},
            "Yağ kaybı için kalori açığı zorunludur; hiçbir egzersiz veya gıda bölgesel yağ yakmaz. Haftalık 0.5-1.0 kg kayıp, kas kaybını minimize eden sürdürülebilir hızdır.");

        KNOWLEDGE.put(
            new String[]{"kas kazanımı", "bulk", "hacim", "kas yap"},
            "Kas kazanımı için haftalık 0.25-0.5 kg kalori fazlası (250-500 kcal/gün) ve kg başına 1.6-2.2g protein gerekir. Yeni başlayanlar bir yılda 8-12 kg kas kazanabilirken deneyimliler yılda 1-2 kg ile sınırlıdır.");

        KNOWLEDGE.put(
            new String[]{"1 tekrar maksimum", "1rm", "one rep max", "max ağırlık"},
            "1RM tahmini için Epley formülü kullanılır: 1RM = ağırlık × (1 + tekrar/30). Gerçek 1RM testi sakatlık riski taşıdığından egzersiz takibinde tahminî değer tercih edilir.");

        KNOWLEDGE.put(
            new String[]{"uyku", "toparlanma", "recovery"},
            "Kas onarımının %80'i uyku sırasında gerçekleşir; 7-9 saat kaliteli uyku optimal hormonal ortamı (büyüme hormonu, testosteron) sağlar. Uyku eksikliği kortizolü artırır ve kas yıkımını hızlandırır.");

        KNOWLEDGE.put(
            new String[]{"su", "hidrasyon", "ne kadar su"},
            "Yetişkinler için bazal su ihtiyacı vücut ağırlığının kg başına 30-35 ml'dir; antrenman yapılan günlerde 500-1000 ml eklenir. İdrar rengi soluk sarı olduğunda yeterli hidrasyon sağlanmıştır.");

        KNOWLEDGE.put(
            new String[]{"squat", "çömelme", "diz ağrısı squat"},
            "Squat'ta diz dizaynı: diz parmak uçlarını aşmamalı ve içe çökmemeli. Diz ağrısında derinliği azaltmak ve box squat kullanmak güvenlidir; tamamen bırakmak gerekmez.");

        KNOWLEDGE.put(
            new String[]{"deadlift", "yerden kaldırma"},
            "Deadlift'te bel düzlüğü (nötral omurga) ve sıkı core aktivasyonu sakatlığı önler. Ağırlık kalçadan değil, yerden hareketle kaldırılmalı; omuzlar bar'ın hemen üzerinde başlamalıdır.");

        KNOWLEDGE.put(
            new String[]{"karın", "abs", "six pack", "mekik"},
            "Karın kasları diğer kaslar gibi dinlenmeye ihtiyaç duyar; haftada 2-3 gün çalışmak yeterlidir. Six-pack görünümü esas olarak düşük vücut yağ oranına (%10-12 erkek, %16-20 kadın) bağlıdır.");

        KNOWLEDGE.put(
            new String[]{"koşu", "cardio", "kardiyo"},
            "Haftalık 150 dakika orta yoğunluklu veya 75 dakika yüksek yoğunluklu kardiyo, sağlık ve yağ kaybı için kanıta dayalı hedeftir. Aşırı kardiyo kas kaybına yol açabilir; dirençli egzersizle dengele.");

        KNOWLEDGE.put(
            new String[]{"plank", "core"},
            "Plank'ta omurga nötral, kalça düz tutulmalı; bel ya da kalça sarkmamalı. 30-60 saniye süreler core stabilitesi için etkilidir; süreyi artırmaktan ziyade formu korumak önceliklidir.");

        KNOWLEDGE.put(
            new String[]{"kilo durdu", "plateau", "takılı kaldım"},
            "Kilo kaybında plateau genellikle adaptif termogenezden kaynaklanır: vücut harcamayı düşürür. Çözüm: kaloriyi 100-200 kcal daha kısmak veya 1-2 haftalık diyet molası (maintenance) vermektir.");

        KNOWLEDGE.put(
            new String[]{"cramp", "krampp", "kramp", "kas krampı"},
            "Egzersiz krampları elektrolit eksikliği (sodyum, magnezyum) veya yetersiz ısınmadan kaynaklanır. Öneri: bol su, ısınma seti ve antrenman sonrası magnezyum takviyesi (200-400 mg gece).");
    }

    /**
     * Returns relevant knowledge snippet if the question matches any topic, otherwise empty string.
     */
    public String retrieve(String question) {
        if (question == null || question.isBlank()) return "";
        String lower = question.toLowerCase();
        for (Map.Entry<String[], String> entry : KNOWLEDGE.entrySet()) {
            for (String keyword : entry.getKey()) {
                // Tam kelime eşleşmesi için Regex Boundary kullanıyoruz (\b)
                String regex = "(?i).*\\b" + Pattern.quote(keyword) + "\\b.*";
                if (lower.matches(regex)) {
                    return entry.getValue();
                }
            }
        }
        return "";
    }
}
