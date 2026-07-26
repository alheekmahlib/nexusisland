import SwiftUI
import Charts

// MARK: - NexusDesign: SparklineChart
//
// A minimal Swift Charts sparkline (no axes, no legend) with a vibrant line
// and a glowing endpoint dot marking the latest value. Replaces the per-module
// hand-rolled `Path` sparklines (BatteryHistorySparkline, Stocks, GitStats).
// Swift Charts is built into macOS 13+, so this adds no dependency.

struct SparklineChart: View {
    var values: [Double]
    var lineColor: Color = NexusPalette.gradientMid
    var endpointColor: Color = NexusPalette.gradientEnd

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("i", index),
                    y: .value("v", value)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

                if index == values.count - 1 {
                    PointMark(
                        x: .value("i", index),
                        y: .value("v", value)
                    )
                    .foregroundStyle(endpointColor)
                    .symbolSize(18)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { $0.background(.clear) }
    }
}
