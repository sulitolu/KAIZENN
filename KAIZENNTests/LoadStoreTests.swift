import XCTest
@testable import KAIZENN

final class LoadStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: GPSSession.storageKey)
        UserDefaults.standard.removeObject(forKey: StrengthSession.storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: GPSSession.storageKey)
        UserDefaults.standard.removeObject(forKey: StrengthSession.storageKey)
        super.tearDown()
    }

    /// Build a GPS session dated `daysAgo` days back with a known sessionLoad.
    /// sessionLoad = (distanceMeters/1000)*10 * (1 + HSR/100). With HSR = 0,
    /// distanceMeters = load*100 yields the requested load.
    private func gpsSession(load: Double, daysAgo: Double) -> GPSSession {
        var s = GPSSession()
        s.highSpeedRunningPercent = 0
        s.distanceMeters = load * 100
        s.date = Date().addingTimeInterval(-daysAgo * 86400)
        return s
    }

    func testFreshStoreACWRIsZero() {
        let store = LoadStore()
        XCTAssertEqual(store.acuteLoad, 0, accuracy: 0.0001)
        XCTAssertEqual(store.chronicLoad, 0, accuracy: 0.0001)
        XCTAssertEqual(store.acwr, 0, accuracy: 0.0001)
    }

    func testAddTodaySessionUpdatesAcuteLoad() {
        let store = LoadStore()
        let s = gpsSession(load: 50, daysAgo: 0)
        XCTAssertEqual(s.sessionLoad, 50, accuracy: 0.0001)
        store.addGPSSession(s)
        XCTAssertEqual(store.acuteLoad, 50, accuracy: 0.0001)
    }

    func testChronicLoadIsTotalOverFour() {
        let store = LoadStore()
        // All within the 28-day window.
        store.addGPSSession(gpsSession(load: 40, daysAgo: 1))
        store.addGPSSession(gpsSession(load: 60, daysAgo: 10))
        store.addGPSSession(gpsSession(load: 100, daysAgo: 20))
        // total = 200, chronic = 200 / 4 = 50
        XCTAssertEqual(store.chronicLoad, 50, accuracy: 0.0001)
    }

    func testACWRForConstructedScenario() {
        let store = LoadStore()
        // One session today (counts in both acute and chronic windows)
        store.addGPSSession(gpsSession(load: 80, daysAgo: 0))
        // One session 20 days ago (chronic only)
        store.addGPSSession(gpsSession(load: 40, daysAgo: 20))
        // acute = 80
        // chronic = (80 + 40) / 4 = 30
        // acwr = 80 / 30 = 2.666...
        XCTAssertEqual(store.acuteLoad, 80, accuracy: 0.0001)
        XCTAssertEqual(store.chronicLoad, 30, accuracy: 0.0001)
        XCTAssertEqual(store.acwr, 80.0 / 30.0, accuracy: 0.0001)
    }
}
