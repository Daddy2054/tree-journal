import Foundation

/// An object that can be used to create a new trip.
struct TripCreate {
    let name: String
    let startDate: Date
    let endDate: Date
}

/// An object that can be used to update an existing trip.
struct TripUpdate {
    let name: String
    let startDate: Date
    let endDate: Date
}

/// An object that can be used to create a media.
struct MediaCreate {
    let eventId: Event.ID
    let base64Data: Data
}

/// An object that can be used to create a new event.
struct EventCreate: Sendable, Hashable, Codable  {
    let tripId: Trip.ID
    let name: String
    let note: String?
//    let date: Date
    let date: String
    let location: Location?
    let transitionFromPrevious: String?
    
    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case name, note, date, location
        case transitionFromPrevious = "transition_from_previous"
    }
}

/// An object that can be used to update an existing event.
struct EventUpdate: Sendable, Hashable, Codable {
    var name: String
    var note: String?
//    var date: Date
    let date: String
    var location: Location?
    var transitionFromPrevious: String?
    
    enum CodingKeys: String, CodingKey {
        case name, note, date, location
        case transitionFromPrevious = "transition_from_previous"
    }
}
