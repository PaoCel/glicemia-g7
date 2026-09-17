import XCTest
@testable import GlicemiaCore

/// The Dexcom Share service is not versioned and not documented. These tests pin the
/// shapes it actually returns, because a parsing mistake here does not crash the app:
/// it shows a wrong glucose number, which is the worst way this app can fail.
final class DexcomParsingTests: XCTestCase {

    private func decode(_ json: String) throws -> [DexcomShareClient.Entry] {
        try JSONDecoder().decode([DexcomShareClient.Entry].self, from: Data(json.utf8))
    }

    // MARK: - Timestamps

    func testParsesBareDateStamp() throws {
        let entries = try decode("""
        [{"WT":"Date(1615229400000)","ST":"Date(1615229400000)","Value":123,"Trend":"Flat"}]
        """)
        XCTAssertEqual(entries.first?.date, Date(timeIntervalSince1970: 1_615_229_400))
    }

    func testParsesSlashWrappedStampWithOffset() throws {
        let entries = try decode("""
        [{"WT":"/Date(1615229400000+0000)/","ST":"/Date(1615229400000+0000)/","Value":123,"Trend":"Flat"}]
        """)
        XCTAssertEqual(entries.first?.date, Date(timeIntervalSince1970: 1_615_229_400))
    }

    func testOffsetDoesNotShiftTheInstant() throws {
        // The trailing offset describes the sender's timezone; the epoch is already UTC.
        // Applying it would move a reading by hours and make "2 min fa" a lie.
        let plus = try decode("""
        [{"WT":"Date(1615229400000+0200)","Value":100,"Trend":"Flat"}]
        """)
        let minus = try decode("""
        [{"WT":"Date(1615229400000-0500)","Value":100,"Trend":"Flat"}]
        """)
        XCTAssertEqual(plus.first?.date, minus.first?.date)
    }

    func testPrefersSensorTimeOverPhoneTime() throws {
        // WT is when the sensor measured; ST is when a phone uploaded it. Using ST would
        // make a delayed upload look like a fresh reading.
        let entries = try decode("""
        [{"WT":"Date(1615229400000)","ST":"Date(1615229999000)","Value":123,"Trend":"Flat"}]
        """)
        XCTAssertEqual(entries.first?.date, Date(timeIntervalSince1970: 1_615_229_400))
    }

    func testFallsBackToPhoneTimeWhenSensorTimeIsAbsent() throws {
        let entries = try decode("""
        [{"ST":"Date(1615229400000)","Value":123,"Trend":"Flat"}]
        """)
        XCTAssertEqual(entries.first?.date, Date(timeIntervalSince1970: 1_615_229_400))
    }

    func testRejectsEntryWithoutAnyTimestamp() {
        XCTAssertThrowsError(try decode("""
        [{"Value":123,"Trend":"Flat"}]
        """))
    }

    // MARK: - Trend

    func testParsesTrendAsName() throws {
        let entries = try decode("""
        [{"WT":"Date(1615229400000)","Value":123,"Trend":"FortyFiveUp"}]
        """)
        XCTAssertEqual(entries.first?.trend, .fortyFiveUp)
    }

    func testParsesTrendAsNumber() throws {
        // Older deployments answer with the numeric form; 4 is Flat.
        let entries = try decode("""
        [{"WT":"Date(1615229400000)","Value":123,"Trend":4}]
        """)
        XCTAssertEqual(entries.first?.trend, .flat)
    }

    func testTrendNameIsCaseInsensitive() throws {
        let entries = try decode("""
        [{"WT":"Date(1615229400000)","Value":123,"Trend":"doubledown"}]
        """)
        XCTAssertEqual(entries.first?.trend, .doubleDown)
    }

    func testUnknownTrendDoesNotFailTheReading() throws {
        // A trend we cannot read is not a reason to throw away a valid glucose value.
        let entries = try decode("""
        [{"WT":"Date(1615229400000)","Value":123,"Trend":"Wobbly"}]
        """)
        XCTAssertEqual(entries.first?.value, 123)
        XCTAssertEqual(entries.first?.trend, .unknown)
        XCTAssertFalse(entries.first!.trend.isKnown)
    }

    func testNumericTrendCoversEveryDocumentedCase() {
        XCTAssertEqual(TrendDirection(shareValue: 0), .unknown)
        XCTAssertEqual(TrendDirection(shareValue: 1), .doubleUp)
        XCTAssertEqual(TrendDirection(shareValue: 2), .singleUp)
        XCTAssertEqual(TrendDirection(shareValue: 3), .fortyFiveUp)
        XCTAssertEqual(TrendDirection(shareValue: 4), .flat)
        XCTAssertEqual(TrendDirection(shareValue: 5), .fortyFiveDown)
        XCTAssertEqual(TrendDirection(shareValue: 6), .singleDown)
        XCTAssertEqual(TrendDirection(shareValue: 7), .doubleDown)
        XCTAssertEqual(TrendDirection(shareValue: 8), .notComputable)
        XCTAssertEqual(TrendDirection(shareValue: 9), .rateOutOfRange)
        XCTAssertEqual(TrendDirection(shareValue: 99), .unknown)
    }

    // MARK: - Value

    func testKeepsExtremeValuesVerbatim() throws {
        // 40 and 400 are the ends of the Dexcom range and must not be clamped away.
        let entries = try decode("""
        [{"WT":"Date(1615229400000)","Value":40,"Trend":"SingleDown"},
         {"WT":"Date(1615229400000)","Value":400,"Trend":"SingleUp"}]
        """)
        XCTAssertEqual(entries.map(\.value), [40, 400])
    }
}
