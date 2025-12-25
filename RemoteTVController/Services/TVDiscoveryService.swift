//
//  TVDiscoveryService.swift
//  RemoteTVController
//

import Foundation
import Network
import Combine

final class TVDiscoveryService: ObservableObject {
    static let shared = TVDiscoveryService()
    
    @Published private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var errorMessage: String?
    
    private var ssdpSocket: NWConnection?
    private var searchTimer: Timer?
    private let ssdpAddress = "239.255.255.250"
    private let ssdpPort: UInt16 = 1900
    
    private init() {}
    
    func startDiscovery() {
        guard !isSearching else { return }
        isSearching = true
        errorMessage = nil
        discoveredDevices.removeAll()
        
        AnalyticsService.shared.trackEvent(.deviceSearchStarted)
        sendSSDPSearch()
        
        searchTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            self?.stopDiscovery()
        }
    }
    
    func stopDiscovery() {
        isSearching = false
        searchTimer?.invalidate()
        searchTimer = nil
        ssdpSocket?.cancel()
        ssdpSocket = nil
    }
    
    // MARK: - SSDP Discovery
    private func sendSSDPSearch() {
        let searchTargets = [
            "ssdp:all",
            "urn:schemas-upnp-org:device:MediaRenderer:1",
            "urn:dial-multiscreen-org:service:dial:1",
            "urn:samsung.com:device:RemoteControlReceiver:1"
        ]
        
        let host = NWEndpoint.Host(ssdpAddress)
        let port = NWEndpoint.Port(rawValue: ssdpPort)!
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        ssdpSocket = NWConnection(host: host, port: port, using: parameters)
        ssdpSocket?.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                for target in searchTargets {
                    let searchMessage = """
                    M-SEARCH * HTTP/1.1\r
                    HOST: \(self?.ssdpAddress ?? "239.255.255.250"):\(self?.ssdpPort ?? 1900)\r
                    MAN: "ssdp:discover"\r
                    MX: 5\r
                    ST: \(target)\r
                    \r
                    """
                    self?.sendSearchMessage(searchMessage)
                }
                self?.receiveResponses()
            }
        }
        ssdpSocket?.start(queue: .global(qos: .userInitiated))
    }
    
    private func sendSearchMessage(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        ssdpSocket?.send(content: data, completion: .contentProcessed { _ in })
    }
    
    private func receiveResponses() {
        ssdpSocket?.receiveMessage { [weak self] data, _, _, _ in
            if let data = data, let response = String(data: data, encoding: .utf8) {
                self?.parseSSDPResponse(response)
            }
            if self?.isSearching == true { self?.receiveResponses() }
        }
    }
    
    private func parseSSDPResponse(_ response: String) {
        let lines = response.components(separatedBy: "\r\n")
        var location: String?
        var st: String?
        var server: String?
        var usn: String?
        
        for line in lines {
            let upper = line.uppercased()
            if upper.hasPrefix("LOCATION:") {
                location = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            } else if upper.hasPrefix("ST:") {
                st = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            } else if upper.hasPrefix("SERVER:") {
                server = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            } else if upper.hasPrefix("USN:") {
                usn = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            }
        }
        
        guard let loc = location else { return }
        fetchDeviceDescription(from: loc, st: st, server: server, usn: usn)
    }
    
    private func fetchDeviceDescription(from urlString: String, st: String?, server: String?, usn: String?) {
        guard let url = URL(string: urlString), let host = url.host else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let xml = String(data: data, encoding: .utf8) else { return }
            
            let friendlyName = self?.extractValue(from: xml, tag: "friendlyName") ?? "Smart TV"
            let manufacturer = self?.extractValue(from: xml, tag: "manufacturer") ?? ""
            let modelName = self?.extractValue(from: xml, tag: "modelName")
            
            let brand = self?.determineBrand(from: manufacturer, friendlyName: friendlyName, server: server) ?? .unknown
            let platform: TVPlatform
            switch brand {
            case .samsung: platform = .tizen
            case .lg: platform = .webOS
            case .roku, .tcl, .hisense: platform = .roku
            default: platform = .unknown
            }
            
            let device = DiscoveredDevice(name: friendlyName, ipAddress: host, brand: brand, platform: platform, model: modelName, usn: usn)
            
            DispatchQueue.main.async {
                if !(self?.discoveredDevices.contains(where: { $0.ipAddress == host }) ?? false) {
                    self?.discoveredDevices.append(device)
                    AnalyticsService.shared.trackEvent(.deviceFound, properties: ["brand": brand.rawValue])
                }
            }
        }.resume()
    }
    
    private func extractValue(from xml: String, tag: String) -> String? {
        guard let openRange = xml.range(of: "<\(tag)>"),
              let closeRange = xml.range(of: "</\(tag)>", range: openRange.upperBound..<xml.endIndex) else { return nil }
        return String(xml[openRange.upperBound..<closeRange.lowerBound])
    }
    
    private func determineBrand(from manufacturer: String, friendlyName: String, server: String?) -> TVBrand {
        let combined = (manufacturer + " " + friendlyName + " " + (server ?? "")).lowercased()
        if combined.contains("samsung") || combined.contains("tizen") { return .samsung }
        if combined.contains("lg") || combined.contains("webos") { return .lg }
        if combined.contains("sony") { return .sony }
        if combined.contains("hisense") || combined.contains("vidaa") { return .hisense }
        if combined.contains("philips") { return .philips }
        if combined.contains("panasonic") { return .panasonic }
        if combined.contains("tcl") { return .tcl }
        if combined.contains("roku") { return .roku }
        return .unknown
    }
}



