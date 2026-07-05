//
//  PusulaFitWidget.swift
//  PusulaFitWidget
//
//  Kilit ekranı + ana ekran widget'ları: kalan kalori, protein, su.
//  Veri, Flutter tarafından home_widget paketiyle App Group'a yazılır
//  (bkz. lib/core/services/lock_screen_widget_service.dart).
//
//  Özellikler:
//  - Gece yarısında otomatik sıfırlanan timeline
//  - Widget'a dokununca Beslenme sekmesine derin bağlantı (homeWidget://nutrition)
//  - iOS 17+: uygulamayı açmadan +250 ml su ekleyen etkileşimli buton
//  - Protein ve su için ayrı dairesel kilit ekranı widget'ları
//

import WidgetKit
import SwiftUI
#if canImport(AppIntents)
import AppIntents
#endif

let appGroupId = "group.com.eneskotay.fitnessapp"
let nutritionDeepLink = URL(string: "homeWidget://nutrition")

// MARK: - Model

struct NutritionEntry: TimelineEntry {
    let date: Date
    let remainingKcal: Int
    let targetKcal: Int
    let consumedKcal: Int
    let proteinG: Int
    let proteinTargetG: Int
    let waterL: Double
    let waterTargetL: Double

    static let placeholder = NutritionEntry(
        date: .now,
        remainingKcal: 1450,
        targetKcal: 2000,
        consumedKcal: 550,
        proteinG: 62,
        proteinTargetG: 112,
        waterL: 1.2,
        waterTargetL: 2.0
    )

    /// App Group UserDefaults'tan güncel veriyi okur.
    static func load() -> NutritionEntry {
        guard let d = UserDefaults(suiteName: appGroupId) else { return .placeholder }
        let target = d.integer(forKey: "target_kcal")
        // Hiç veri yazılmamışsa placeholder göster
        guard target > 0 else { return .placeholder }
        let waterTarget = d.double(forKey: "water_target_l")
        return NutritionEntry(
            date: .now,
            remainingKcal: d.integer(forKey: "remaining_kcal"),
            targetKcal: target,
            consumedKcal: d.integer(forKey: "consumed_kcal"),
            proteinG: d.integer(forKey: "protein_g"),
            proteinTargetG: d.integer(forKey: "protein_target_g"),
            waterL: d.double(forKey: "water_l"),
            waterTargetL: waterTarget > 0 ? waterTarget : 2.0
        )
    }

    /// Gece yarısı için sıfırlanmış kopya (hedefler korunur).
    func reset(at date: Date) -> NutritionEntry {
        NutritionEntry(
            date: date,
            remainingKcal: targetKcal,
            targetKcal: targetKcal,
            consumedKcal: 0,
            proteinG: 0,
            proteinTargetG: proteinTargetG,
            waterL: 0,
            waterTargetL: waterTargetL
        )
    }

    var consumedFraction: Double {
        guard targetKcal > 0 else { return 0 }
        return min(1.0, max(0.0, Double(consumedKcal) / Double(targetKcal)))
    }

    var proteinFraction: Double {
        guard proteinTargetG > 0 else { return 0 }
        return min(1.0, max(0.0, Double(proteinG) / Double(proteinTargetG)))
    }

    var waterFraction: Double {
        guard waterTargetL > 0 else { return 0 }
        return min(1.0, max(0.0, waterL / waterTargetL))
    }
}

// MARK: - Provider

struct NutritionProvider: TimelineProvider {
    func placeholder(in context: Context) -> NutritionEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (NutritionEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NutritionEntry>) -> Void) {
        let now = Date()
        let current = NutritionEntry.load()
        var entries = [current]

        // Gece yarısında değerleri sıfırla — uygulama açılmasa bile
        // widget dünkü veriyi göstermeye devam etmesin.
        let calendar = Calendar.current
        if let midnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) {
            entries.append(current.reset(at: midnight))
        }

        // Uygulama her veri değişiminde WidgetCenter üzerinden yenileme tetikliyor;
        // yine de 30 dk'da bir kendiliğinden tazelensin.
        let refresh = calendar.date(byAdding: .minute, value: 30, to: now)!
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

// MARK: - Su Ekleme Intent'i (iOS 17+)

#if canImport(AppIntents)
@available(iOS 17.0, *)
struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Su Ekle"
    static var description = IntentDescription("Günlük su takibine 250 ml ekler.")

    func perform() async throws -> some IntentResult {
        guard let d = UserDefaults(suiteName: appGroupId) else { return .result() }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let today = fmt.string(from: .now)

        // Uygulama açılınca senkronize edilecek bekleyen miktar.
        var pending = d.integer(forKey: "pending_water_ml")
        if d.string(forKey: "pending_water_date") != today { pending = 0 }
        pending += 250
        d.set(pending, forKey: "pending_water_ml")
        d.set(today, forKey: "pending_water_date")

        // Widget'ta anında görünsün.
        let water = min(d.double(forKey: "water_l") + 0.25, 6.0)
        d.set(water, forKey: "water_l")

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
#endif

// MARK: - Renkler

private let brandGold = Color(red: 0.92, green: 0.76, blue: 0.45)
private let brandOrange = Color(red: 1.0, green: 0.47, blue: 0.22)
private let brandAqua = Color(red: 0.25, green: 0.83, blue: 0.95)
private let widgetBackgroundStart = Color(red: 0.10, green: 0.10, blue: 0.13)
private let widgetBackgroundEnd = Color(red: 0.21, green: 0.17, blue: 0.12)

// MARK: - Ana Widget Görünümleri

struct PusulaFitWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: NutritionEntry

    private static let kcalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private var remainingKcalText: String {
        Self.kcalFormatter.string(from: NSNumber(value: entry.remainingKcal))
            ?? "\(entry.remainingKcal)"
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circular
            case .accessoryRectangular:
                rectangular
            case .accessoryInline:
                Text("🔥 \(remainingKcalText) kcal kaldı")
            case .systemMedium:
                medium
            default:
                small
            }
        }
        .widgetURL(nutritionDeepLink)
    }

    /// Kilit ekranı — dairesel: kalan kalori gauge'u (buzlu arka planlı)
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Gauge(value: entry.consumedFraction) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .widgetAccentable()
            } currentValueLabel: {
                VStack(spacing: -2) {
                    Text(remainingKcalText)
                        .font(.system(.body, design: .rounded).weight(.heavy))
                        .minimumScaleFactor(0.45)
                        .monospacedDigit()
                    Text("kcal")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
    }

    /// Kilit ekranı — dikdörtgen: büyük kalori rakamı + mini göstergeler
    private var rectangular: some View {
        HStack(alignment: .center, spacing: 9) {
            VStack(alignment: .leading, spacing: -1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(remainingKcalText)
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.48)
                        .monospacedDigit()
                    Text("kcal")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .widgetAccentable()
                .lineLimit(1)

                Text("bugün kalan")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 74, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                miniGauge(
                    icon: "fork.knife",
                    fraction: entry.proteinFraction,
                    value: "\(entry.proteinG)g"
                )
                miniGauge(
                    icon: "drop.fill",
                    fraction: entry.waterFraction,
                    value: String(format: "%.1fL", entry.waterL)
                )
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Dikdörtgen widget için ikon + kapasite çubuğu + değer satırı
    private func miniGauge(
        icon: String,
        fraction: Double,
        value: String
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 11)
                .widgetAccentable()
            Gauge(value: fraction) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .widgetAccentable()
            Text(value)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 29, alignment: .trailing)
        }
    }

    /// Ana ekran — küçük kart
    private var small: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(brandOrange)
                Text("PusulaFit")
                    .font(.caption.bold())
                Spacer()
            }

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(remainingKcalText)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .monospacedDigit()
                    .lineLimit(1)
                Text("kcal")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Text("bugün kalan enerji")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            ProgressView(value: entry.consumedFraction)
                .tint(brandOrange)

            HStack {
                Label("\(entry.proteinG)g", systemImage: "fork.knife")
                Spacer()
                Label(String(format: "%.1fL", entry.waterL), systemImage: "drop.fill")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    /// Ana ekran — orta boy: gauge + makro çubukları + su butonu
    private var medium: some View {
        HStack(spacing: 14) {
            VStack(spacing: 4) {
                Gauge(value: entry.consumedFraction) {
                    Image(systemName: "flame.fill")
                } currentValueLabel: {
                    Text(remainingKcalText)
                        .font(.system(.body, design: .rounded).weight(.heavy))
                        .minimumScaleFactor(0.45)
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(brandOrange)
                Text("kcal kaldı")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                metricBar(
                    icon: "fork.knife",
                    label: "Protein",
                    value: "\(entry.proteinG)/\(entry.proteinTargetG) g",
                    fraction: entry.proteinFraction,
                    tint: brandGold
                )
                metricBar(
                    icon: "drop.fill",
                    label: "Su",
                    value: String(
                        format: "%.1f/%.1f L", entry.waterL, entry.waterTargetL
                    ),
                    fraction: entry.waterFraction,
                    tint: brandAqua
                )
            }
            .frame(maxWidth: .infinity)

            if #available(iOS 17.0, *) {
                Button(intent: AddWaterIntent()) {
                    VStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                        Text("+250")
                            .font(.caption2.bold())
                    }
                    .padding(10)
                }
                .buttonStyle(.bordered)
                .tint(brandAqua)
            }
        }
    }

    private func metricBar(
        icon: String,
        label: String,
        value: String,
        fraction: Double,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2).foregroundStyle(tint)
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.caption2.bold())
            }
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(tint)
        }
    }

    @ViewBuilder
    static func widgetBackground() -> some View {
        LinearGradient(
            colors: [widgetBackgroundStart, widgetBackgroundEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Ana Widget

struct PusulaFitWidget: Widget {
    let kind: String = "PusulaFitWidget"

    private var families: [WidgetFamily] {
        [
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
            .systemSmall, .systemMedium
        ]
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionProvider()) { entry in
            if #available(iOS 17.0, *) {
                PusulaFitWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        PusulaFitWidgetEntryView.widgetBackground()
                    }
            } else {
                PusulaFitWidgetEntryView(entry: entry)
                    .padding()
            }
        }
        .configurationDisplayName("Günlük Beslenme")
        .description("Kalori, protein ve su hedeflerini tek bakışta takip et.")
        .supportedFamilies(families)
    }
}

// MARK: - Protein Widget (dairesel)

struct PusulaFitProteinWidget: Widget {
    let kind: String = "PusulaFitProteinWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionProvider()) { entry in
            proteinView(entry)
        }
        .configurationDisplayName("Protein")
        .description("Günlük protein hedefine ilerlemeni gösterir.")
        .supportedFamilies([.accessoryCircular])
    }

    @ViewBuilder
    private func proteinView(_ entry: NutritionEntry) -> some View {
        let gauge = ZStack {
            AccessoryWidgetBackground()
            Gauge(value: entry.proteinFraction) {
                Image(systemName: "fork.knife")
                    .font(.caption2)
                    .widgetAccentable()
            } currentValueLabel: {
                VStack(spacing: -2) {
                    Text("\(entry.proteinG)")
                        .font(.system(.body, design: .rounded).weight(.heavy))
                        .minimumScaleFactor(0.55)
                    Text("g")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .gaugeStyle(.accessoryCircular)
        }
        .widgetURL(nutritionDeepLink)

        if #available(iOS 17.0, *) {
            gauge.containerBackground(.fill.tertiary, for: .widget)
        } else {
            gauge
        }
    }
}

// MARK: - Su Widget (dairesel)

struct PusulaFitWaterWidget: Widget {
    let kind: String = "PusulaFitWaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionProvider()) { entry in
            waterView(entry)
        }
        .configurationDisplayName("Su")
        .description("Bugün içtiğin su miktarını gösterir.")
        .supportedFamilies([.accessoryCircular])
    }

    @ViewBuilder
    private func waterView(_ entry: NutritionEntry) -> some View {
        let gauge = ZStack {
            AccessoryWidgetBackground()
            Gauge(value: entry.waterFraction) {
                Image(systemName: "drop.fill")
                    .font(.caption2)
                    .widgetAccentable()
            } currentValueLabel: {
                VStack(spacing: -2) {
                    Text(String(format: "%.1f", entry.waterL))
                        .font(.system(.body, design: .rounded).weight(.heavy))
                        .minimumScaleFactor(0.55)
                    Text("L")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .gaugeStyle(.accessoryCircular)
        }
        .widgetURL(nutritionDeepLink)

        if #available(iOS 17.0, *) {
            gauge.containerBackground(.fill.tertiary, for: .widget)
        } else {
            gauge
        }
    }
}
