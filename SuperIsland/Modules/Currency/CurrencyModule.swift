import Combine
import Foundation
import SwiftUI

// MARK: - Currency Converter Module
//
// Fetches live exchange rates from open.er-api.com (free, no key) and shows
// a configurable conversion. Default: USD → SAR/AED/EUR/GBP.

struct CurrencyRate: Identifiable, Equatable {
    let id: String          // currency code
    let code: String
    let rate: Double        // 1 USD = rate
    let flag: String        // SF Symbol or emoji fallback

    var formattedRate: String {
        String(format: "%.2f", rate)
    }
}

@MainActor
final class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()

    @Published private(set) var rates: [CurrencyRate] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private var refreshToken: ModuleRefreshToken?

    /// Default currencies to show (relative to USD).
    private let defaultCurrencies = ["SAR", "AED", "EUR", "GBP", "EGP", "TRY"]

    private init() {
        fetchRates()
        registerRefresh()
    }

    func fetchRates() {
        guard !isLoading else { return }
        isLoading = true
        let url = URL(string: "https://open.er-api.com/v6/latest/USD")!

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let error { self.lastError = error.localizedDescription; return }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let rawRates = json["rates"] as? [String: Double] else {
                    self.lastError = "Bad response"; return
                }
                self.rates = self.defaultCurrencies.compactMap { code in
                    guard let rate = rawRates[code] else { return nil }
                    return CurrencyRate(id: code, code: code, rate: rate, flag: Self.flagFor(code))
                }
                self.lastError = nil
            }
        }.resume()
    }

    /// Convert an amount from USD to a target currency.
    func convert(amount: Double, to code: String) -> Double? {
        guard let rate = rates.first(where: { $0.code == code })?.rate else { return nil }
        return amount * rate
    }

    private static func flagFor(_ code: String) -> String {
        switch code {
        case "SAR", "AED", "EGP", "TRY", "EUR", "GBP": return "dollarsign.circle.fill"
        default: return "dollarsign.circle"
        }
    }

    private func registerRefresh() {
        refreshToken = ModuleRefreshScheduler.shared.register(
            id: "currency.refresh", name: "Currency refresh",
            module: .builtIn(.currency),
            policy: .interval(3600, tolerance: 300), // hourly
            enabled: { AppState.shared.currencyEnabled }
        ) { [weak self] in self?.fetchRates() }
    }

    deinit { let t = refreshToken; Task { @MainActor in ModuleRefreshScheduler.shared.unregister(t) } }
}

// MARK: - Views

struct CurrencyCompactView: View {
    @ObservedObject private var manager = CurrencyManager.shared

    var body: some View {
        if let first = manager.rates.first {
            HStack(spacing: 5) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 10)).foregroundColor(NexusPalette.electricViolet)
                Text("1$ = \(first.formattedRate)")
                    .font(NexusTypography.mono(9))
                    .foregroundColor(NexusPalette.textPrimary)
                Text(first.code)
                    .font(NexusTypography.caption(9))
                    .foregroundColor(NexusPalette.electricViolet)
            }
        } else {
            Image(systemName: "dollarsign.circle").font(.system(size: 11)).foregroundColor(NexusPalette.textTertiary)
        }
    }
}

struct CurrencyExpandedView: View {
    @ObservedObject private var manager = CurrencyManager.shared

    var body: some View {
        if manager.rates.isEmpty {
            Text(manager.isLoading ? "…" : "لا توجد بيانات")
                .font(NexusTypography.body(10)).foregroundColor(NexusPalette.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("1 دولار أمريكي =").font(NexusTypography.caption(9)).foregroundColor(NexusPalette.textTertiary)
                ForEach(manager.rates.prefix(4)) { rate in
                    HStack(spacing: 6) {
                        Text(rate.code).font(NexusTypography.body(10)).foregroundColor(NexusPalette.electricViolet)
                        Spacer()
                        Text(rate.formattedRate).font(NexusTypography.mono(11)).foregroundColor(NexusPalette.textPrimary)
                    }.frame(width: 120)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

struct CurrencyFullExpandedView: View {
    @ObservedObject private var manager = CurrencyManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("أسعار الصرف").font(NexusTypography.title(12)).foregroundColor(NexusPalette.textPrimary)
                Spacer()
                if manager.isLoading { ProgressView().scaleEffect(0.6).frame(width: 12, height: 12) }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .environment(\.layoutDirection, .rightToLeft)
            Divider().background(NexusPalette.glassTint.opacity(0.10))

            if manager.rates.isEmpty {
                Text("لا توجد بيانات").font(NexusTypography.body(11)).foregroundColor(NexusPalette.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        Text("1 دولار أمريكي =").font(NexusTypography.caption(9)).foregroundColor(NexusPalette.textTertiary)
                            .padding(.bottom, 4)
                        ForEach(manager.rates) { rate in
                            HStack(spacing: 10) {
                                Text(rate.code).font(NexusTypography.body(12)).foregroundColor(NexusPalette.electricViolet)
                                    .frame(width: 40, alignment: .leading)
                                Spacer()
                                Text(rate.formattedRate).font(NexusTypography.title(13)).foregroundColor(NexusPalette.textPrimary)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .nexusSurface(variant: .glass, radius: NexusMetrics.cornerRadiusS)
                            .environment(\.layoutDirection, .rightToLeft)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}
