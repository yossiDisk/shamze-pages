import Foundation

enum Configuration {
    enum Error: Swift.Error {
        case missingKey, invalidValue
    }
    
    // להסתרת מידע רגיש
    static func value<T>(for key: String) throws -> T where T: LosslessStringConvertible {
        guard let object = Bundle.main.object(forInfoDictionaryKey: key) else {
            throw Error.missingKey
        }
        
        switch object {
        case let value as T:
            return value
        case let string as String:
            guard let value = T(string) else { fallthrough }
            return value
        default:
            throw Error.invalidValue
        }
    }
    
    // URLs
    static var apiBaseURL: String {
        return "https://o0rmue7xt0.execute-api.il-central-1.amazonaws.com/dev"
    }
    
    // Cache Settings
    static let cacheTimeLimit: TimeInterval = 4 * 60 * 60 // 4 hours
    static let maxCacheSize = 100
    
    // API Endpoints
    static func siteEndpoint(domain: String) -> String {
        return "\(apiBaseURL)/sites?site=\(domain)"
    }
}
