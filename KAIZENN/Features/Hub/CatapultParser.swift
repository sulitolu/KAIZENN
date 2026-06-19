import Foundation

struct CatapultParser {

    static func parse(csvString: String) -> GPSSession? {
        var lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { return nil }

        let headerLine = lines.removeFirst()
        let headers = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        let distanceIdx = headers.firstIndex(where: { $0.lowercased().contains("distance") })
        let playerLoadIdx = headers.firstIndex(where: { $0.lowercased().contains("player load") })
        let sprintIdx = headers.firstIndex(where: { $0.lowercased().contains("sprint") })
        let hsrIdx = headers.firstIndex(where: { $0.lowercased().contains("high speed") })
        let durationIdx = headers.firstIndex(where: { $0.lowercased().contains("duration") })

        var totalDistance: Double = 0
        var totalPlayerLoad: Double = 0
        var totalSprints: Int = 0
        var hsrValues: [Double] = []
        var totalDuration: Double = 0
        var rowCount = 0

        for line in lines {
            let cols = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            rowCount += 1

            if let idx = distanceIdx, idx < cols.count {
                totalDistance += Double(cols[idx]) ?? 0
            }
            if let idx = playerLoadIdx, idx < cols.count {
                totalPlayerLoad += Double(cols[idx]) ?? 0
            }
            if let idx = sprintIdx, idx < cols.count {
                totalSprints += Int(Double(cols[idx]) ?? 0)
            }
            if let idx = hsrIdx, idx < cols.count {
                if let v = Double(cols[idx]) { hsrValues.append(v) }
            }
            if let idx = durationIdx, idx < cols.count {
                totalDuration += Double(cols[idx]) ?? 0
            }
        }

        guard rowCount > 0 else { return nil }

        var session = GPSSession()
        session.source = .catapultCSV
        session.distanceMeters = totalDistance
        session.playerLoad = totalPlayerLoad
        session.sprintCount = totalSprints
        session.highSpeedRunningPercent = hsrValues.isEmpty ? 0 : hsrValues.reduce(0, +) / Double(hsrValues.count)
        session.durationSeconds = totalDuration
        session.date = Date()
        return session
    }
}
