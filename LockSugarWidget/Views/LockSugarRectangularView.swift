import SwiftUI
import WidgetKit
import Charts

public struct LockSugarRectangularView: View {
    public let reading: GlucoseReading?
    public let history: [GlucoseReading]
    public let forecast: [GlucoseForecastPoint]
    public let targetLow: Double
    public let targetHigh: Double
    public let isDynamicYAxisEnabled: Bool
    
    public init(
        reading: GlucoseReading?,
        history: [GlucoseReading] = [],
        forecast: [GlucoseForecastPoint] = [],
        targetLow: Double = GlucoseZone.defaultTargetLow,
        targetHigh: Double = GlucoseZone.defaultTargetHigh,
        isDynamicYAxisEnabled: Bool = true
    ) {
        self.reading = reading
        self.history = history
        self.forecast = forecast
        self.targetLow = targetLow
        self.targetHigh = targetHigh
        self.isDynamicYAxisEnabled = isDynamicYAxisEnabled
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            headerView
            chartView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // MARK: - Header
    
    @ViewBuilder
    private var headerView: some View {
        if let reading = reading {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(reading.formattedValue)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(reading.zoneColor)
                        .widgetAccentable()
                    
                    Text(reading.trendArrowSymbol)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(reading.zoneColor)
                        .widgetAccentable()
                }
                
                Spacer()
                
                Text(reading.formattedTime)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .opacity(reading.isStale() ? 0.5 : 1.0)
        } else {
            HStack {
                Text("---")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .opacity(0.5)
        }
    }
    
    // MARK: - Chart View
    
    @ViewBuilder
    private var chartView: some View {
        let chartData = prepareChartData()
        let lineColor = reading?.zoneColor ?? .glucoseNormal
        
        Chart {
            // Target Range reference boundaries
            RuleMark(y: .value("TargetLow", targetLow))
                .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
                .foregroundStyle(Color.secondary.opacity(0.35))
            
            RuleMark(y: .value("TargetHigh", targetHigh))
                .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
                .foregroundStyle(Color.secondary.opacity(0.35))
            
            // Forecast Uncertainty Band
            ForEach(chartData.forecastBand) { point in
                AreaMark(
                    x: .value("Time", point.timestamp),
                    yStart: .value("Low", point.lowerBound),
                    yEnd: .value("High", point.upperBound)
                )
                .foregroundStyle(lineColor.opacity(0.18))
            }
            
            // Historical Readings Curve (Solid)
            ForEach(chartData.recentHistory, id: \.timestamp) { item in
                LineMark(
                    x: .value("Time", item.timestamp),
                    y: .value("Glucose", item.valueInMgPerDl)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.0))
                .foregroundStyle(lineColor)
            }
            
            // Dot for current reading
            if let latest = chartData.recentHistory.last {
                PointMark(
                    x: .value("Time", latest.timestamp),
                    y: .value("Glucose", latest.valueInMgPerDl)
                )
                .symbolSize(16)
                .foregroundStyle(lineColor)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                AxisValueLabel(format: Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.system(size: 8, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: chartData.yAxisTicks) { value in
                AxisValueLabel {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: chartData.yAxisMin...chartData.yAxisMax)
        .widgetAccentable()
    }
    
    // MARK: - Data Preparation
    
    private struct PreparedChartData {
        let recentHistory: [GlucoseReading]
        let forecastLine: [GlucoseForecastPoint]
        let forecastBand: [GlucoseForecastPoint]
        let yAxisMin: Double
        let yAxisMax: Double
        let yAxisTicks: [Int]
    }
    
    private func prepareChartData() -> PreparedChartData {
        let now = reading?.timestamp ?? Date()
        let cutoff = now.addingTimeInterval(-3.25 * 3600) // ~3 hours of history
        
        var recent = history.filter { $0.timestamp >= cutoff }.sorted(by: { $0.timestamp < $1.timestamp })
        if let reading = reading {
            if !recent.contains(where: { abs($0.timestamp.timeIntervalSince(reading.timestamp)) < 1.0 }) {
                recent.append(reading)
                recent.sort(by: { $0.timestamp < $1.timestamp })
            }
        }
        
        // Connect the forecast line and band seamlessly starting from the last historical point
        var forecastLinePoints: [GlucoseForecastPoint] = []
        var forecastBandPoints: [GlucoseForecastPoint] = []
        
        if let last = recent.last, !forecast.isEmpty {
            let connectionPoint = GlucoseForecastPoint(
                timestamp: last.timestamp,
                value: last.valueInMgPerDl,
                lowerBound: last.valueInMgPerDl,
                upperBound: last.valueInMgPerDl
            )
            forecastLinePoints.append(connectionPoint)
            forecastBandPoints.append(connectionPoint)
        }
        forecastLinePoints.append(contentsOf: forecast)
        forecastBandPoints.append(contentsOf: forecast)
        
        let yAxisMin: Double
        let yAxisMax: Double
        let yAxisTicks: [Int]
        
        if isDynamicYAxisEnabled {
            // Current calibrated Y-axis: (min - 5) to (max + 5) of the actually available values
            var availableValues = recent.map(\.valueInMgPerDl)
            if availableValues.isEmpty {
                if let reading = reading {
                    availableValues = [reading.valueInMgPerDl]
                } else {
                    availableValues = [targetLow, targetHigh]
                }
            }
            
            let minVal = availableValues.min() ?? 70.0
            let maxVal = availableValues.max() ?? 180.0
            
            yAxisMin = max(0.0, minVal - 5.0)
            yAxisMax = min(500.0, maxVal + 5.0)
            
            let step = (yAxisMax - yAxisMin) / 2.0
            let mid = yAxisMin + step
            yAxisTicks = [Int(round(yAxisMin)), Int(round(mid)), Int(round(yAxisMax))]
        } else {
            // Previous Y-axis: broad range including targets (70-180) and forecast bounds
            var allValues = recent.map(\.valueInMgPerDl)
            allValues.append(contentsOf: forecast.map(\.value))
            allValues.append(contentsOf: forecast.map(\.lowerBound))
            allValues.append(contentsOf: forecast.map(\.upperBound))
            allValues.append(targetLow)
            allValues.append(targetHigh)
            
            let minVal = allValues.min() ?? 60.0
            let maxVal = allValues.max() ?? 160.0
            
            yAxisMin = max(40.0, floor((minVal - 10.0) / 10.0) * 10.0)
            yAxisMax = min(350.0, ceil((maxVal + 15.0) / 10.0) * 10.0)
            
            if yAxisMax <= 180 && yAxisMin >= 50 {
                yAxisTicks = [60, 110, 160]
            } else {
                let step = (yAxisMax - yAxisMin) / 2.0
                let mid = round((yAxisMin + step) / 10.0) * 10.0
                yAxisTicks = [Int(yAxisMin), Int(mid), Int(yAxisMax)]
            }
        }
        
        return PreparedChartData(
            recentHistory: recent,
            forecastLine: forecastLinePoints,
            forecastBand: forecastBandPoints,
            yAxisMin: yAxisMin,
            yAxisMax: yAxisMax,
            yAxisTicks: yAxisTicks
        )
    }
}

public struct LockSugarMediumView: View {
    public let reading: GlucoseReading?
    public let history: [GlucoseReading]
    public let forecast: [GlucoseForecastPoint]
    public let targetLow: Double
    public let targetHigh: Double
    public let isDynamicYAxisEnabled: Bool
    
    public init(
        reading: GlucoseReading?,
        history: [GlucoseReading] = [],
        forecast: [GlucoseForecastPoint] = [],
        targetLow: Double = GlucoseZone.defaultTargetLow,
        targetHigh: Double = GlucoseZone.defaultTargetHigh,
        isDynamicYAxisEnabled: Bool = true
    ) {
        self.reading = reading
        self.history = history
        self.forecast = forecast
        self.targetLow = targetLow
        self.targetHigh = targetHigh
        self.isDynamicYAxisEnabled = isDynamicYAxisEnabled
    }
    
    public var body: some View {
        LockSugarRectangularView(
            reading: reading,
            history: history,
            forecast: forecast,
            targetLow: targetLow,
            targetHigh: targetHigh,
            isDynamicYAxisEnabled: isDynamicYAxisEnabled
        )
        .padding(4)
    }
}
