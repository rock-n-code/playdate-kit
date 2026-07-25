internal import CPlaydate

extension System {
    /// A calendar date and time, mirroring `PDDateTime`.
    public struct DateTime: Sendable {
        public var year: UInt16
        /// 1...12
        public var month: UInt8
        /// 1...31
        public var day: UInt8
        /// 1 = Monday ... 7 = Sunday
        public var weekday: UInt8
        /// 0...23
        public var hour: UInt8
        public var minute: UInt8
        public var second: UInt8

        public init(year: UInt16, month: UInt8, day: UInt8, weekday: UInt8 = 0,
                    hour: UInt8, minute: UInt8, second: UInt8) {
            self.year = year
            self.month = month
            self.day = day
            self.weekday = weekday
            self.hour = hour
            self.minute = minute
            self.second = second
        }

        init(_ dateTime: PDDateTime) {
            year = dateTime.year
            month = dateTime.month
            day = dateTime.day
            weekday = dateTime.weekday
            hour = dateTime.hour
            minute = dateTime.minute
            second = dateTime.second
        }

        var cValue: PDDateTime {
            PDDateTime(year: year, month: month, day: day, weekday: weekday,
                       hour: hour, minute: minute, second: second)
        }
    }
}
