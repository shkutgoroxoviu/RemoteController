//
//  TVDiscoveryService.swift
//  RemoteTVController
//

import Foundation
import Network
import Combine

@MainActor
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
    
    // MARK: - Public
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
        
        fallbackScanIPRange()
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
            guard let self = self else { return }
            if case .ready = state {
                Task { @MainActor in
                    for target in searchTargets {
                        let message = """
                        M-SEARCH * HTTP/1.1\r
                        HOST: \(self.ssdpAddress):\(self.ssdpPort)\r
                        MAN: "ssdp:discover"\r
                        MX: 3\r
                        ST: \(target)\r
                        \r
                        """
                        self.sendSearchMessage(message)
                    }
                    self.receiveResponses()
                }
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
            guard let self = self else { return }
            if let data = data, let response = String(data: data, encoding: .utf8) {
                self.parseSSDPResponse(response)
            }
            if self.isSearching {
                self.receiveResponses()
            }
        }
    }
    
    private func parseSSDPResponse(_ response: String) {
        var location: String?
        var server: String?
        var st: String?
        
        let lines = response.components(separatedBy: "\r\n")
        for line in lines {
            let upper = line.uppercased()
            if upper.hasPrefix("LOCATION:") {
                location = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            } else if upper.hasPrefix("SERVER:") {
                server = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            } else if upper.hasPrefix("ST:") {
                st = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            }
        }
        
        if let location = location {
            fetchDeviceDescription(from: location, st: st, server: server)
        }
    }
    
    private func fetchDeviceDescription(from urlString: String, st: String?, server: String?) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data, let xml = String(data: data, encoding: .utf8) else { return }
            
            let friendlyName = self.extractValue(from: xml, tag: "friendlyName") ?? "Smart TV"
            let manufacturer = self.extractValue(from: xml, tag: "manufacturer") ?? ""
            let modelName = self.extractValue(from: xml, tag: "modelName")
            
            let brand = self.determineBrand(from: manufacturer, friendlyName: friendlyName, st: st, server: server)
            let platform = self.determinePlatform(from: brand, st: st, server: server)
            
            let device = DiscoveredDevice(name: friendlyName, ipAddress: url.host ?? "", brand: brand, platform: platform, model: modelName, usn: nil)
            
            DispatchQueue.main.async {
                if !(self.discoveredDevices.contains(where: { $0.ipAddress == device.ipAddress })) {
                    self.discoveredDevices.append(device)
                    AnalyticsService.shared.trackEvent(.deviceFound, properties: ["brand": brand.rawValue])
                }
            }
        }.resume()
    }
    
    private func extractValue(from xml: String, tag: String) -> String? {
        guard let open = xml.range(of: "<\(tag)>"),
              let close = xml.range(of: "</\(tag)>", range: open.upperBound..<xml.endIndex) else { return nil }
        return String(xml[open.upperBound..<close.lowerBound])
    }
    
    private func determineBrand(from manufacturer: String, friendlyName: String, st: String?, server: String?) -> TVBrand {
        let combined = (manufacturer + " " + friendlyName + " " + (st ?? "") + " " + (server ?? "")).lowercased()
        if combined.contains("samsung") { return .samsung }
        if combined.contains("lg") { return .lg }
        if combined.contains("sony") { return .sony }
        if combined.contains("hisense") { return .hisense }
        if combined.contains("philips") { return .philips }
        if combined.contains("panasonic") { return .panasonic }
        if combined.contains("tcl") { return .tcl }
        if combined.contains("roku") { return .roku }
        return .unknown
    }
    
    private func determinePlatform(from brand: TVBrand, st: String?, server: String?) -> TVPlatform {
        switch brand {
        case .samsung: return .tizen
        case .lg: return .webOS
        case .roku: return .roku
        case .hisense: return .vidaa
        case .sony, .philips, .tcl: return .androidTV
        default: return .unknown
        }
    }
    
    // MARK: - Fallback IP scan
    private func fallbackScanIPRange() {
        guard let localIP = getLocalIPAddress() else { return }
        let components = localIP.components(separatedBy: ".")
        guard components.count == 4 else { return }
        let prefix = components[0...2].joined(separator: ".")
        
        for i in 1...254 {
            let ip = "\(prefix).\(i)"
            scanCommonPorts(at: ip)
        }
    }
    
    private func scanCommonPorts(at ip: String) {
        checkSamsungPort(ip)
        checkLGPort(ip)
        checkHisensePort(ip)
        checkRokuPort(ip)
    }
    
    // MARK: - Port scanning
    private func checkSamsungPort(_ ip: String) {
        let port: UInt16 = 8001
        guard let url = URL(string: "http://\(ip):\(port)/api/v2/") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let device = json["device"] as? [String: Any],
                  let name = device["name"] as? String else { return }
            
            let discovered = DiscoveredDevice(name: name, ipAddress: ip, brand: .samsung, platform: .tizen, model: device["modelName"] as? String, usn: nil)
            DispatchQueue.main.async {
                if !(self.discoveredDevices.contains(where: { $0.ipAddress == ip })) {
                    self.discoveredDevices.append(discovered)
                    AnalyticsService.shared.trackEvent(.deviceFound, properties: ["brand": "Samsung"])
                }
            }
        }.resume()
    }
    
    private func checkLGPort(_ ip: String) {
        guard let url = URL(string: "http://\(ip):3000/api/v1/") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self = self, let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { return }
            let discovered = DiscoveredDevice(name: "LG Smart TV", ipAddress: ip, brand: .lg, platform: .webOS, model: nil, usn: nil)
            DispatchQueue.main.async {
                if !(self.discoveredDevices.contains(where: { $0.ipAddress == ip })) {
                    self.discoveredDevices.append(discovered)
                    AnalyticsService.shared.trackEvent(.deviceFound, properties: ["brand": "LG"])
                }
            }
        }.resume()
    }
    
    private func checkHisensePort(_ ip: String) {
        let ports: [UInt16] = [36669, 8080, 56789, 1926]
        for port in ports {
            let host = NWEndpoint.Host(ip)
            guard let nwPort = NWEndpoint.Port(rawValue: port) else { continue }
            let parameters = NWParameters.tcp
            let connection = NWConnection(host: host, port: nwPort, using: parameters)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: connection.cancel()
                default: connection.cancel()
                }
            }
            connection.start(queue: .global())
        }
    }
    
    private func checkRokuPort(_ ip: String) {
        guard let url = URL(string: "http://\(ip):8060/query/device-info") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self, let data = data, let xml = String(data: data, encoding: .utf8), xml.lowercased().contains("roku") else { return }
            let name = self.extractValue(from: xml, tag: "friendly-device-name") ?? "Roku TV"
            let discovered = DiscoveredDevice(name: name, ipAddress: ip, brand: .roku, platform: .roku, model: nil, usn: nil)
            DispatchQueue.main.async {
                if !(self.discoveredDevices.contains(where: { $0.ipAddress == ip })) {
                    self.discoveredDevices.append(discovered)
                    AnalyticsService.shared.trackEvent(.deviceFound, properties: ["brand": "Roku"])
                }
            }
        }.resume()
    }
    
    // MARK: - Helpers
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
               String(cString: interface.ifa_name) == "en0" {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                address = String(cString: hostname)
            }
        }
        return address
    }
}



