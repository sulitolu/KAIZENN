import XCTest
@testable import KAIZENN

final class GPSSessionTests: XCTestCase {

    func testSessionLoadNoHSR() {
        var s = GPSSession()
        s.distanceMeters = 6000
        s.highSpeedRunningPercent = 0
        // (6000/1000)*10 * (1 + 0/100) = 60 * 1 = 60
        XCTAssertEqual(s.sessionLoad, 60.0, accuracy: 0.0001)
    }

    func testSessionLoadWithHSR() {
        var s = GPSSession()
        s.distanceMeters = 6000
        s.highSpeedRunningPercent = 50
        // 60 * (1 + 0.5) = 90
        XCTAssertEqual(s.sessionLoad, 90.0, accuracy: 0.0001)
    }

    func testSessionLoadZeroDistance() {
        var s = GPSSession()
        s.distanceMeters = 0
        s.highSpeedRunningPercent = 80
        XCTAssertEqual(s.sessionLoad, 0.0, accuracy: 0.0001)
    }
}
