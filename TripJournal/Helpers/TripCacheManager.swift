//
//  TripCacheManager.swift
//  TripJournal
//
//  Created by Jesus Guerra on 5/18/24.
//

import Foundation

class TripCacheManager {
    private let userDefaults = UserDefaults.standard
    private let tripsKey = "trips"
    private let tripKey = "trip"

    func saveTrips(_ trips: [Trip]) {
        do {
            // Encode trips array into JSON data and save it to UserDefaults using tripsKey
            let data = try JSONEncoder().encode(trips)
            userDefaults.set(data, forKey: tripsKey)
        } catch {
            print("Failed to save trips to UserDefaults: \(error)")
        }
    }

    func loadTrips() -> [Trip] {
        // Retrieve data from UserDefaults using tripsKey; if no data is found, return an empty array

        guard let data = userDefaults.data(forKey: tripsKey) else {
            return []
        }
        do {
//            Decode the retrieved data using JSONDecoder to convert it back into an array of Trip objects.
            return try JSONDecoder().decode([Trip].self, from: data)
        } catch {
            return []
        }
    }
    
    func loadTrip() -> Trip {
        // Retrieve data from UserDefaults using tripsKey; if no data is found, return an empty array

        guard let data = userDefaults.data(forKey: tripKey) else {
            return   Trip(
                    id: 1,
                    name: "A Great Adventure",
                    startDate: Date(),
                    endDate: Date(),
                    events: []
                )
        }
        do {
//            Decode the retrieved data using JSONDecoder to convert it back into an array of Trip objects.
            return try JSONDecoder().decode(Trip.self, from: data)
        } catch {
            return   Trip(
                    id: 1,
                    name: "A Great Adventure",
                    startDate: Date(),
                    endDate: Date(),
                    events: []
                )
        }
    }
}
