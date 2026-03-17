import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/weekly_meal_plan_storage.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/planned_meal.dart';
import '../../domain/entities/user_profile.dart';
import '../state/diet_provider.dart';
import 'food_search_page.dart';
import 'smart_grocery_list_page.dart';
import 'weekly_meal_plan_page.dart';

// ─── Veri Modelleri ────────────────────────────────────────────────────────────

class _Goal {
  final String key;
  final String label;
  final String emoji;
  final Color color;
  final String subtitle;
  final String calorieRule;
  final List<_Macro> macros;
  final List<_MealIdea> meals;
  final List<String> rules;
  final List<String> avoid;
  final List<_DayMeal> dailyPlan;
  final List<_TopFood> topFoods;
  final _Timing timing;
  final List<String> supplements;

  const _Goal({
    required this.key,
    required this.label,
    required this.emoji,
    required this.color,
    required this.subtitle,
    required this.calorieRule,
    required this.macros,
    required this.meals,
    required this.rules,
    required this.avoid,
    required this.dailyPlan,
    required this.topFoods,
    required this.timing,
    required this.supplements,
  });
}

class _Macro {
  final String name;
  final String amount;
  final double ratio;
  final Color color;
  const _Macro({
    required this.name,
    required this.amount,
    required this.ratio,
    required this.color,
  });
}

class _MealIdea {
  final String name;
  final String detail;
  final IconData icon;
  final Color accent;
  const _MealIdea({
    required this.name,
    required this.detail,
    required this.icon,
    required this.accent,
  });
}

class _DayMeal {
  final String time;
  final String label;
  final String food;
  final String macros;
  final IconData icon;
  const _DayMeal({
    required this.time,
    required this.label,
    required this.food,
    required this.macros,
    required this.icon,
  });
}

class _TopFood {
  final String name;
  final String highlight;
  final Color color;
  const _TopFood({
    required this.name,
    required this.highlight,
    required this.color,
  });
}

class _Timing {
  final String preMeal;
  final String postMeal;
  final String preDetail;
  final String postDetail;
  const _Timing({
    required this.preMeal,
    required this.postMeal,
    required this.preDetail,
    required this.postDetail,
  });
}

class _PersonalInsight {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _PersonalInsight({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// ─── Statik Veri ──────────────────────────────────────────────────────────────

const _goals = <_Goal>[
  _Goal(
    key: 'cut',
    label: 'Kilo Ver',
    emoji: '🔥',
    color: Color(0xFFFF453A),
    subtitle: 'Yağ yakarken kas koru',
    calorieRule: '−300 – 500 kcal/gün açığı',
    macros: [
      _Macro(
        name: 'Protein',
        amount: '2.0–2.4 g/kg',
        ratio: 0.35,
        color: Color(0xFFFF453A),
      ),
      _Macro(
        name: 'Karbonhidrat',
        amount: '3–4 g/kg',
        ratio: 0.40,
        color: Color(0xFFFF9F0A),
      ),
      _Macro(
        name: 'Yağ',
        amount: '0.8–1.0 g/kg',
        ratio: 0.25,
        color: Color(0xFF30D158),
      ),
    ],
    meals: [
      _MealIdea(
        name: 'Tavuklu Salata',
        detail: '~400 kcal · 40g pro',
        icon: Icons.lunch_dining_rounded,
        accent: Color(0xFFFF453A),
      ),
      _MealIdea(
        name: 'Yulaf + Yumurta',
        detail: '~350 kcal · 25g pro',
        icon: Icons.free_breakfast_rounded,
        accent: Color(0xFFFF9F0A),
      ),
      _MealIdea(
        name: 'Ton Balıklı Tam Tahıl',
        detail: '~300 kcal · 30g pro',
        icon: Icons.wrap_text_rounded,
        accent: Color(0xFF30D158),
      ),
      _MealIdea(
        name: 'Izgara Balık + Sebze',
        detail: '~360 kcal · 35g pro',
        icon: Icons.set_meal_rounded,
        accent: Color(0xFF0A84FF),
      ),
      _MealIdea(
        name: 'Süzme Yoğurt + Ceviz',
        detail: '~200 kcal · 18g pro',
        icon: Icons.icecream_rounded,
        accent: Color(0xFFBF5AF2),
      ),
    ],
    rules: [
      'Her öğünde protein önce yenilsin',
      'Kalori saymak yerine besin yoğunluğuna odaklan',
      'Günde en az 2.5L su iç — açlık hissini azaltır',
      'Gece geç saatte karbonhidrat alımını kısıt',
      'Haftalık 0.5–1 kg kayıp ideal hız',
    ],
    avoid: [
      'Şeker ve işlenmiş atıştırmalıklar',
      'Alkol — kalori yoğun, kas yıkımı yapar',
      'Beyaz ekmek ve rafine karbonhidrat',
      'Kızartmalar ve fast food',
    ],
    dailyPlan: [
      _DayMeal(
        time: '07:30',
        label: 'Kahvaltı',
        food: 'Yulaf ezmesi + 2 haşlanmış yumurta + yarım muz',
        macros: '~380 kcal · 28g pro',
        icon: Icons.free_breakfast_rounded,
      ),
      _DayMeal(
        time: '10:30',
        label: 'Ara Öğün',
        food: 'Süzme yoğurt + bir avuç ceviz',
        macros: '~200 kcal · 18g pro',
        icon: Icons.bakery_dining_rounded,
      ),
      _DayMeal(
        time: '13:00',
        label: 'Öğle',
        food: 'Fırın tavuk göğsü + mevsim salatası + zeytinyağı',
        macros: '~450 kcal · 42g pro',
        icon: Icons.lunch_dining_rounded,
      ),
      _DayMeal(
        time: '16:30',
        label: 'Antrenman Öncesi',
        food: 'Muz veya 1 dilim tam tahıl ekmek + az peynir',
        macros: '~150 kcal · 7g pro',
        icon: Icons.fitness_center_rounded,
      ),
      _DayMeal(
        time: '20:00',
        label: 'Akşam',
        food: 'Izgara balık (levrek/çipura) + buharda sebze + bulgur',
        macros: '~480 kcal · 38g pro',
        icon: Icons.dinner_dining_rounded,
      ),
    ],
    topFoods: [
      _TopFood(
        name: 'Tavuk Göğsü',
        highlight: 'En yüksek protein/kcal oranı',
        color: Color(0xFFFF453A),
      ),
      _TopFood(
        name: 'Yumurta',
        highlight: 'Tam protein + doyurucu',
        color: Color(0xFFFF9F0A),
      ),
      _TopFood(
        name: 'Süzme Yoğurt',
        highlight: 'Yüksek protein + probiyotik',
        color: Color(0xFF30D158),
      ),
      _TopFood(
        name: 'Levrek / Çipura',
        highlight: 'Omega-3 + yüksek pro',
        color: Color(0xFF0A84FF),
      ),
      _TopFood(
        name: 'Brokoli / Ispanak',
        highlight: 'Yüksek lif, düşük kcal',
        color: Color(0xFF34C759),
      ),
      _TopFood(
        name: 'Ton Balığı',
        highlight: 'Uygun fiyat, yüksek pro',
        color: Color(0xFFBF5AF2),
      ),
    ],
    timing: _Timing(
      preMeal: 'Antrenman 60–90 dk Önce',
      postMeal: 'Antrenman 30 dk Sonra',
      preDetail:
          'Orta GI karbonhidrat + az protein. Örnek: yulaf ezmesi + lor peyniri veya muz + yoğurt.',
      postDetail:
          'Hızlı sindirilen protein + basit karb. Örnek: whey shake + muz veya yağsız yoğurt + meyve.',
    ),
    supplements: [
      'Whey Protein',
      'Kreatin 5g',
      'Multivitamin',
      'Omega-3',
      'D3 Vitamini',
    ],
  ),
  _Goal(
    key: 'gain',
    label: 'Kilo Al',
    emoji: '📈',
    color: Color(0xFF30D158),
    subtitle: 'Sağlıklı ve kademeli artış',
    calorieRule: '+300 – 500 kcal/gün fazlası',
    macros: [
      _Macro(
        name: 'Protein',
        amount: '1.6–2.0 g/kg',
        ratio: 0.28,
        color: Color(0xFF30D158),
      ),
      _Macro(
        name: 'Karbonhidrat',
        amount: '5–6 g/kg',
        ratio: 0.50,
        color: Color(0xFFFF9F0A),
      ),
      _Macro(
        name: 'Yağ',
        amount: '1.0–1.5 g/kg',
        ratio: 0.22,
        color: Color(0xFF0A84FF),
      ),
    ],
    meals: [
      _MealIdea(
        name: 'Yulaf + Muz Smoothie',
        detail: '~550 kcal · 25g pro',
        icon: Icons.blender_rounded,
        accent: Color(0xFF30D158),
      ),
      _MealIdea(
        name: 'Pirinç + Tavuk + Zeytinyağı',
        detail: '~650 kcal · 45g pro',
        icon: Icons.rice_bowl_rounded,
        accent: Color(0xFFFF9F0A),
      ),
      _MealIdea(
        name: 'Fındık Ezmeli Tam Tahıl',
        detail: '~420 kcal · 15g pro',
        icon: Icons.bakery_dining_rounded,
        accent: Color(0xFFFF453A),
      ),
      _MealIdea(
        name: 'Yumurta + Avokado',
        detail: '~480 kcal · 20g pro',
        icon: Icons.egg_alt_rounded,
        accent: Color(0xFF0A84FF),
      ),
      _MealIdea(
        name: 'Makarna + Kıyma',
        detail: '~700 kcal · 40g pro',
        icon: Icons.dinner_dining_rounded,
        accent: Color(0xFFBF5AF2),
      ),
    ],
    rules: [
      '4–5 öğünle günlük kalorileri yay',
      'Antrenman öncesi karbonhidrat yükle',
      'Antrenman sonrası 30dk içinde protein al',
      'Haftalık 0.3–0.5 kg artış ideal',
      'Uyku en az 8 saat — büyüme hormonuna kritik',
    ],
    avoid: [
      'Uzun süreli açlık ve atlanmış öğünler',
      'Sadece yağlı/şekerli besinlerle kalori artırma',
      'Aşırı kafein — iştah bastırır',
      'Kilo alma adına çöp kalori',
    ],
    dailyPlan: [
      _DayMeal(
        time: '07:00',
        label: 'Kahvaltı',
        food: 'Yulaf + yumurta + fındık ezmesi + muz',
        macros: '~600 kcal · 30g pro',
        icon: Icons.free_breakfast_rounded,
      ),
      _DayMeal(
        time: '10:00',
        label: 'Ara Öğün',
        food: 'Tam yağlı yoğurt + meyve + ceviz',
        macros: '~320 kcal · 16g pro',
        icon: Icons.bakery_dining_rounded,
      ),
      _DayMeal(
        time: '13:00',
        label: 'Öğle',
        food: 'Pirinç pilav + tavuk + zeytinyağı',
        macros: '~700 kcal · 48g pro',
        icon: Icons.rice_bowl_rounded,
      ),
      _DayMeal(
        time: '16:00',
        label: 'Antrenman Öncesi',
        food: 'Muz + 1 dilim tam tahıl ekmek',
        macros: '~200 kcal · 5g pro',
        icon: Icons.fitness_center_rounded,
      ),
      _DayMeal(
        time: '19:30',
        label: 'Akşam',
        food: 'Makarna + kıyma sosu + kaşar rendesi',
        macros: '~750 kcal · 42g pro',
        icon: Icons.dinner_dining_rounded,
      ),
    ],
    topFoods: [
      _TopFood(
        name: 'Yulaf',
        highlight: 'Kalori + lif + uzun enerji',
        color: Color(0xFF30D158),
      ),
      _TopFood(
        name: 'Pirinç / Bulgur',
        highlight: 'Hızlı sindirim, yüksek karb',
        color: Color(0xFFFF9F0A),
      ),
      _TopFood(
        name: 'Fındık Ezmesi',
        highlight: 'Sağlıklı yağ + kalori',
        color: Color(0xFFFF453A),
      ),
      _TopFood(
        name: 'Muz',
        highlight: 'Hızlı enerji + potasyum',
        color: Color(0xFF0A84FF),
      ),
      _TopFood(
        name: 'Tavuk Göğsü',
        highlight: 'Yüksek protein + düşük yağ',
        color: Color(0xFF30D158),
      ),
      _TopFood(
        name: 'Zeytinyağı',
        highlight: 'Kalori yoğun + sağlıklı',
        color: Color(0xFFBF5AF2),
      ),
    ],
    timing: _Timing(
      preMeal: 'Antrenman 60 dk Önce',
      postMeal: 'Antrenman 30 dk Sonra',
      preDetail:
          'Yüksek karbonhidrat + orta protein. Örnek: pirinç + tavuk veya yulaf + yumurta.',
      postDetail:
          'Protein + hızlı karb kombinasyonu. Örnek: whey + muz + pirinç keki veya yoğurt + granola.',
    ),
    supplements: [
      'Whey Protein',
      'Kreatin 5g',
      'Mass Gainer',
      'ZMA',
      'B12 Vitamini',
    ],
  ),
  _Goal(
    key: 'bulk',
    label: 'Hacim',
    emoji: '💪',
    color: Color(0xFFBF5AF2),
    subtitle: 'Maksimum kas kütlesi',
    calorieRule: '+500 – 1000 kcal/gün fazlası',
    macros: [
      _Macro(
        name: 'Protein',
        amount: '1.8–2.4 g/kg',
        ratio: 0.30,
        color: Color(0xFFBF5AF2),
      ),
      _Macro(
        name: 'Karbonhidrat',
        amount: '6–8 g/kg',
        ratio: 0.50,
        color: Color(0xFFFF9F0A),
      ),
      _Macro(
        name: 'Yağ',
        amount: '1.0–1.5 g/kg',
        ratio: 0.20,
        color: Color(0xFF30D158),
      ),
    ],
    meals: [
      _MealIdea(
        name: 'Yoğurtlu Muz Shake',
        detail: '~550 kcal · 30g pro',
        icon: Icons.local_drink_rounded,
        accent: Color(0xFFBF5AF2),
      ),
      _MealIdea(
        name: 'Kırmızı Et + Patates',
        detail: '~750 kcal · 50g pro',
        icon: Icons.outdoor_grill_rounded,
        accent: Color(0xFFFF453A),
      ),
      _MealIdea(
        name: 'Pirinç Pilav + Mercimek',
        detail: '~600 kcal · 30g pro',
        icon: Icons.rice_bowl_rounded,
        accent: Color(0xFFFF9F0A),
      ),
      _MealIdea(
        name: 'Tam Yağlı Süt + Yulaf',
        detail: '~500 kcal · 22g pro',
        icon: Icons.local_cafe_rounded,
        accent: Color(0xFF0A84FF),
      ),
      _MealIdea(
        name: 'Hindi Saç + Ekmek',
        detail: '~680 kcal · 55g pro',
        icon: Icons.lunch_dining_rounded,
        accent: Color(0xFF30D158),
      ),
    ],
    rules: [
      'Her 2–3 saatte öğün ye — anabolik pencere',
      'Yatmadan önce kazein veya yoğurt al',
      'Ağır bileşik hareketlere odaklan',
      'Creatine monohydrate günde 5g ekle',
      'Karın yağı %15 altındayken bulk daha etkili',
    ],
    avoid: [
      'Cardio ağırlıklı program — kalori yakıyor',
      'Yetersiz karbonhidrat — enerji düşer',
      'Öğün atlamak — katabolizma riski',
      'Uyku eksikliği — hormon profili bozulur',
    ],
    dailyPlan: [
      _DayMeal(
        time: '07:00',
        label: 'Kahvaltı',
        food: '4 yumurta + yulaf + süt + muz',
        macros: '~750 kcal · 45g pro',
        icon: Icons.free_breakfast_rounded,
      ),
      _DayMeal(
        time: '10:00',
        label: 'Ara Öğün',
        food: 'Süt + yulaf + muz + fındık karışımı',
        macros: '~550 kcal · 28g pro',
        icon: Icons.local_drink_rounded,
      ),
      _DayMeal(
        time: '13:00',
        label: 'Öğle',
        food: 'Kırmızı et + pirinç pilav + salata',
        macros: '~850 kcal · 55g pro',
        icon: Icons.outdoor_grill_rounded,
      ),
      _DayMeal(
        time: '16:00',
        label: 'Antrenman',
        food: 'Whey + dextrose veya muz + pirinç keki',
        macros: '~350 kcal · 35g pro',
        icon: Icons.fitness_center_rounded,
      ),
      _DayMeal(
        time: '19:30',
        label: 'Akşam',
        food: 'Hindi + patates + zeytinyağı',
        macros: '~800 kcal · 58g pro',
        icon: Icons.dinner_dining_rounded,
      ),
      _DayMeal(
        time: '22:00',
        label: 'Gece',
        food: 'Süzme yoğurt veya lor peyniri + ceviz',
        macros: '~220 kcal · 22g pro',
        icon: Icons.nightlight_rounded,
      ),
    ],
    topFoods: [
      _TopFood(
        name: 'Kırmızı Et',
        highlight: 'Kreatin + demir + pro',
        color: Color(0xFFBF5AF2),
      ),
      _TopFood(
        name: 'Yulaf',
        highlight: 'Kompleks karb + kalori',
        color: Color(0xFFFF9F0A),
      ),
      _TopFood(
        name: 'Tam Yağlı Süt',
        highlight: 'Kalori + kazein + pro',
        color: Color(0xFF0A84FF),
      ),
      _TopFood(
        name: 'Pirinç',
        highlight: 'Hızlı glikojen doldurma',
        color: Color(0xFF30D158),
      ),
      _TopFood(
        name: 'Yumurta',
        highlight: 'Tam aminoasit profili',
        color: Color(0xFFFF453A),
      ),
      _TopFood(
        name: 'Avokado',
        highlight: 'Sağlıklı yağ + kalori',
        color: Color(0xFF34C759),
      ),
    ],
    timing: _Timing(
      preMeal: 'Antrenman 45–60 dk Önce',
      postMeal: 'Antrenman 20 dk Sonra',
      preDetail:
          'Yüksek karb + protein. Örnek: pirinç + tavuk + az yağ. Sindirimi kolay tutun.',
      postDetail:
          'Anabolic pencere kritik! Whey + yüksek GI karb. Örnek: whey + pirinç + muz kombinasyonu.',
    ),
    supplements: [
      'Whey Protein',
      'Kreatin 5g',
      'Mass Gainer',
      'BCAA',
      'Glutamin',
      'ZMA',
    ],
  ),
  _Goal(
    key: 'strength',
    label: 'Güç',
    emoji: '⚡',
    color: Color(0xFFFF9F0A),
    subtitle: 'Performans & kuvvet odaklı',
    calorieRule: 'Dengeli / +100–200 kcal',
    macros: [
      _Macro(
        name: 'Protein',
        amount: '1.8–2.2 g/kg',
        ratio: 0.30,
        color: Color(0xFFFF9F0A),
      ),
      _Macro(
        name: 'Karbonhidrat',
        amount: '4–6 g/kg',
        ratio: 0.45,
        color: Color(0xFF30D158),
      ),
      _Macro(
        name: 'Yağ',
        amount: '1.0–1.2 g/kg',
        ratio: 0.25,
        color: Color(0xFF0A84FF),
      ),
    ],
    meals: [
      _MealIdea(
        name: 'Antrenman Öncesi Yulaf',
        detail: '~400 kcal · 15g pro',
        icon: Icons.bolt_rounded,
        accent: Color(0xFFFF9F0A),
      ),
      _MealIdea(
        name: 'Whey + Muz (Sonrası)',
        detail: '~300 kcal · 30g pro',
        icon: Icons.fitness_center_rounded,
        accent: Color(0xFFBF5AF2),
      ),
      _MealIdea(
        name: 'Tavuk + Tatlı Patates',
        detail: '~580 kcal · 45g pro',
        icon: Icons.rice_bowl_rounded,
        accent: Color(0xFF30D158),
      ),
      _MealIdea(
        name: 'Yumurta Beyazı + Tam Tahıl',
        detail: '~350 kcal · 28g pro',
        icon: Icons.egg_rounded,
        accent: Color(0xFFFF453A),
      ),
      _MealIdea(
        name: 'Kırmızı Et + Bulgur',
        detail: '~620 kcal · 50g pro',
        icon: Icons.outdoor_grill_rounded,
        accent: Color(0xFF0A84FF),
      ),
    ],
    rules: [
      'Antrenman 90dk öncesi karb + protein al',
      'Kafein (200mg) 45dk öncesi performansı artırır',
      'Creatine — kuvvet için kanıtlanmış tek takviye',
      'Yeterince kaloride olmadan kuvvet gelişmez',
      'Deload haftasında kaloriyi %10 düşür',
    ],
    avoid: [
      'Antrenman öncesi yüksek yağlı öğün',
      'Düşük karbonhidrat diyeti — güç düşer',
      'Takviye bağımlılığı — önce beslenme',
      'Alkol — toparlanmayı engeller',
    ],
    dailyPlan: [
      _DayMeal(
        time: '07:30',
        label: 'Kahvaltı',
        food: 'Yulaf + 3 yumurta + ceviz',
        macros: '~520 kcal · 35g pro',
        icon: Icons.free_breakfast_rounded,
      ),
      _DayMeal(
        time: '11:00',
        label: 'Ara Öğün',
        food: 'Tam buğday ekmek + hindi + avokado',
        macros: '~380 kcal · 28g pro',
        icon: Icons.bakery_dining_rounded,
      ),
      _DayMeal(
        time: '14:00',
        label: 'Öğle',
        food: 'Kırmızı et + bulgur pilavı + ıspanak',
        macros: '~650 kcal · 52g pro',
        icon: Icons.outdoor_grill_rounded,
      ),
      _DayMeal(
        time: '17:00',
        label: 'Antrenman Öncesi',
        food: 'Tatlı patates + tavuk + kafein',
        macros: '~420 kcal · 35g pro',
        icon: Icons.fitness_center_rounded,
      ),
      _DayMeal(
        time: '20:30',
        label: 'Akşam',
        food: 'Somon + brokoli + pirinç',
        macros: '~580 kcal · 45g pro',
        icon: Icons.dinner_dining_rounded,
      ),
    ],
    topFoods: [
      _TopFood(
        name: 'Sığır Eti',
        highlight: 'Kreatin + demir + çinko',
        color: Color(0xFFFF9F0A),
      ),
      _TopFood(
        name: 'Bulgur',
        highlight: 'Lif + demir + kompleks karb',
        color: Color(0xFF30D158),
      ),
      _TopFood(
        name: 'Tatlı Patates',
        highlight: 'Sürekli enerji kaynağı',
        color: Color(0xFFFF453A),
      ),
      _TopFood(
        name: 'Somon',
        highlight: 'Omega-3 + toparlanma',
        color: Color(0xFF0A84FF),
      ),
      _TopFood(
        name: 'Yumurta',
        highlight: 'Tam aminoasit profili',
        color: Color(0xFFBF5AF2),
      ),
      _TopFood(
        name: 'Kahve / Kafein',
        highlight: 'Performans artırıcı',
        color: Color(0xFF8D6E63),
      ),
    ],
    timing: _Timing(
      preMeal: 'Antrenman 60–90 dk Önce',
      postMeal: 'Antrenman 30 dk Sonra',
      preDetail:
          'Kompleks karb + orta protein + kafein (opsiyonel). Örnek: bulgur + kıyma köfte veya yulaf + yumurta.',
      postDetail:
          'Kas onarımı için hızlı protein. Whey + basit karb veya yoğurt + muz. Kreatin antrenman sonrası en etkili.',
    ),
    supplements: [
      'Kreatin 5g',
      'Kafein 200mg',
      'Whey Protein',
      'Omega-3',
      'Magnezyum',
    ],
  ),
  _Goal(
    key: 'maintain',
    label: 'Form Koru',
    emoji: '⚖️',
    color: Color(0xFF0A84FF),
    subtitle: 'Mevcut formu ve kiloyu koru',
    calorieRule: 'TDEE = sıfır açık/fazla',
    macros: [
      _Macro(
        name: 'Protein',
        amount: '1.4–1.8 g/kg',
        ratio: 0.25,
        color: Color(0xFF0A84FF),
      ),
      _Macro(
        name: 'Karbonhidrat',
        amount: '4–5 g/kg',
        ratio: 0.50,
        color: Color(0xFFFF9F0A),
      ),
      _Macro(
        name: 'Yağ',
        amount: '1.0 g/kg',
        ratio: 0.25,
        color: Color(0xFF30D158),
      ),
    ],
    meals: [
      _MealIdea(
        name: 'Omlet + Sebze',
        detail: '~350 kcal · 22g pro',
        icon: Icons.egg_alt_rounded,
        accent: Color(0xFF0A84FF),
      ),
      _MealIdea(
        name: 'Izgara Balık + Salata',
        detail: '~420 kcal · 35g pro',
        icon: Icons.set_meal_rounded,
        accent: Color(0xFF30D158),
      ),
      _MealIdea(
        name: 'Bulgur Pilavı + Yoğurt',
        detail: '~480 kcal · 20g pro',
        icon: Icons.rice_bowl_rounded,
        accent: Color(0xFFFF9F0A),
      ),
      _MealIdea(
        name: 'Meyve + Ceviz',
        detail: '~250 kcal · 5g pro',
        icon: Icons.eco_rounded,
        accent: Color(0xFF30D158),
      ),
      _MealIdea(
        name: 'Mercimek Çorbası',
        detail: '~300 kcal · 18g pro',
        icon: Icons.soup_kitchen_rounded,
        accent: Color(0xFFFF453A),
      ),
    ],
    rules: [
      'Kilonu haftada bir takip et — trend izle',
      'Dengeli tabak: ½ sebze, ¼ protein, ¼ karb',
      'Egzersiz rutinini koru — hafta 3–4 gün',
      'Stres ve uyku kalitesi formda kritik',
      'Hafta 1 gün serbest öğün motivasyonu artırır',
    ],
    avoid: [
      'Tutarsız beslenme düzeni — yoyo yapar',
      'Aşırı kısıtlama veya aşırı yeme',
      'Hareketsiz uzun dönemler',
      'Kontrolsüz sosyal yemek periyotları',
    ],
    dailyPlan: [
      _DayMeal(
        time: '08:00',
        label: 'Kahvaltı',
        food: '2 yumurta + tam tahıl ekmek + domates',
        macros: '~380 kcal · 22g pro',
        icon: Icons.free_breakfast_rounded,
      ),
      _DayMeal(
        time: '11:00',
        label: 'Ara Öğün',
        food: 'Meyve + bir avuç fındık',
        macros: '~200 kcal · 5g pro',
        icon: Icons.eco_rounded,
      ),
      _DayMeal(
        time: '13:30',
        label: 'Öğle',
        food: 'Bulgur + ızgara tavuk + cacık',
        macros: '~520 kcal · 38g pro',
        icon: Icons.rice_bowl_rounded,
      ),
      _DayMeal(
        time: '16:30',
        label: 'Ara Öğün',
        food: 'Yoğurt veya kefir',
        macros: '~150 kcal · 10g pro',
        icon: Icons.icecream_rounded,
      ),
      _DayMeal(
        time: '19:30',
        label: 'Akşam',
        food: 'Izgara balık + mercimek çorbası + salata',
        macros: '~500 kcal · 42g pro',
        icon: Icons.set_meal_rounded,
      ),
    ],
    topFoods: [
      _TopFood(
        name: 'Bulgur',
        highlight: 'Lif + demir + dengeli karb',
        color: Color(0xFF0A84FF),
      ),
      _TopFood(
        name: 'Mercimek',
        highlight: 'Protein + lif + demir',
        color: Color(0xFFFF9F0A),
      ),
      _TopFood(
        name: 'Yoğurt',
        highlight: 'Probiyotik + kalsiyum',
        color: Color(0xFF30D158),
      ),
      _TopFood(
        name: 'Balık',
        highlight: 'Omega-3 + yüksek pro',
        color: Color(0xFF0A84FF),
      ),
      _TopFood(
        name: 'Sebze Çeşitleri',
        highlight: 'Mikro besin deposu',
        color: Color(0xFF34C759),
      ),
      _TopFood(
        name: 'Zeytinyağı',
        highlight: 'Anti-enflamatuar yağ',
        color: Color(0xFFFF453A),
      ),
    ],
    timing: _Timing(
      preMeal: 'Egzersiz 60 dk Önce',
      postMeal: 'Egzersiz 45 dk Sonra',
      preDetail:
          'Hafif ve sindirimi kolay öğün. Yoğurt veya 1 dilim tam tahıl ekmek + beyaz peynir yeterli.',
      postDetail:
          'Normal öğün yeterli. Tavuk, yumurta veya yoğurt ağırlıklı tercih form korumayı destekler.',
    ),
    supplements: [
      'Multivitamin',
      'D3 + K2',
      'Omega-3',
      'Magnezyum',
      'C Vitamini',
    ],
  ),
];

// ─── Sayfa ────────────────────────────────────────────────────────────────────

class NutritionGuidePage extends StatefulWidget {
  const NutritionGuidePage({super.key});

  @override
  State<NutritionGuidePage> createState() => _NutritionGuidePageState();
}

class _NutritionGuidePageState extends State<NutritionGuidePage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _syncedWithProfile = false;
  final _weeklyPlanStorage = WeeklyMealPlanStorage();
  late AnimationController _switchCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _switchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _switchCtrl, curve: Curves.easeOut);
    _switchCtrl.forward();
  }

  @override
  void dispose() {
    _switchCtrl.dispose();
    super.dispose();
  }

  void _selectGoal(int i) async {
    if (i == _selectedIndex) return;
    await _switchCtrl.reverse();
    if (!mounted) return;
    setState(() => _selectedIndex = i);
    _switchCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncedWithProfile) return;
    final profileGoal = context.read<DietProvider>().profile?.goal;
    final goalIndex = _goalIndexForProfile(profileGoal);
    if (goalIndex != null) {
      _selectedIndex = goalIndex;
    }
    _syncedWithProfile = true;
  }

  int? _goalIndexForProfile(Goal? goal) {
    switch (goal) {
      case Goal.cut:
        return _goals.indexWhere((item) => item.key == 'cut');
      case Goal.bulk:
        return _goals.indexWhere((item) => item.key == 'bulk');
      case Goal.strength:
        return _goals.indexWhere((item) => item.key == 'strength');
      case Goal.maintain:
        return _goals.indexWhere((item) => item.key == 'maintain');
      case null:
        return null;
    }
  }

  MealType _suggestedMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) return MealType.breakfast;
    if (hour < 16) return MealType.lunch;
    if (hour < 21) return MealType.dinner;
    return MealType.snack;
  }

  List<_PersonalInsight> _buildInsights(DietProvider provider, _Goal goal) {
    final proteinGap =
        (provider.macroTargets.protein - provider.totals.totalProtein).clamp(
          0,
          double.infinity,
        );
    final carbGap = (provider.macroTargets.carb - provider.totals.totalCarb)
        .clamp(0, double.infinity);
    final remaining = provider.remainingKcal;
    final insights = <_PersonalInsight>[
      _PersonalInsight(
        title: remaining >= 0 ? 'Kalori alanın açık' : 'Kalori hedefin aşıldı',
        description: remaining >= 0
            ? 'Bugün yaklaşık ${remaining.round()} kcal alanın var. Sonraki öğünü ${goal.label.toLowerCase()} hedefine göre seçebilirsin.'
            : 'Bugün hedefinin ${remaining.abs().round()} kcal üstündesin. Daha hafif ve protein ağırlıklı seçim toparlar.',
        icon: remaining >= 0
            ? Icons.local_fire_department_rounded
            : Icons.balance_rounded,
        color: remaining >= 0 ? goal.color : const Color(0xFFFF9F0A),
      ),
      _PersonalInsight(
        title: proteinGap > 15
            ? 'Protein tarafı geride'
            : 'Protein ritmi iyi gidiyor',
        description: proteinGap > 15
            ? 'Hedefe yaklaşmak için yaklaşık ${proteinGap.round()}g protein daha eklemek iyi olur. Tavuk, yoğurt veya yumurta öncelikli olabilir.'
            : 'Bugün protein hedefin iyi ilerliyor. Geri kalan öğünlerde dengeyi korumaya odaklanabilirsin.',
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFF30D158),
      ),
      _PersonalInsight(
        title: carbGap > 30
            ? 'Enerji desteği gerekebilir'
            : 'Karbonhidrat dengesi kontrollü',
        description: carbGap > 30
            ? 'Özellikle antrenman varsa yulaf, bulgur veya pirinç gibi temiz karbonhidratlar performansı destekler.'
            : 'Karbonhidrat alımın dengeli görünüyor. Günün geri kalanında sebze ve proteinle rahat ilerleyebilirsin.',
        icon: Icons.bolt_rounded,
        color: const Color(0xFF0A84FF),
      ),
    ];
    return insights;
  }

  void _openFoodSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodSearchPage(selectedMealType: _suggestedMealType()),
      ),
    );
  }

  void _openWeeklyPlan() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WeeklyMealPlanPage()));
  }

  void _openGroceryList() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SmartGroceryListPage()));
  }

  MealType _mealTypeFromDayMeal(_DayMeal meal) {
    final lower = meal.label.toLowerCase();
    if (lower.contains('kahvalt')) {
      return MealType.breakfast;
    }
    if (lower.contains('öğle') || lower.contains('ogle')) {
      return MealType.lunch;
    }
    if (lower.contains('akşam') || lower.contains('aksam')) {
      return MealType.dinner;
    }
    return MealType.snack;
  }

  String _slotKeyForMealType(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snack';
    }
  }

  int _extractKcal(String text) {
    final match = RegExp(
      r'(\d+)\s*kcal',
      caseSensitive: false,
    ).firstMatch(text);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  double _defaultGuidePortion(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 120;
      case MealType.lunch:
      case MealType.dinner:
        return 180;
      case MealType.snack:
        return 80;
    }
  }

  Future<void> _copyDailyPlanToWeeklyPlan(_Goal goal) async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final dayIndex = now.weekday - 1;
    final weekPlan = await _weeklyPlanStorage.load(weekStart);
    final daySlots = Map<String, PlannedMeal?>.from(weekPlan[dayIndex] ?? {});

    for (final meal in goal.dailyPlan) {
      final mealType = _mealTypeFromDayMeal(meal);
      final slotKey = _slotKeyForMealType(mealType);
      final nextMeal = PlannedMeal(
        name: meal.food,
        kcal: _extractKcal(meal.macros),
        portionGrams: _defaultGuidePortion(mealType),
        mealType: mealType,
        ingredients: meal.food
            .split(RegExp(r'\+|/| veya '))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
      );

      final existing = daySlots[slotKey];
      if (existing == null) {
        daySlots[slotKey] = nextMeal;
      } else {
        daySlots[slotKey] = existing.copyWith(
          name: '${existing.name} • ${nextMeal.name}',
          kcal: existing.kcal + nextMeal.kcal,
          portionGrams: existing.portionGrams + nextMeal.portionGrams,
          ingredients: [...existing.ingredients, ...nextMeal.ingredients],
          clearFoodId: true,
        );
      }
    }

    weekPlan[dayIndex] = daySlots;
    await _weeklyPlanStorage.save(weekStart, weekPlan);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${goal.label} örnek günü bugünün haftalık planına kopyalandı.',
          ),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(label: 'Aç', onPressed: _openWeeklyPlan),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DietProvider>();
    final goal = _goals[_selectedIndex];
    final insights = _buildInsights(provider, goal);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            expandedHeight: 100,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(54, 0, 16, 14),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Beslenme Rehberi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Hedefe göre kişisel plan',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              background: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      goal.color.withValues(alpha: 0.18),
                      AppColors.background,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // ── Goal Selector ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _GoalSelector(
              goals: _goals,
              selectedIndex: _selectedIndex,
              onSelected: _selectGoal,
            ),
          ),

          // ── Animated Content ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero
                    _HeroBanner(goal: goal, provider: provider),
                    const SizedBox(height: 14),

                    _PersonalSummaryCard(
                      goal: goal,
                      provider: provider,
                      insights: insights,
                    ),
                    const SizedBox(height: 14),

                    _GuideActionsCard(
                      onFoodSearch: _openFoodSearch,
                      onWeeklyPlan: _openWeeklyPlan,
                      onGroceryList: _openGroceryList,
                    ),
                    const SizedBox(height: 14),

                    // Makrolar
                    _MacroCard(goal: goal, provider: provider),
                    const SizedBox(height: 20),

                    // Öğün Fikirleri
                    _SectionHeader(
                      title: 'Öğün Fikirleri',
                      icon: Icons.restaurant_menu_rounded,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(height: 112, child: _MealList(goal: goal)),
                    const SizedBox(height: 20),

                    // Günlük Plan
                    _SectionHeader(
                      title: 'Örnek Günlük Plan',
                      icon: Icons.schedule_rounded,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _copyDailyPlanToWeeklyPlan(goal),
                        icon: Icon(
                          Icons.content_copy_rounded,
                          color: goal.color,
                          size: 16,
                        ),
                        label: Text(
                          'Bugünün planına kopyala',
                          style: TextStyle(
                            color: goal.color,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    _DailyPlanCard(goal: goal),
                    const SizedBox(height: 20),

                    // Zamanlama
                    _SectionHeader(
                      title: 'Antrenman Zamanlaması',
                      icon: Icons.timer_rounded,
                    ),
                    const SizedBox(height: 10),
                    _TimingCard(goal: goal),
                    const SizedBox(height: 20),

                    // En İyi Besinler
                    _SectionHeader(
                      title: 'En İyi 6 Besin',
                      icon: Icons.star_rounded,
                    ),
                    const SizedBox(height: 10),
                    _TopFoodsGrid(goal: goal),
                    const SizedBox(height: 20),

                    // Altın Kurallar
                    _SectionHeader(
                      title: 'Altın Kurallar',
                      icon: Icons.check_circle_rounded,
                      color: goal.color,
                    ),
                    const SizedBox(height: 10),
                    _RulesCard(goal: goal),
                    const SizedBox(height: 14),

                    // Kaçınılacaklar
                    _SectionHeader(
                      title: 'Kaçınılacaklar',
                      icon: Icons.block_rounded,
                      color: const Color(0xFFFF453A),
                    ),
                    const SizedBox(height: 10),
                    _AvoidCard(goal: goal),
                    const SizedBox(height: 20),

                    // Takviyeler
                    _SectionHeader(
                      title: 'Önerilen Takviyeler',
                      icon: Icons.science_rounded,
                    ),
                    const SizedBox(height: 10),
                    _SupplementChips(goal: goal),
                    const SizedBox(height: 20),

                    // Genel İpuçları
                    _SectionHeader(
                      title: 'Genel Beslenme İpuçları',
                      icon: Icons.lightbulb_rounded,
                      color: const Color(0xFFFFD60A),
                    ),
                    const SizedBox(height: 10),
                    _GeneralTipsCard(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;
  const _SectionHeader({required this.title, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white60;
    return Row(
      children: [
        Icon(icon, color: c, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color != null ? c : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Goal Selector ────────────────────────────────────────────────────────────

class _GoalSelector extends StatelessWidget {
  final List<_Goal> goals;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _GoalSelector({
    required this.goals,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        itemCount: goals.length,
        itemBuilder: (_, i) {
          final g = goals[i];
          final sel = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? g.color.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: sel
                      ? g.color.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.08),
                  width: sel ? 1.5 : 1,
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: g.color.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(g.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    g.label,
                    style: TextStyle(
                      color: sel ? g.color : Colors.white54,
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Hero Banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final _Goal goal;
  final DietProvider provider;
  const _HeroBanner({required this.goal, required this.provider});

  @override
  Widget build(BuildContext context) {
    final profileLabel = provider.profile?.goal.name == null
        ? 'Rehber modunda'
        : 'Profilinle senkronlu';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            goal.color.withValues(alpha: 0.22),
            goal.color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: goal.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(goal.emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.label,
                  style: TextStyle(
                    color: goal.color,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  goal.subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: goal.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        goal.calorieRule,
                        style: TextStyle(
                          color: goal.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        profileLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalSummaryCard extends StatelessWidget {
  final _Goal goal;
  final DietProvider provider;
  final List<_PersonalInsight> insights;

  const _PersonalSummaryCard({
    required this.goal,
    required this.provider,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = provider.remainingKcal.round();
    final proteinTarget = provider.macroTargets.protein.round();
    final proteinCurrent = provider.totals.totalProtein.round();
    final currentKcal = provider.totals.totalKcal.round();
    final targetKcal = provider.effectiveTargetKcal.round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10151D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: goal.color, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Bugün İçin Akıllı Özet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Kalori',
                  value: '$currentKcal / $targetKcal',
                  helper: remaining >= 0
                      ? '$remaining kcal alan'
                      : '${remaining.abs()} kcal fazla',
                  color: goal.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Protein',
                  value: '$proteinCurrent / $proteinTarget g',
                  helper: proteinCurrent >= proteinTarget
                      ? 'Hedefe ulaştın'
                      : '${proteinTarget - proteinCurrent}g kaldı',
                  color: const Color(0xFF30D158),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InsightRow(insight: insight),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideActionsCard extends StatelessWidget {
  final VoidCallback onFoodSearch;
  final VoidCallback onWeeklyPlan;
  final VoidCallback onGroceryList;

  const _GuideActionsCard({
    required this.onFoodSearch,
    required this.onWeeklyPlan,
    required this.onGroceryList,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rehberden Aksiyona Geç',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionChip(
                label: 'Öğün Ara',
                icon: Icons.search_rounded,
                onTap: onFoodSearch,
              ),
              _ActionChip(
                label: 'Haftaya Ekle',
                icon: Icons.calendar_month_rounded,
                onTap: onWeeklyPlan,
              ),
              _ActionChip(
                label: 'Alışveriş Listesi',
                icon: Icons.shopping_cart_rounded,
                onTap: onGroceryList,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final _PersonalInsight insight;

  const _InsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: insight.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(insight.icon, color: insight.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  insight.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Macro Card ───────────────────────────────────────────────────────────────

class _MacroCard extends StatelessWidget {
  final _Goal goal;
  final DietProvider provider;
  const _MacroCard({required this.goal, required this.provider});

  @override
  Widget build(BuildContext context) {
    final targets = provider.macroTargets;
    final proteinProgress =
        (provider.totals.totalProtein /
                (targets.protein == 0 ? 1 : targets.protein))
            .clamp(0.0, 1.0);
    final carbProgress =
        (provider.totals.totalCarb / (targets.carb == 0 ? 1 : targets.carb))
            .clamp(0.0, 1.0);
    final fatProgress =
        (provider.totals.totalFat / (targets.fat == 0 ? 1 : targets.fat)).clamp(
          0.0,
          1.0,
        );
    final dynamicMacros = [
      _Macro(
        name: 'Protein',
        amount:
            '${provider.totals.totalProtein.round()} / ${targets.protein.round()} g',
        ratio: proteinProgress,
        color: goal.macros[0].color,
      ),
      _Macro(
        name: 'Karbonhidrat',
        amount:
            '${provider.totals.totalCarb.round()} / ${targets.carb.round()} g',
        ratio: carbProgress,
        color: goal.macros[1].color,
      ),
      _Macro(
        name: 'Yağ',
        amount:
            '${provider.totals.totalFat.round()} / ${targets.fat.round()} g',
        ratio: fatProgress,
        color: goal.macros[2].color,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst: başlık + pasta özeti
          Row(
            children: [
              const Icon(
                Icons.pie_chart_rounded,
                color: Colors.white54,
                size: 15,
              ),
              const SizedBox(width: 7),
              const Text(
                'Makro Hedefler',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // Küçük renk legend
              Row(
                children: dynamicMacros
                    .map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: m.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              m.name
                                  .split('o')
                                  .first
                                  .replaceAll('Karb', 'K')
                                  .replaceAll('Protein', 'P')
                                  .replaceAll('Yağ', 'Y'),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Birleşik bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: dynamicMacros
                  .map(
                    (m) => Expanded(
                      flex: (m.ratio * 100).round(),
                      child: Container(height: 10, color: m.color),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          // Her makro satırı
          ...dynamicMacros.asMap().entries.map(
            (e) => Padding(
              padding: EdgeInsets.only(
                bottom: e.key < dynamicMacros.length - 1 ? 10 : 0,
              ),
              child: _MacroRow(macro: e.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final _Macro macro;
  const _MacroRow({required this.macro});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: macro.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          macro.name,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const Spacer(),
        Text(
          macro.amount,
          style: TextStyle(
            color: macro.color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: macro.ratio,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(macro.color),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Meal List ────────────────────────────────────────────────────────────────

class _MealList extends StatelessWidget {
  final _Goal goal;
  const _MealList({required this.goal});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      itemCount: goal.meals.length,
      itemBuilder: (_, i) => _MealCard(meal: goal.meals[i]),
    );
  }
}

class _MealCard extends StatelessWidget {
  final _MealIdea meal;
  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: meal.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: meal.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: meal.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(meal.icon, color: meal.accent, size: 17),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meal.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                meal.detail,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Daily Plan Card ──────────────────────────────────────────────────────────

class _DailyPlanCard extends StatelessWidget {
  final _Goal goal;
  const _DailyPlanCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: goal.dailyPlan.asMap().entries.map((e) {
          final meal = e.value;
          final isLast = e.key == goal.dailyPlan.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Zaman + ikon
                    SizedBox(
                      width: 52,
                      child: Column(
                        children: [
                          Text(
                            meal.time,
                            style: TextStyle(
                              color: goal.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Icon(
                            meal.icon,
                            color: goal.color.withValues(alpha: 0.6),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                    // Dikey çizgi
                    Container(
                      width: 1,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: goal.color.withValues(alpha: 0.2),
                    ),
                    // İçerik
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            meal.food,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            meal.macros,
                            style: TextStyle(
                              color: goal.color.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Timing Card ─────────────────────────────────────────────────────────────

class _TimingCard extends StatelessWidget {
  final _Goal goal;
  const _TimingCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimingHalf(
            label: goal.timing.preMeal,
            detail: goal.timing.preDetail,
            icon: Icons.arrow_upward_rounded,
            color: goal.color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TimingHalf(
            label: goal.timing.postMeal,
            detail: goal.timing.postDetail,
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF30D158),
          ),
        ),
      ],
    );
  }
}

class _TimingHalf extends StatelessWidget {
  final String label;
  final String detail;
  final IconData icon;
  final Color color;
  const _TimingHalf({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top Foods Grid ───────────────────────────────────────────────────────────

class _TopFoodsGrid extends StatelessWidget {
  final _Goal goal;
  const _TopFoodsGrid({required this.goal});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.45,
      children: goal.topFoods
          .map(
            (f) => Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: f.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: f.color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: f.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    f.highlight,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─── Rules Card ───────────────────────────────────────────────────────────────

class _RulesCard extends StatelessWidget {
  final _Goal goal;
  const _RulesCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: goal.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: goal.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: goal.rules.asMap().entries.map((e) {
          final isLast = e.key == goal.rules.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  decoration: BoxDecoration(
                    color: goal.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text(
                      '${e.key + 1}',
                      style: TextStyle(
                        color: goal.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.value,
                    style: const TextStyle(
                      color: Color(0xFFCCCCCC),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Avoid Card ───────────────────────────────────────────────────────────────

class _AvoidCard extends StatelessWidget {
  final _Goal goal;
  const _AvoidCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0808),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF453A).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: goal.avoid
            .map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3, right: 10),
                      child: Icon(
                        Icons.remove_circle_outline_rounded,
                        color: Color(0xFFFF453A),
                        size: 15,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        a,
                        style: const TextStyle(
                          color: Color(0xFFB0A0A0),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Supplement Chips ─────────────────────────────────────────────────────────

class _SupplementChips extends StatelessWidget {
  final _Goal goal;
  const _SupplementChips({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: goal.supplements
          .map(
            (s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: goal.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: goal.color.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science_rounded, color: goal.color, size: 12),
                  const SizedBox(width: 5),
                  Text(
                    s,
                    style: TextStyle(
                      color: goal.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─── General Tips Card ────────────────────────────────────────────────────────

class _GeneralTipsCard extends StatelessWidget {
  const _GeneralTipsCard();

  static const _tips = [
    (
      icon: Icons.water_drop_rounded,
      color: Color(0xFF0A84FF),
      text:
          'Günde en az 2–2.5 litre su iç. Açlık hissi çoğu zaman susuzluktur.',
    ),
    (
      icon: Icons.schedule_rounded,
      color: Color(0xFF30D158),
      text: 'Düzenli öğün saatleri tutmak metabolizmayı dengede tutar.',
    ),
    (
      icon: Icons.no_food_rounded,
      color: Color(0xFFFF453A),
      text: 'İşlenmiş gıda, hazır meyve suyu ve şekerli içeceklerden kaçın.',
    ),
    (
      icon: Icons.restaurant_rounded,
      color: Color(0xFFFF9F0A),
      text:
          'Tabağının yarısı sebze, çeyreği protein, çeyreği karbonhidrat olsun.',
    ),
    (
      icon: Icons.bedtime_rounded,
      color: Color(0xFFBF5AF2),
      text: 'Uyku kalitesi beslenme kadar önemlidir; 7–8 saat hedefle.',
    ),
    (
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFFF6B35),
      text: 'Direnç egzersizi + yeterli protein = kas korumanın anahtarı.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: _tips.asMap().entries.map((e) {
          final tip = e.value;
          final isLast = e.key == _tips.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 12, top: 1),
                  decoration: BoxDecoration(
                    color: tip.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tip.icon, color: tip.color, size: 16),
                ),
                Expanded(
                  child: Text(
                    tip.text,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
