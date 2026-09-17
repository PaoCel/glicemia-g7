import XCTest
@testable import GlicemiaCore

final class FreshnessTests: XCTestCase {

    func testBoundariesMatchTheSensorCadence() {
        // A G7 publishes every five minutes, so anything under six is normal.
        XCTAssertEqual(Freshness.of(age: 0), .fresh)
        XCTAssertEqual(Freshness.of(age: 5 * 60), .fresh)
        XCTAssertEqual(Freshness.of(age: 6 * 60 - 1), .fresh)
        XCTAssertEqual(Freshness.of(age: 6 * 60), .delayed)
        XCTAssertEqual(Freshness.of(age: 12 * 60 - 1), .delayed)
        XCTAssertEqual(Freshness.of(age: 12 * 60), .stale)
        XCTAssertEqual(Freshness.of(age: 60 * 60), .stale)
    }

    func testStaleReadingLosesItsRangeColour() {
        // Acting on a twenty minute old "low" is worse than acting on no value at all,
        // so a stale reading must stop signalling urgency through colour.
        let lowFresh = GlucoseTheme.valueColor(55, freshness: .fresh)
        let lowStale = GlucoseTheme.valueColor(55, freshness: .stale)
        XCTAssertNotEqual(lowFresh, lowStale)
        XCTAssertEqual(lowStale, GlucoseTheme.secondaryText)
    }

    func testOutOfRangeAlwaysCarriesANonColourMarker() {
        // The Series 3 screen is small and often read in bad light: colour alone is
        // never allowed to be the only carrier of meaning.
        XCTAssertNotNil(GlucoseTheme.rangeGlyph(55))
        XCTAssertNotNil(GlucoseTheme.rangeGlyph(250))
        XCTAssertNil(GlucoseTheme.rangeGlyph(110))
    }
}

final class AgeFormattingTests: XCTestCase {

    func testReadsLikeSomethingAPersonWouldSay() {
        XCTAssertEqual(GlucoseFormatting.age(0), "adesso")
        XCTAssertEqual(GlucoseFormatting.age(44), "adesso")
        XCTAssertEqual(GlucoseFormatting.age(60), "1 min fa")
        XCTAssertEqual(GlucoseFormatting.age(5 * 60), "5 min fa")
        XCTAssertEqual(GlucoseFormatting.age(59 * 60), "59 min fa")
        XCTAssertEqual(GlucoseFormatting.age(60 * 60), "1 h fa")
        XCTAssertEqual(GlucoseFormatting.age(65 * 60), "1 h 05 fa")
        XCTAssertEqual(GlucoseFormatting.age(25 * 60 * 60), "ieri")
    }

    func testNegativeAgeNeverPrintsSomethingAbsurd() {
        // Clock skew between the sensor and the phone can put a reading in the future.
        XCTAssertEqual(GlucoseFormatting.age(-30), "adesso")
        XCTAssertEqual(GlucoseFormatting.age(-10_000), "adesso")
    }
}

final class WatchLinkTests: XCTestCase {

    func testReadingSurvivesTheRoundTrip() throws {
        let original = GlucoseReading(
            mgdl: 137,
            trend: .fortyFiveDown,
            date: Date(timeIntervalSince1970: 1_615_229_400),
            source: .dexcomShare
        )
        let payload = WatchLink.encode(reading: original, error: nil, sequence: 7)
        let snapshot = try XCTUnwrap(WatchLink.decode(payload))

        XCTAssertEqual(snapshot.reading, original)
        XCTAssertEqual(snapshot.sequence, 7)
        XCTAssertNil(snapshot.error)
    }

    func testPayloadHoldsOnlyPropertyListTypes() {
        // WCSession rejects anything else at runtime, silently breaking the link.
        let payload = WatchLink.encode(
            reading: GlucoseReading(mgdl: 100, trend: .flat, date: Date(), source: .mock),
            error: "guasto",
            sequence: 1
        )
        XCTAssertTrue(PropertyListSerialization.propertyList(payload, isValidFor: .binary))
    }

    func testAnErrorTravelsWithoutARReading() throws {
        let payload = WatchLink.encode(reading: nil, error: "server non raggiungibile", sequence: 3)
        let snapshot = try XCTUnwrap(WatchLink.decode(payload))
        XCTAssertNil(snapshot.reading)
        XCTAssertEqual(snapshot.error, "server non raggiungibile")
    }

    func testPayloadFromAnotherSchemaIsRefused() {
        var payload = WatchLink.encode(
            reading: GlucoseReading(mgdl: 100, trend: .flat, date: Date(), source: .mock),
            error: nil,
            sequence: 1
        )
        payload[WatchLink.Key.schema] = 99
        XCTAssertNil(WatchLink.decode(payload))
    }

    func testEmptyPayloadIsRefusedRatherThanDecodedAsBlank() {
        // A Watch launching before the iPhone has sent anything reads an empty context.
        XCTAssertNil(WatchLink.decode([:]))
    }
}
