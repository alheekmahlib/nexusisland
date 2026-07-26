import Combine
import Foundation
import SwiftUI

// MARK: - Stocks / Crypto Ticker Module
//
// Fetches crypto prices from CoinGecko (free, no key) and shows them in the
// island. Defaults to BTC, ETH, BNB, SOL.

struct CryptoPrice: Identifiable, Equatable {
    let id: String          // coingecko id (e.g. "bitcoin")
    let symbol: String      // "BTC"
    let priceUSD: Double
    let change24h: Double   // percentage

    var formattedPrice: String {
        if priceUSD >= 1 { return String(format: "$%.0f", priceUSD) }
        return String(format: "$%.4f", priceUSD)
    }

    var isUp: Bool { change24h >= 0 }
    var changeFormatted: String {
        let sign = isUp ? "+" : ""
        return "\(sign)\(String(format: "%.1f", change24h))%"
    }
}

@MainActor
final class StocksManager: ObservableObject {
    static let shared = StocksManager()

    @Published private(set) var prices: [CryptoPrice] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private var refreshToken: ModuleRefreshToken?

    /// Default coins to track (CoinGecko ids).
    private let trackedCoins: [(id: String, symbol: String)] = [
        ("bitcoin", "BTC"), ("ethereum", "ETH"), ("binancecoin", "BNB"), ("solana", "SOL")
    ]

    private init() {
        fetchPrices()
        registerRefresh()
    }

    func fetchPrices() {
        guard !isLoading else { return }
        isLoading = true
        let ids = trackedCoins.map(\.id).joined(separator: ",")
        let urlString = "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd&include_24hr_change=true"
        guard let url = URL(string: urlString) else { isLoading = false; return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let error { self.lastError = error.localizedDescription; return }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.lastError = "Bad response"; return
                }
                self.prices = self.trackedCoins.compactMap { coin in
                    guard let entry = json[coin.id] as? [String: Any],
                          let price = entry["usd"] as? Double else { return nil }
                    let change = entry["usd_24h_change"] as? Double ?? 0
                    return CryptoPrice(id: coin.id, symbol: coin.symbol, priceUSD: price, change24h: change)
                }
                self.lastError = nil
            }
        }.resume()
    }

    private func registerRefresh() {
        refreshToken = ModuleRefreshScheduler.shared.register(
            id: "stocks.refresh", name: "Stocks refresh",
            module: .builtIn(.stocks),
            policy: .interval(120, tolerance: 30), // every 2 min
            enabled: { AppState.shared.stocksEnabled }
        ) { [weak self] in self?.fetchPrices() }
    }

    deinit { let t = refreshToken; Task { @MainActor in ModuleRefreshScheduler.shared.unregister(t) } }
}

// MARK: - Views

struct StocksCompactView: View {
    @ObservedObject private var manager = StocksManager.shared

    var body: some View {
        if let first = manager.prices.first {
            HStack(spacing: 4) {
                Text(first.symbol).font(NexusTypography.caption(9)).foregroundColor(NexusPalette.textTertiary)
                Text(first.formattedPrice).font(NexusTypography.mono(10)).foregroundColor(first.isUp ? NexusPalette.success : NexusPalette.danger)
            }
        } else {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 11)).foregroundColor(NexusPalette.textTertiary)
        }
    }
}

struct StocksExpandedView: View {
    @ObservedObject private var manager = StocksManager.shared

    var body: some View {
        if manager.prices.isEmpty {
            Text(manager.isLoading ? "…" : "لا توجد بيانات")
                .font(NexusTypography.body(10)).foregroundColor(NexusPalette.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(manager.prices.prefix(4))) { coin in
                    HStack(spacing: 6) {
                        Text(coin.symbol).font(NexusTypography.body(10)).foregroundColor(NexusPalette.textSecondary)
                        Spacer()
                        Text(coin.formattedPrice).font(NexusTypography.mono(11)).foregroundColor(NexusPalette.textPrimary)
                        Text(coin.changeFormatted).font(NexusTypography.mono(9))
                            .foregroundColor(coin.isUp ? NexusPalette.success : NexusPalette.danger)
                    }.frame(width: 130)
                }
            }
        }
    }
}

struct StocksFullExpandedView: View {
    @ObservedObject private var manager = StocksManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("العملات الرقمية").font(NexusTypography.title(12)).foregroundColor(NexusPalette.textPrimary)
                Spacer()
                if manager.isLoading { ProgressView().scaleEffect(0.6).frame(width: 12, height: 12) }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .environment(\.layoutDirection, .rightToLeft)
            Divider().background(NexusPalette.glassTint.opacity(0.10))

            if manager.prices.isEmpty {
                Text("لا توجد بيانات").font(NexusTypography.body(11)).foregroundColor(NexusPalette.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(manager.prices) { coin in
                            HStack(spacing: 10) {
                                Text(coin.symbol).font(NexusTypography.title(13)).foregroundColor(NexusPalette.textPrimary)
                                    .frame(width: 50, alignment: .leading)
                                Spacer()
                                Text(coin.formattedPrice).font(NexusTypography.mono(13)).foregroundColor(NexusPalette.textPrimary)
                                Text(coin.changeFormatted).font(NexusTypography.mono(10))
                                    .foregroundColor(coin.isUp ? NexusPalette.success : NexusPalette.danger)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .nexusSurface(variant: .glass, radius: NexusMetrics.cornerRadiusS)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}
