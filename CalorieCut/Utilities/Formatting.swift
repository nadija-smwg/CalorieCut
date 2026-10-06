import Foundation

enum Units {
    static func weight(_ kg: Double, unit: String) -> Double { unit == "lb" ? kg * 2.2046226218 : kg }
    static func kilograms(_ value: Double, unit: String) -> Double { unit == "lb" ? value / 2.2046226218 : value }
    static func length(_ cm: Double, unit: String) -> Double { unit == "in" ? cm / 2.54 : cm }
    static func centimeters(_ value: Double, unit: String) -> Double { unit == "in" ? value * 2.54 : value }
}
extension Double {
    var whole: String { formatted(.number.precision(.fractionLength(0))) }
    var decimal: String { formatted(.number.precision(.fractionLength(1))) }
}
extension Date {
    var dayTitle: String { formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }
    func dayOffset(_ value: Int) -> Date { Calendar.current.date(byAdding: .day, value: value, to: self) ?? self }
    var loggingTime: Date { Calendar.current.isDateInToday(self) ? .now : min(self, .now) }
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}
enum AppError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): message } }
}
