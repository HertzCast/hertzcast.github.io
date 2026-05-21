import Foundation
import Darwin

class DiscoveryService: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var discovered: [DiscoveredDevice] = []
    @Published var errorMessage: String?

    struct DiscoveredDevice: Identifiable {
        let id = UUID()
        let name: String
        let host: String
    }

    private var browser: NetServiceBrowser?
    private var pending: [NetService] = []
    private var timeoutTimer: Timer?
    private var verifyTasks: [URLSessionDataTask] = []

    func startScan() {
        stopScan()
        discovered = []
        errorMessage = nil
        isScanning = true

        let b = NetServiceBrowser()
        b.delegate = self
        b.searchForServices(ofType: "_http._tcp", inDomain: "local.")
        browser = b

        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            guard let self else { return }
            let found = self.discovered.count
            self.stopScan()
            if found == 0 {
                self.errorMessage = "No Yamaha receivers found. Enter IP manually."
            }
        }
    }

    func stopScan() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        browser?.stop()
        browser = nil
        pending.forEach { $0.stop() }
        pending.removeAll()
        verifyTasks.forEach { $0.cancel() }
        verifyTasks.removeAll()
        isScanning = false
    }

    // After resolving, verify the device responds to the YXC API
    private func verify(host: String, name: String) {
        guard let url = URL(string: "http://\(host)/YamahaExtendedControl/v1/main/getStatus") else { return }
        var req = URLRequest(url: url, timeoutInterval: 3)
        req.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self else { return }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["response_code"] != nil else { return }
            DispatchQueue.main.async {
                guard !self.discovered.contains(where: { $0.host == host }) else { return }
                self.discovered.append(DiscoveredDevice(name: name, host: host))
                if self.discovered.count == 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if self.discovered.count == 1 {
                            HertzSettings.shared.ipAddress = self.discovered[0].host
                            self.stopScan()
                        }
                    }
                }
            }
        }
        verifyTasks.append(task)
        task.resume()
    }

    private func ipv4(from service: NetService) -> String? {
        guard let addresses = service.addresses else { return nil }
        for data in addresses {
            let ip = data.withUnsafeBytes { raw -> String? in
                let ptr = raw.baseAddress!
                let family = ptr.load(as: sockaddr.self).sa_family
                guard family == sa_family_t(AF_INET) else { return nil }
                var addr = ptr.load(as: sockaddr_in.self).sin_addr
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                guard inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN)) != nil else { return nil }
                return String(cString: buf)
            }
            if let ip, ip != "0.0.0.0" { return ip }
        }
        return nil
    }
}

extension DiscoveryService: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        pending.append(service)
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        stopScan()
        errorMessage = "Discovery failed. Enter IP manually."
    }
}

extension DiscoveryService: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let host = ipv4(from: sender) else { return }
        let name = sender.name.isEmpty ? host : sender.name
        verify(host: host, name: name)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        pending.removeAll { $0 === sender }
    }
}
