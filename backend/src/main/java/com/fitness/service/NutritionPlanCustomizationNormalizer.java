package com.fitness.service;

import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import com.fitness.dto.NutritionAiResponse;

import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class NutritionPlanCustomizationNormalizer {

    private static final List<String> SLOT_ORDER = List.of("BREAKFAST", "LUNCH", "DINNER", "SNACK");

    public List<NutritionAiResponse.DailyPlanMeal> normalize(List<NutritionAiResponse.DailyPlanMeal> meals) {
        if (meals == null || meals.isEmpty()) {
            return new ArrayList<>();
        }

        Map<String, NutritionAiResponse.DailyPlanMeal> normalizedBySlot = new LinkedHashMap<>();
        for (NutritionAiResponse.DailyPlanMeal candidate : meals) {
            if (candidate == null || isBlank(candidate.food)) {
                continue;
            }

            String mealType = normalizeMealType(candidate.mealType, candidate.label, candidate.time);
            NutritionAiResponse.DailyPlanMeal normalized = sanitize(candidate, mealType);
            NutritionAiResponse.DailyPlanMeal existing = normalizedBySlot.get(mealType);
            normalizedBySlot.put(mealType, existing == null ? normalized : merge(existing, normalized));
        }

        List<NutritionAiResponse.DailyPlanMeal> ordered = new ArrayList<>();
        for (String slot : SLOT_ORDER) {
            NutritionAiResponse.DailyPlanMeal meal = normalizedBySlot.get(slot);
            if (meal != null) {
                ordered.add(meal);
            }
        }
        return ordered;
    }

    private NutritionAiResponse.DailyPlanMeal sanitize(NutritionAiResponse.DailyPlanMeal meal, String mealType) {
        NutritionAiResponse.DailyPlanMeal normalized = new NutritionAiResponse.DailyPlanMeal();
        normalized.mealType = mealType;
        normalized.label = isBlank(meal.label) ? defaultLabel(mealType) : meal.label.trim();
        normalized.time = normalizeTime(meal.time, mealType);
        normalized.food = meal.food.trim();
        normalized.reason = isBlank(meal.reason) ? "" : meal.reason.trim();
        normalized.ingredients = dedupeStrings(meal.ingredients);
        normalized.macros = meal.macros == null ? new NutritionAiResponse.MealMacros() : meal.macros;
        return normalized;
    }

    private NutritionAiResponse.DailyPlanMeal merge(
            NutritionAiResponse.DailyPlanMeal existing,
            NutritionAiResponse.DailyPlanMeal incoming) {
        NutritionAiResponse.DailyPlanMeal merged = new NutritionAiResponse.DailyPlanMeal();
        merged.mealType = existing.mealType;
        merged.label = existing.label;
        merged.time = earlierTime(existing.time, incoming.time, existing.mealType);
        merged.food = joinDistinct(existing.food, incoming.food, " • ");
        merged.reason = joinDistinct(existing.reason, incoming.reason, " ");
        merged.ingredients = mergeIngredients(existing.ingredients, incoming.ingredients);
        merged.macros = mergeMacros(existing.macros, incoming.macros);
        return merged;
    }

    private NutritionAiResponse.MealMacros mergeMacros(
            NutritionAiResponse.MealMacros first,
            NutritionAiResponse.MealMacros second) {
        NutritionAiResponse.MealMacros merged = new NutritionAiResponse.MealMacros();
        merged.kcal = safeInt(first == null ? null : first.kcal) + safeInt(second == null ? null : second.kcal);
        merged.proteinG = safeInt(first == null ? null : first.proteinG) + safeInt(second == null ? null : second.proteinG);
        merged.carbsG = safeInt(first == null ? null : first.carbsG) + safeInt(second == null ? null : second.carbsG);
        merged.fatG = safeInt(first == null ? null : first.fatG) + safeInt(second == null ? null : second.fatG);
        return merged;
    }

    private List<String> mergeIngredients(List<String> first, List<String> second) {
        LinkedHashSet<String> merged = new LinkedHashSet<>();
        merged.addAll(dedupeStrings(first));
        merged.addAll(dedupeStrings(second));
        return new ArrayList<>(merged);
    }

    private List<String> dedupeStrings(List<String> values) {
        LinkedHashSet<String> deduped = new LinkedHashSet<>();
        if (values == null) {
            return new ArrayList<>();
        }
        for (String value : values) {
            if (!isBlank(value)) {
                deduped.add(value.trim());
            }
        }
        return new ArrayList<>(deduped);
    }

    private String normalizeMealType(String mealType, String label, String time) {
        String fromType = normalizeMealTypeToken(mealType);
        if (fromType != null) {
            return fromType;
        }

        String fromLabel = normalizeMealTypeToken(label);
        if (fromLabel != null) {
            return fromLabel;
        }

        LocalTime parsedTime = parseTime(time);
        if (parsedTime != null) {
            if (parsedTime.isBefore(LocalTime.of(10, 30))) {
                return "BREAKFAST";
            }
            if (parsedTime.isBefore(LocalTime.of(15, 30))) {
                return "LUNCH";
            }
            if (parsedTime.isBefore(LocalTime.of(20, 30))) {
                return "DINNER";
            }
        }

        return "SNACK";
    }

    private String normalizeMealTypeToken(String raw) {
        if (isBlank(raw)) {
            return null;
        }

        String normalized = raw.trim().toUpperCase(Locale.ROOT)
                .replace('Ğ', 'G')
                .replace('Ü', 'U')
                .replace('Ş', 'S')
                .replace('İ', 'I')
                .replace('Ö', 'O')
                .replace('Ç', 'C');

        if (normalized.contains("BREAKFAST") || normalized.contains("KAHVALT")) {
            return "BREAKFAST";
        }
        if (normalized.contains("LUNCH") || normalized.contains("OGLE")) {
            return "LUNCH";
        }
        if (normalized.contains("DINNER") || normalized.contains("AKSAM")) {
            return "DINNER";
        }
        if (normalized.contains("SNACK") || normalized.contains("ARA OGUN") || normalized.contains("ATISTIR")) {
            return "SNACK";
        }
        return null;
    }

    private String normalizeTime(String rawTime, String mealType) {
        LocalTime parsed = parseTime(rawTime);
        if (parsed != null) {
            return parsed.toString();
        }
        return defaultTime(mealType);
    }

    private LocalTime parseTime(String rawTime) {
        if (isBlank(rawTime)) {
            return null;
        }

        try {
            return LocalTime.parse(rawTime.trim());
        } catch (DateTimeParseException ignored) {
            return null;
        }
    }

    private String earlierTime(String first, String second, String mealType) {
        LocalTime firstTime = parseTime(first);
        LocalTime secondTime = parseTime(second);

        if (firstTime != null && secondTime != null) {
            return firstTime.isAfter(secondTime) ? secondTime.toString() : firstTime.toString();
        }
        if (firstTime != null) {
            return firstTime.toString();
        }
        if (secondTime != null) {
            return secondTime.toString();
        }
        return defaultTime(mealType);
    }

    private String defaultLabel(String mealType) {
        return switch (mealType) {
            case "BREAKFAST" -> "Kahvaltı";
            case "LUNCH" -> "Öğle";
            case "DINNER" -> "Akşam";
            default -> "Ara Öğün";
        };
    }

    private String defaultTime(String mealType) {
        return switch (mealType) {
            case "BREAKFAST" -> "08:00";
            case "LUNCH" -> "13:00";
            case "DINNER" -> "19:00";
            default -> "16:30";
        };
    }

    private String joinDistinct(String first, String second, String separator) {
        if (isBlank(first)) {
            return isBlank(second) ? "" : second.trim();
        }
        if (isBlank(second)) {
            return first.trim();
        }
        if (first.trim().equalsIgnoreCase(second.trim())) {
            return first.trim();
        }
        return first.trim() + separator + second.trim();
    }

    private int safeInt(Integer value) {
        return value == null ? 0 : value;
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
