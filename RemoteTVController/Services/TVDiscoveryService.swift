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
    
    private func sendSSDPSearch() {
        let searchTargets = [
            "urn:schemas-upnp-org:device:MediaRenderer:1",
            "urn:schemas-upnp-org:device:Basic:1",
            "urn:dial-multiscreen-org:service:dial:1",
            "ssdp:all",
            "urn:samsung.com:device:RemoteControl:1"
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
        discoverCommonTVPorts()
    }
    
    private func sendSearchMessage(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        ssdpSocket?.send(content: data, completion: .contentProcessed { _ in })
    }
    
    private func receiveResponses() {
        ssdpSocket?.receiveMessage { [weak self] data, _, _, _ in
            if let data = data, let response = String(data: data, encoding: .utf8) {
                self?.parseSSResponse(response)
            }
            if self?.isSearching == true { self?.receiveResponses() }
        }
    }
    
    private func parseSSResponse(_ response: String) {
        let lines = response.components(separatedBy: "\r\n")
        var location: String?
        
        for line in lines {
            if line.uppercased().hasPrefix("LOCATION:") {
                location = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            }
        }
        
        if let location = location {
            fetchDeviceDescription(from: location)
        }
    }
    
    private func fetchDeviceDescription(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let xml = String(data: data, encoding: .utf8) else { return }
            
            if let device = self?.parseDeviceXML(xml, urlString: urlString) {
                DispatchQueue.main.async {
                    if !(self?.discoveredDevices.contains(where: { $0.ipAddress == device.ipAddress }) ?? false) {
                        self?.discoveredDevices.append(device)
                        AnalyticsService.shared.trackEvent(.deviceFound, properties: ["brand": device.brand.rawValue])
                    }
                }
            }
        }.resume()
    }
    
    private func parseDeviceXML(_ xml: String, urlString: String) -> DiscoveredDevice? {
        guard let url = URL(string: urlString), let host = url.host else { return nil }
        
        let friendlyName = extractValue(from: xml, tag: "friendlyName") ?? "Smart TV"
        let manufacturer = extractValue(from: xml, tag: "manufacturer") ?? ""
        let modelName = extractValue(from: xml, tag: "modelName")
        let brand = determineBrand(from: manufacturer, friendlyName: friendlyName)
        
        return DiscoveredDevice(name: friendlyName, ipAddress: host, brand: brand, platform: .unknown, model: modelName, usn: nil)
    }
    
    private func extractValue(from xml: String, tag: String) -> String? {
        guard let openRange = xml.range(of: "<\(tag)>"),
              let closeRange = xml.range(of: "</\(tag)>", range: openRange.upperBound..<xml.endIndex) else { return nil }
        return String(xml[openRange.upperBound..<closeRange.lowerBound])
    }
    
    private func determineBrand(from manufacturer: String, friendlyName: String) -> TVBrand {
        let combined = (manufacturer + " " + friendlyName).lowercased()
        if combined.contains("samsung") { return .samsung }
        if combined.contains("lg") { return .lg }
        if combined.contains("sony") { return .sony }
        if combined.contains("hisense") || combined.contains("vidaa") { return .hisense }
        if combined.contains("philips") { return .philips }
        if combined.contains("panasonic") { return .panasonic }
        if combined.contains("tcl") { return .tcl }
        if combined.contains("roku") { return .roku }
        return .unknown
    }
    
    private func discoverCommonTVPorts() {
        guard let localIP = getLocalIPAddress() else { return }
        let components = localIP.components(separatedBy: ".")
        guard components.count == 4 else { return }
        let prefix = components[0...2].joined(separator: ".")
        
        // Сканируем первые 254 адреса в подсети
        for i in 1...254 {
            let ip = "\(prefix).\(i)"
            checkSamsungTV(at: ip)
            checkHisenseTV(at: ip)
            checkLGTV(at: ip)
            checkRokuTV(at: ip)
        }
    }
    
    private func checkSamsungTV(at ip: String) {
        guard let url = URL(string: "http://\(ip):8001/api/v2/") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let device = json["device"] as? [String: Any],
                  let name = device["name"] as? String else { return }
            
            DispatchQueue.main.async {
                let discovered = DiscoveredDevice(name: name, ipAddress: ip, brand: .samsung, platform: .tizen, model: device["modelName"] as? String, usn: nil)
                if !(self?.discoveredDevices.contains(where: { $0.ipAddress == ip }) ?? false) {
                    self?.discoveredDevices.append(discovered)
                    AnalyticsService.shared.trackEvent(.deviceFound, properties: ["brand": "Samsung"])
                }
            }
        }.resume()
    }
    
    // MARK: - Hisense TV Discovery
    private func checkHisenseTV(at ip: String) {
        let hisensePorts: [UInt16] = [36669, 8080, 56789, 1926]
        
        for port in hisensePorts {
            checkHisensePort(at: ip, port: port)
        }
    }
    
    private func checkHisensePort(at ip: String, port: UInt16) {
        let host = NWEndpoint.Host(ip)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .wifi
        
        let connection = NWConnection(host: host, port: nwPort, using: parameters)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.identifyHisenseDevice(at: ip, port: port)
                connection.cancel()
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            connection.cancel()
        }
    }
    
    private func identifyHisenseDevice(at ip: String, port: UInt16) {
        let endpoints = [
            "http://\(ip):\(port)/api/v1/device",
            "http://\(ip):\(port)/device/info",
            "http://\(ip):\(port)/api/status"
        ]
        
        for urlString in endpoints {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.timeoutInterval = 2
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    
                    var name = "Hisense Smart TV"
                    var model: String? = nil
                    
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        name = json["name"] as? String ?? 
                               json["friendlyName"] as? String ?? 
                               json["deviceName"] as? String ?? name
                        model = json["model"] as? String ?? 
                                json["modelName"] as? String ??
                                json["model_name"] as? String
                    }
                    
                    DispatchQueue.main.async {
                        let discovered = DiscoveredDevice(name: name, ipAddress: ip, brand: .hisense, platform: .vidaa, model: model, usn: nil)
                        if !(self?.discoveredDevices.contains(where: { $0.ipAddress == ip }) ?? false) {
                            self?.discoveredDevices.append(discovered)
                            AnalyticsService.shared.trackEvent(.deviceFound, properties: ["brand": "Hisense"])
                        }
                    }
                    return
                }
            }.resume()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            let discovered = DiscoveredDevice(
                name: "Hisense TV",
                ipAddress: ip,
                brand: .hisense,
                platform: .vidaa,
                model: nil,
                usn: nil
            )
            if !(self?.discoveredDevices.contains(where: { $0.ipAddress == ip }) ?? false) {
                self?.discoveredDevices.append(discovered)
                AnalyticsService.shared.trackEvent(.deviceFound, properties: ["brand": "Hisense"])
            }
        }
    }
    
    // MARK: - LG TV Discovery
    private func checkLGTV(at ip: String) {
        guard let url = URL(string: "http://\(ip):3000/api/v1/") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return }
            
            DispatchQueue.main.async {
                let discovered = DiscoveredDevice(name: "LG Smart TV", ipAddress: ip, brand: .lg, platform: .webOS, model: nil, usn: nil)
                if !(self?.discoveredDevices.contains(where: { $0.ipAddress == ip }) ?? false) {
                    self?.discoveredDevices.append(discovered)
                    AnalyticsService.shared.trackEvent(.deviceFound, properties: ["brand": "LG"])
                }
            }
        }.resume()
    }
    
    // MARK: - Roku TV Discovery
    private func checkRokuTV(at ip: String) {
        guard let url = URL(string: "http://\(ip):8060/query/device-info") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data,
                  let xml = String(data: data, encoding: .utf8),
                  xml.contains("roku") || xml.contains("Roku") else { return }
            
            let name = self?.extractValue(from: xml, tag: "user-device-name") ?? 
                       self?.extractValue(from: xml, tag: "friendly-device-name") ?? "Roku TV"
            let model = self?.extractValue(from: xml, tag: "model-name")
            
            var brand: TVBrand = .roku
            if xml.lowercased().contains("tcl") {
                brand = .tcl
            } else if xml.lowercased().contains("hisense") {
                brand = .hisense
            }
            
            DispatchQueue.main.async {
                let discovered = DiscoveredDevice(name: name, ipAddress: ip, brand: brand, platform: .roku, model: model, usn: nil)
                if !(self?.discoveredDevices.contains(where: { $0.ipAddress == ip }) ?? false) {
                    self?.discoveredDevices.append(discovered)
                    AnalyticsService.shared.trackEvent(.deviceFound, properties: ["brand": brand.rawValue])
                }
            }
        }.resume()
    }
    
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
