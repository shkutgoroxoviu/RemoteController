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
    
    // MARK: - Discovery Control
    func startDiscovery(timeout: TimeInterval = 10) {
        guard !isSearching else { return }
        isSearching = true
        discoveredDevices.removeAll()
        errorMessage = nil
        
        sendSSDPSearch()
        
        searchTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
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
    
    // MARK: - SSDP Search
    private func sendSSDPSearch() {
        let searchTargets = [
            "ssdp:all",
            "urn:schemas-upnp-org:device:MediaRenderer:1",
            "urn:samsung.com:device:RemoteControlReceiver:1",
            "urn:dial-multiscreen-org:service:dial:1"
        ]
        
        let host = NWEndpoint.Host(ssdpAddress)
        let port = NWEndpoint.Port(rawValue: ssdpPort)!
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        ssdpSocket = NWConnection(host: host, port: port, using: parameters)
        ssdpSocket?.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                for target in searchTargets {
                    let message = """
                    M-SEARCH * HTTP/1.1\r
                    HOST: \(self?.ssdpAddress ?? "239.255.255.250"):\(self?.ssdpPort ?? 1900)\r
                    MAN: "ssdp:discover"\r
                    MX: 3\r
                    ST: \(target)\r
                    \r
                    """
                    self?.sendSearchMessage(message)
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
    
    // MARK: - Parsing SSDP
    private func parseSSDPResponse(_ response: String) {
        var location: String?
        var usn: String?
        var st: String?
        var server: String?
        
        for line in response.components(separatedBy: "\r\n") {
            let upper = line.uppercased()
            if upper.hasPrefix("LOCATION:") {
                location = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            }
            if upper.hasPrefix("USN:") {
                usn = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            }
            if upper.hasPrefix("ST:") {
                st = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            }
            if upper.hasPrefix("SERVER:") {
                server = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            }
        }
        
        guard let locationURL = location, let url = URL(string: locationURL), let host = url.host else { return }
        
        fetchDeviceDescription(from: locationURL, usn: usn, st: st, server: server)
    }
    
    private func fetchDeviceDescription(from urlString: String, usn: String?, st: String?, server: String?) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let xml = String(data: data, encoding: .utf8) else { return }
            let friendlyName = self?.extractValue(from: xml, tag: "friendlyName") ?? "Smart TV"
            let manufacturer = self?.extractValue(from: xml, tag: "manufacturer") ?? ""
            let modelName = self?.extractValue(from: xml, tag: "modelName")
            let brand = self?.determineBrand(manufacturer: manufacturer, friendlyName: friendlyName, usn: usn, st: st, server: server) ?? .unknown
            let platform = self?.determinePlatform(brand: brand, usn: usn, st: st, server: server) ?? .unknown
            
            let discovered = DiscoveredDevice(name: friendlyName, ipAddress: url.host ?? "", brand: brand, platform: platform, model: modelName, usn: usn)
            
            DispatchQueue.main.async {
                if !(self?.discoveredDevices.contains(where: { $0.ipAddress == discovered.ipAddress }) ?? false) {
                    self?.discoveredDevices.append(discovered)
                }
            }
        }.resume()
    }
    
    private func extractValue(from xml: String, tag: String) -> String? {
        guard let open = xml.range(of: "<\(tag)>"),
              let close = xml.range(of: "</\(tag)>", range: open.upperBound..<xml.endIndex) else { return nil }
        return String(xml[open.upperBound..<close.lowerBound])
    }
    
    // MARK: - Brand & Platform Detection
    private func determineBrand(manufacturer: String, friendlyName: String, usn: String?, st: String?, server: String?) -> TVBrand {
        let combined = (manufacturer + " " + friendlyName + " " + (usn ?? "") + " " + (st ?? "") + " " + (server ?? "")).lowercased()
        if combined.contains("samsung") || combined.contains("tizen") { return .samsung }
        if combined.contains("lg") { return .lg }
        if combined.contains("sony") { return .sony }
        if combined.contains("hisense") { return .hisense }
        if combined.contains("philips") { return .philips }
        if combined.contains("panasonic") { return .panasonic }
        if combined.contains("tcl") { return .tcl }
        if combined.contains("roku") { return .roku }
        return .unknown
    }
    
    private func determinePlatform(brand: TVBrand, usn: String?, st: String?, server: String?) -> TVPlatform {
        switch brand {
        case .samsung: return .tizen
        case .lg: return .webOS
        case .roku: return .roku
        case .hisense: return .vidaa
        case .sony, .philips, .tcl: return .androidTV
        default: return .unknown
        }
    }
}


