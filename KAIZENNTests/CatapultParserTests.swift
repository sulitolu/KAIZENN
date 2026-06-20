import XCTest
@testable import KAIZENN

final class CatapultParserTests: XCTestCase {

    func testValidTwoRowCSV() {
        let csv = """
        Distance,Player Load,Sprints,High Speed Running
        3000,250,5,40
        3000,250,5,60
        """
        let session = CatapultParser.parse(csvString: csv)
        XCTAssertNotNil(session)
        guard let s = session else { return }
        XCTAssertEqual(s.distanceMeters, 6000, accuracy: 0.0001)
        XCTAssertEqual(s.playerLoad, 500, accuracy: 0.0001)
        XCTAssertEqual(s.sprintCount, 10)
        // HSR is averaged: (40 + 60) / 2 = 50
        XCTAssertEqual(s.highSpeedRunningPercent, 50, accuracy: 0.0001)
        XCTAssertEqual(s.source, .catapultCSV)
    }

    func testEmptyStringReturnsNil() {
        XCTAssertNil(CatapultParser.parse(csvString: ""))
    }

    func testHeaderOnlyReturnsNil() {
        let csv = "Distance,Player Load,Sprints,High Speed Running"
        XCTAssertNil(CatapultParser.parse(csvString: csv))
    }

    func testNonNumericCellsContributeZero() {
        let csv = """
        Distance,Player Load,Sprints,High Speed Running
        abc,xyz,foo,bar
        1000,100,2,30
        """
        let session = CatapultParser.parse(csvString: csv)
        XCTAssertNotNil(session)
        guard let s = session else { return }
        // Row 1 non-numeric -> 0; row 2 valid
        XCTAssertEqual(s.distanceMeters, 1000, accuracy: 0.0001)
        XCTAssertEqual(s.playerLoad, 100, accuracy: 0.0001)
        XCTAssertEqual(s.sprintCount, 2)
        // Only one parseable HSR value (30) -> average is 30
        XCTAssertEqual(s.highSpeedRunningPercent, 30, accuracy: 0.0001)
    }
}
