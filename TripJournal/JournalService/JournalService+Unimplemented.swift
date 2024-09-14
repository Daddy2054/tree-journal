import Combine
import Foundation

enum HTTPMethods: String {
    case POST, GET, PUT, DELETE
}

enum MIMEType: String {
    case JSON = "application/json"
    case form = "application/x-www-form-urlencoded"
}

enum HTTPHeaders: String {
    case accept
    case contentType = "Content-Type"
    case authorization = "Authorization"
}

enum NetworkError: Error {
    case badUrl
    case badResponse
    case failedToDecodeResponse
    case invalidValue
}
enum EncodingError: Error {
    case badFormat
}

enum SessionError: Error {
    case expired
}

extension SessionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .expired:
            return "Your session has expired. Please log in again."
        }
    }
}
/// An unimplemented version of the `JournalService`.
class UnimplementedJournalService: JournalService {
    var tokenExpired: Bool = false
//    var isAuthenticated: AnyPublisher<Bool, Never> {
//        fatalError("Unimplemented isAuthenticated")
//    }
    @Published private var token: Token? {
        didSet {
            if let token = token {
                try? KeychainHelper.shared.saveToken(token)
            } else {
                try? KeychainHelper.shared.deleteToken()
            }
        }
    }

    var isAuthenticated: AnyPublisher<Bool, Never> {
        $token
            .map { $0 != nil }
            .eraseToAnyPublisher()
    }
    enum EndPoints {
//        static let base = "http://localhost:8000/"
        static let base = "https://2d09-145-224-104-27.ngrok-free.app/"

        case register
        case login
        case trips
        case handleTrip(String)
        case events
        case handleEvent(String)
        case media
        case handleMedia(String)
   

        private var stringValue: String {
            switch self {
            case .register:
                return EndPoints.base + "register"
            case .login:
                return EndPoints.base + "token"
            case .trips:
                return EndPoints.base + "trips"
            case .handleTrip(let tripId):
                return EndPoints.base + "trips/\(tripId)"
            case .events:
                return EndPoints.base + "events"
            case .handleEvent(let eventId):
                return EndPoints.base + "events/\(eventId)"
            case .media:
                return EndPoints.base + "media"
            case .handleMedia(let mediaId):
                return EndPoints.base + "media/\(mediaId)"
            }
        }

        var url: URL {
            return URL(string: stringValue)!
        }
    }
    
    // Shared URLSession instance
    private let urlSession: URLSession
    //    Add an instance of TripCacheManager to manage trip caching
        private let tripCacheManager = TripCacheManager()
    //    Add a Published instance of NetworkMonitor to monitor network connection status
        @Published private var networkMonitor = NetworkMonitor()
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        self.urlSession = URLSession(configuration: configuration)

        if let savedToken = try? KeychainHelper.shared.getToken() {
            if !isTokenExpired(savedToken) {
                self.token = savedToken
            } else {
                self.tokenExpired = true
                self.token = nil
            }
        } else {
            self.token = nil
        }
    }
//    func register(username _: String, password _: String) async throws -> Token {
//        fatalError("Unimplemented register")
//    }
    func register(username: String, password: String) async throws -> Token {
        let request = try createRegisterRequest(username: username, password: password)
        var token = try await performNetworkRequest(request, responseType: Token.self)
        token.expirationDate = Token.defaultExpirationDate()
        self.token = token
        return token
    }

//    func logOut() {
//        fatalError("Unimplemented logOut")
//    }
    func logOut() {
        token = nil
    }

//    func logIn(username _: String, password _: String) async throws -> Token {
//        fatalError("Unimplemented logIn")
//    }

    func logIn(username: String, password: String) async throws -> Token {
        let request = try createLoginRequest(username: username, password: password)
        var token = try await performNetworkRequest(request, responseType: Token.self)
        token.expirationDate = Token.defaultExpirationDate()
        self.token = token
        return token
    }
    
//    func createTrip(with _: TripCreate) async throws -> Trip {
//        fatalError("Unimplemented createTrip")
//    }
    func createTrip(with request: TripCreate) async throws -> Trip {
        guard let token = token else {
            throw NetworkError.invalidValue
        }

        var requestURL = URLRequest(url: EndPoints.trips.url)
        requestURL.httpMethod = HTTPMethods.POST.rawValue
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        let tripData: [String: Any] = [
            "name": request.name,
            "start_date": dateFormatter.string(from: request.startDate),
            "end_date": dateFormatter.string(from: request.endDate)
        ]
        requestURL.httpBody = try JSONSerialization.data(withJSONObject: tripData)

        return try await performNetworkRequest(requestURL, responseType: Trip.self)
    }


//    func getTrips() async throws -> [Trip] {
//        fatalError("Unimplemented getTrips")
//    }
    
    func getTrips() async throws -> [Trip] {
        guard let token = token else {
            throw NetworkError.invalidValue
        }

        // Check network connection
//        Check the network connection status using networkMonitor before making a network request.
        if !networkMonitor.isConnected {
            print("Offline: Loading trips from UserDefaults")
            return tripCacheManager.loadTrips()
        }

        var requestURL = URLRequest(url: EndPoints.trips.url)
        requestURL.httpMethod = HTTPMethods.GET.rawValue
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)

        do {
            let trips = try await performNetworkRequest(requestURL, responseType: [Trip].self)
//            When**** successfully**** fetch trips from the network, save them to the cache
            // 3.b Save the fetched trips to the cache to keep it updated

            tripCacheManager.saveTrips(trips)
//            print(trips)
            return trips
        } catch {
//            In case of a network error, return trips from the cache
            // 3.c If fetching trips fails, load trips from cache as a fallback

            print("Fetching trips failed, loading from UserDefaults")
            return tripCacheManager.loadTrips()
        }
    }
    

//    func getTrip(withId _: Trip.ID) async throws -> Trip {
//        fatalError("Unimplemented getTrip")
//    }
    func getTrip(withId tripId: Trip.ID) async throws -> Trip {
        guard let token = token else {
            throw NetworkError.invalidValue
        }

        // Check network connection
//        Check the network connection status using networkMonitor before making a network request.
//        if !networkMonitor.isConnected {
//            print("Offline: Loading trips from UserDefaults")
//            return tripCacheManager.loadTrips()
//        }
        let url = EndPoints.handleTrip(tripId.description).url
        var requestURL = URLRequest(url: url)
        requestURL.httpMethod = HTTPMethods.GET.rawValue
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)

        do {
//            let trips = try await performNetworkRequest(requestURL, responseType: [Trip].self)
            let trip = try await performNetworkRequest(requestURL, responseType: Trip.self)
//            When**** successfully**** fetch trips from the network, save them to the cache
            // 3.b Save the fetched trips to the cache to keep it updated

//            tripCacheManager.saveTrips(trips)
//            print(trip)
            return trip
        } catch {
//            In case of a network error, return trips from the cache
            // 3.c If fetching trips fails, load trips from cache as a fallback

            print("Fetching trips failed, loading from UserDefaults")
            return tripCacheManager.loadTrip()
 
        }
    }
  
    func updateTrip(withId tripId: Trip.ID, and  request:  TripUpdate) async throws -> Trip {
//        fatalError("Unimplemented updateTrip")
//    }
//    func createTrip(with request: TripCreate) async throws -> Trip {
        guard let token = token else {
            throw NetworkError.invalidValue
        }

        let url = EndPoints.handleTrip(tripId.description).url
        var requestURL = URLRequest(url: url)
        requestURL.httpMethod = HTTPMethods.PUT.rawValue
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]

        let tripData: [String: Any] = [
            "name": request.name,
            "start_date": dateFormatter.string(from: request.startDate),
            "end_date": dateFormatter.string(from: request.endDate)
        ]
        requestURL.httpBody = try JSONSerialization.data(withJSONObject: tripData)

        return try await performNetworkRequest(requestURL, responseType: Trip.self)
    }



//    func deleteTrip(withId _: Trip.ID) async throws {
//        fatalError("Unimplemented deleteTrip")
//    }
    func deleteTrip(withId tripId: Trip.ID) async throws {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        let url = EndPoints.handleTrip(tripId.description).url
        var requestURL = URLRequest(url: url)
        requestURL.httpMethod = HTTPMethods.DELETE.rawValue
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)

        try await performVoidNetworkRequest(requestURL)
    }


    func createEvent(with request: EventCreate) async throws -> Event {

        guard let token = token else {
            throw NetworkError.invalidValue
        }

        var requestURL = URLRequest(url: EndPoints.events.url)
        requestURL.httpMethod = HTTPMethods.POST.rawValue
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)

//        let dateFormatter = ISO8601DateFormatter()
//        dateFormatter.formatOptions = [.withInternetDateTime]
//
//
//        let eventData: [String: Encodable] = [
//            "name": request.name,
//            "date": dateFormatter.string(from: request.date),
//            "note": request.note  ,
//            "trip_id": String(request.tripId),
//            "location": request.location,
//            "transition_from_previous":request.transitionFromPrevious,
//        ]
        
//        let locationData: [String: Location?] = [
//            "location": request.location ,
//]
//        print(isValidJSONObject(obj:eventData))
//        requestURL.httpBody = try JSONSerialization.data(withJSONObject: eventData)
//        let locationBody = try JSONSerialization.data(withJSONObject: locationData)
//        let testRequest  = try JSONEncoder().encode(request)


//        print(testRequest)

        requestURL.httpBody  = try JSONEncoder().encode(request)
//        print("jsonData: ", String(data: requestURL.httpBody!, encoding: .utf8) ?? "no body data")
//        requestURL.httpBody?.append(locationBody)
//        request.log()
        return try await performNetworkRequest(requestURL, responseType: Event.self)
    }


    func updateEvent(withId eventId: Event.ID, and request: EventUpdate) async throws -> Event {
//        fatalError("Unimplemented updateEvent")
//    }
            guard let token = token else {
            throw NetworkError.invalidValue
        }

        let url = EndPoints.handleEvent(eventId.description).url
        var requestURL = URLRequest(url: url)
        requestURL.httpMethod = HTTPMethods.PUT.rawValue
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)

//        let dateFormatter = ISO8601DateFormatter()
//        dateFormatter.formatOptions = [.withInternetDateTime]
//
//        let eventData: [String: Any] = [
//            "name": request.name,
//            "date": dateFormatter.string(from: request.date),
//            "note": request.note  as Any,
////            "location":  request.location as Any,
//            "transition_from_previous":request.transitionFromPrevious as Any,
//
//        
//        ]
//        print(eventData)
//        requestURL.httpBody = try JSONSerialization.data(withJSONObject: eventData)
        requestURL.httpBody  = try JSONEncoder().encode(request)
        return try await performNetworkRequest(requestURL, responseType: Event.self)
    }



    func deleteEvent(withId eventId: Event.ID) async throws {
//        fatalError("Unimplemented deleteEvent")
//    }
//    func deleteTrip(withId tripId: Trip.ID) async throws {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        let url = EndPoints.handleEvent(eventId.description).url
        var requestURL = URLRequest(url: url)
        requestURL.httpMethod = HTTPMethods.DELETE.rawValue
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)

        try await performVoidNetworkRequest(requestURL)
    }

    func createMedia(with request: MediaCreate) async throws -> Media {
//        fatalError("Unimplemented createMedia")
//    }
//    func createEvent(with request: EventCreate) async throws -> Event {

        guard let token = token else {
            throw NetworkError.invalidValue
        }

        var requestURL = URLRequest(url: EndPoints.media.url)
        requestURL.httpMethod = HTTPMethods.POST.rawValue
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)

        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)


        let mediaData: [String: Any] = [
            "caption": "image caption",
            "event_id": request.eventId,
            "base64_data": request.base64Data.base64EncodedString()

        ]
//        print(mediaData)
        requestURL.httpBody = try JSONSerialization.data(withJSONObject: mediaData)

        return try await performNetworkRequest(requestURL, responseType: Media.self)
    }


    func deleteMedia(withId _: Media.ID) async throws {
        fatalError("Unimplemented deleteMedia")
    }
    
    private func createRegisterRequest(username: String, password: String) throws -> URLRequest {
        var request = URLRequest(url: EndPoints.register.url)
        request.httpMethod = HTTPMethods.POST.rawValue
        request.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        request.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)

        let registerRequest = LoginRequest(username: username, password: password)
        request.httpBody = try JSONEncoder().encode(registerRequest)

        return request
    }
    private func createLoginRequest(username: String, password: String) throws -> URLRequest {
        var request = URLRequest(url: EndPoints.login.url)
        request.httpMethod = HTTPMethods.POST.rawValue
        request.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        request.addValue(MIMEType.form.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)

        let loginData = "grant_type=&username=\(username)&password=\(password)"
        request.httpBody = loginData.data(using: .utf8)

        return request
    }
    
    private func performNetworkRequest<T: Decodable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)
//        request.log()
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            request.log()
            throw NetworkError.badResponse
            
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let object = try decoder.decode(T.self, from: data)
            return object
        } catch {
            throw NetworkError.failedToDecodeResponse
        }
    }
    
    private func performVoidNetworkRequest(_ request: URLRequest) async throws {
        let (_, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw NetworkError.badResponse
        }
    }
    private func isTokenExpired(_ token: Token) -> Bool {
        guard let expirationDate = token.expirationDate else {
            return false
        }
        return expirationDate <= Date()
    }
}

extension Data {
    func toString() -> String? {
        return String(data: self, encoding: .utf8)
    }
}


extension URLRequest {
    func log() {
        print("\(httpMethod ?? "") \(self)")
        print("BODY \n \(String(describing: httpBody?.toString()))")
        print("HEADERS \n \(String(describing: allHTTPHeaderFields))")
    }
}
