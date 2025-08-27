//
//  AmadeusServices.swift
//  TravelMaster
//
//  Created by 珠穆朗玛小蜜蜂 on 2025/8/26.
//

import Foundation

class AmadeusService {
    private let apiKey: String
    private let apiSecret: String
    private let baseURL: String
    private var accessToken: String?
    private var tokenExpiration: Date?
    private let session: URLSession
    
    enum APIError: Error, LocalizedError {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case authenticationFailed
        case noData
        case decodingError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的URL"
            case .requestFailed(let error):
                return "请求失败: \(error.localizedDescription)"
            case .invalidResponse:
                return "无效的响应"
            case .authenticationFailed:
                return "认证失败"
            case .noData:
                return "没有数据"
            case .decodingError(let error):
                return "解码错误: \(error.localizedDescription)"
            }
        }
    }
    
    init(config: TicketConfiguration) {
        self.apiKey = config.amadeusAPIKey
        self.apiSecret = config.amadeusAPISecret
        self.baseURL = config.amadeusEnvironment == "test"
            ? "https://test.api.amadeus.com/v2"
            : "https://api.amadeus.com/v2"
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - 认证
    
    private func authenticate() async throws -> String {
        // 检查现有 token 是否有效
        if let token = accessToken, let expiration = tokenExpiration, expiration > Date() {
            return token
        }
        
        // 否则获取新 token
        let authURL = URL(string: "https://test.api.amadeus.com/v1/security/oauth2/token")!
        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=client_credentials&client_id=\(apiKey)&client_secret=\(apiSecret)"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.authenticationFailed
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? Int else {
                throw APIError.decodingError(NSError(domain: "AmadeusAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析认证响应"]))
            }
            
            self.accessToken = token
            self.tokenExpiration = Date().addingTimeInterval(TimeInterval(expiresIn))
            
            return token
        } catch {
            throw APIError.requestFailed(error)
        }
    }
    
    
    //MARK:城市名到IATA码的映射

    private let cityToIATACode: [String: String] = [
        // 中国主要城市
        "北京": "PEK",
        "上海": "SHA",
        "广州": "CAN",
        "深圳": "SZX",
        "成都": "CTU",
        "重庆": "CKG",
        "杭州": "HGH",
        "南京": "NKG",
        "西安": "XIY",
        "长沙": "CSX",
        "武汉": "WUH",
        "厦门": "XMN",
        "青岛": "TAO",
        "大连": "DLC",
        "天津": "TSN",
        "三亚": "SYX",
        "昆明": "KMG",
        "郑州": "CGO",
        "哈尔滨": "HRB",
        
        // 国际主要城市
        "东京": "HND",
        "大阪": "KIX",
        "首尔": "ICN",
        "香港": "HKG",
        "台北": "TPE",
        "新加坡": "SIN",
        "曼谷": "BKK",
        "吉隆坡": "KUL",
        "纽约": "JFK",
        "洛杉矶": "LAX",
        "伦敦": "LHR",
        "巴黎": "CDG",
        "悉尼": "SYD",
        
        // 英文城市名 (便于外国用户)
        "Beijing": "PEK",
        "Shanghai": "SHA",
        "Guangzhou": "CAN",
        "Shenzhen": "SZX",
        "Chengdu": "CTU",
        "Hangzhou": "HGH",
        "Tokyo": "HND",
        "Seoul": "ICN",
        "Singapore": "SIN",
        "Bangkok": "BKK",
        "New York": "JFK",
        "London": "LHR",
        "Paris": "CDG",
        "Sydney": "SYD"
    ]

    // 添加公开方法获取城市代码
    func getCityCode(for cityName: String) -> String? {
        return cityToIATACode[cityName]
    }
    
    // MARK: - 航班搜索
    
    struct FlightOffersSearchParams {
        let originLocationCode: String
        let destinationLocationCode: String
        let departureDate: String
        let returnDate: String?
        let adults: Int
        let children: Int
        let infants: Int
        let travelClass: String?
        let maxResults: Int?
        let currencyCode: String?
    }
    
    func searchFlightOffers(params: FlightOffersSearchParams) async throws -> FlightOffersResponse {
        let token = try await authenticate()
        
        var components = URLComponents(string: "\(baseURL)/shopping/flight-offers")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "originLocationCode", value: params.originLocationCode),
            URLQueryItem(name: "destinationLocationCode", value: params.destinationLocationCode),
            URLQueryItem(name: "departureDate", value: params.departureDate),
            URLQueryItem(name: "adults", value: String(params.adults))
        ]
        
        if let returnDate = params.returnDate {
            queryItems.append(URLQueryItem(name: "returnDate", value: returnDate))
        }
        
        if params.children > 0 {
            queryItems.append(URLQueryItem(name: "children", value: String(params.children)))
        }
        
        if params.infants > 0 {
            queryItems.append(URLQueryItem(name: "infants", value: String(params.infants)))
        }
        
        if let travelClass = params.travelClass {
            queryItems.append(URLQueryItem(name: "travelClass", value: travelClass))
        }
        
        if let maxResults = params.maxResults {
            queryItems.append(URLQueryItem(name: "max", value: String(maxResults)))
        }
        
        if let currencyCode = params.currencyCode {
            queryItems.append(URLQueryItem(name: "currencyCode", value: currencyCode))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.requestFailed(NSError(domain: "AmadeusAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API 请求失败"]))
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(FlightOffersResponse.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.requestFailed(error)
        }
    }
    
    // MARK: - 航班价格确认
    
    func confirmFlightPrice(flightOffer: FlightOffer) async throws -> FlightPriceResponse {
        let token = try await authenticate()
        
        let url = URL(string: "\(baseURL)/shopping/flight-offers/pricing")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "data": [
                "type": "flight-offers-pricing",
                "flightOffers": [flightOffer.toJSON()]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.requestFailed(NSError(domain: "AmadeusAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "价格确认失败"]))
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(FlightPriceResponse.self, from: data)
        } catch {
            throw APIError.requestFailed(error)
        }
    }
    
    // MARK: - 机场搜索
    
    func searchAirports(keyword: String, subType: String = "AIRPORT", countryCode: String? = nil) async throws -> AirportSearchResponse {
        let token = try await authenticate()
        
        var components = URLComponents(string: "\(baseURL)/reference-data/locations")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "keyword", value: keyword),
            URLQueryItem(name: "subType", value: subType)
        ]
        
        if let countryCode = countryCode {
            queryItems.append(URLQueryItem(name: "countryCode", value: countryCode))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.requestFailed(NSError(domain: "AmadeusAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "机场搜索失败"]))
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(AirportSearchResponse.self, from: data)
        } catch {
            throw APIError.requestFailed(error)
        }
    }
}

// MARK: - 响应模型

struct FlightOffersResponse: Codable {
    let data: [FlightOffer]
    let dictionaries: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case data
        case dictionaries
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode([FlightOffer].self, forKey: .data)
        // dictionaries 字段比较复杂，这里简化处理
        dictionaries = nil
    }
    
    // 新增编码逻辑：忽略 dictionaries 字段（因为解码时没实际解析它）
     func encode(to encoder: Encoder) throws {
         var container = encoder.container(keyedBy: CodingKeys.self)
         try container.encode(data, forKey: .data)
         // 编码时 dictionaries 固定为 nil，可省略不写，或显式 encodeNil
         try container.encodeNil(forKey: .dictionaries)
     }
}

struct FlightOffer: Codable {
    let id: String
    let source: String
    let type: String
    let price: Price
    let itineraries: [Itinerary]
    let travelerPricings: [TravelerPricing]
    
    func toJSON() -> [String: Any] {
        return [
            "id": id,
            "source": source,
            "type": type,
            // 其他字段...
        ]
    }
}

struct Price: Codable {
    let currency: String
    let total: String
    let base: String
    let fees: [Fee]?
    let grandTotal: String?
}

struct Fee: Codable {
    let amount: String
    let type: String
}

struct Itinerary: Codable {
    let duration: String
    let segments: [Segment]
}

struct Segment: Codable {
    let departure: FlightEndpoint
    let arrival: FlightEndpoint
    let carrierCode: String
    let number: String
    let aircraft: Aircraft?
    let operating: Operating?
    let duration: String
    let id: String
    let numberOfStops: Int
}

struct FlightEndpoint: Codable {
    let iataCode: String
    let terminal: String?
    let at: String // ISO 日期时间
}

struct Aircraft: Codable {
    let code: String
}

struct Operating: Codable {
    let carrierCode: String
}

struct TravelerPricing: Codable {
    let travelerId: String
    let fareOption: String
    let travelerType: String
    let price: Price
    let fareDetailsBySegment: [FareDetails]
}

struct FareDetails: Codable {
    let segmentId: String
    let cabin: String
    let fareBasis: String
    let brandedFare: String?
    let `class`: String
}

struct FlightPriceResponse: Codable {
    let data: FlightPriceData
}

struct FlightPriceData: Codable {
    let type: String
    let flightOffers: [FlightOffer]
}

struct AirportSearchResponse: Codable {
    let data: [Airport]
}

struct Airport: Codable {
    let type: String
    let subType: String
    let name: String
    let iataCode: String
    let address: Address
}

struct Address: Codable {
    let cityName: String
    let countryName: String
}
