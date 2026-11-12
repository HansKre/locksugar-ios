import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif
#if canImport(ExternalAccessory)
import ExternalAccessory
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

public final class BluetoothBatteryMonitor: NSObject, ObservableObject {
    public static let shared = BluetoothBatteryMonitor()
    
    @Published public private(set) var currentInfo: HeadphoneBatteryInfo?
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var diagnosticLogs: [String] = []
    
    private let storage: SharedStorage
    
    private static let logFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    
    public func log(_ message: String) {
        let timestamp = Self.logFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        print("[BluetoothBatteryMonitor] \(line)")
        if Thread.isMainThread {
            self.diagnosticLogs.append(line)
            if self.diagnosticLogs.count > 300 {
                self.diagnosticLogs.removeFirst(self.diagnosticLogs.count - 300)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.diagnosticLogs.append(line)
                if self.diagnosticLogs.count > 300 {
                    self.diagnosticLogs.removeFirst(self.diagnosticLogs.count - 300)
                }
            }
        }
    }
    
    public func clearLogs() {
        if Thread.isMainThread {
            self.diagnosticLogs.removeAll()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.diagnosticLogs.removeAll()
            }
        }
    }
    
    public var logsAsText: String {
        diagnosticLogs.joined(separator: "\n")
    }
    
    #if canImport(CoreBluetooth)
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private let knownServiceUUIDs: [CBUUID] = [
        CBUUID(string: "180F"), // Battery Service
        CBUUID(string: "1801"), // Generic Attribute Profile (GATT)
        CBUUID(string: "1800"), // Generic Access Profile (GAP)
        CBUUID(string: "180A"), // Device Information Service
        CBUUID(string: "FE2C")  // Google Fast Pair Service (Shokz / Android fast pair)
    ]
    private let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")
    private var scanTimeoutTimer: Timer?
    #endif
    
    public init(storage: SharedStorage = .shared) {
        self.storage = storage
        // Purge any stale preset / unverified battery levels (e.g. 20% from earlier testing)
        if let stored = storage.headphoneBatteryInfo, stored.batteryLevel == 20 {
            let sanitized = HeadphoneBatteryInfo(
                isConnected: stored.isConnected,
                batteryLevel: nil,
                deviceName: stored.deviceName,
                updatedAt: Date()
            )
            storage.headphoneBatteryInfo = sanitized
            self.currentInfo = sanitized
        } else {
            self.currentInfo = storage.headphoneBatteryInfo
        }
        super.init()
        log("Monitor initialized. Stored info: isConnected=\(currentInfo?.isConnected == true), level=\(currentInfo?.batteryLevel.map { "\($0)%" } ?? "nil"), device='\(currentInfo?.deviceName ?? "none")'")
        
        #if canImport(CoreBluetooth) && !os(watchOS)
        self.centralManager = CBCentralManager(
            delegate: self,
            queue: DispatchQueue.main,
            options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )
        #endif
        
        setupAudioRouteObserver()
        checkCurrentAudioRoute()
    }
    
    // MARK: - Audio Route Monitoring
    
    private func setupAudioRouteObserver() {
        #if canImport(AVFoundation) && !os(macOS) && !os(watchOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        #endif
    }
    
    @objc private func handleAudioRouteChange(notification: Notification) {
        log("AVAudioSession routeChangeNotification received")
        checkCurrentAudioRoute()
    }
    
    public func checkCurrentAudioRoute() {
        #if canImport(AVFoundation) && !os(macOS) && !os(watchOS)
        let route = AVAudioSession.sharedInstance().currentRoute
        var isBluetoothConnected = false
        var deviceName: String? = nil
        
        log("Audio route check: \(route.outputs.count) outputs found")
        for output in route.outputs {
            log(" - Output: name='\(output.portName)', type=\(output.portType.rawValue), uid='\(output.uid)'")
            if output.portType == .bluetoothA2DP ||
               output.portType == .bluetoothHFP ||
               output.portType == .bluetoothLE {
                isBluetoothConnected = true
                deviceName = output.portName
            }
        }
        log("Audio status: isConnected=\(isBluetoothConnected), deviceName='\(deviceName ?? "none")'")
        
        #if canImport(ExternalAccessory)
        let accessories = EAAccessoryManager.shared().connectedAccessories
        log("EAAccessoryManager: \(accessories.count) connected accessories")
        for acc in accessories {
            log(" - EAAccessory: name='\(acc.name)', mfr='\(acc.manufacturer)', model='\(acc.modelNumber)'")
        }
        #endif
        
        if isBluetoothConnected {
            // Retain battery level only if confirmed for this exact device and not an old stale 20% preset
            let existingLevel = (currentInfo?.deviceName == deviceName && currentInfo?.batteryLevel != 20) ? currentInfo?.batteryLevel : nil
            updateBatteryInfo(isConnected: true, level: existingLevel, deviceName: deviceName)
            
            #if canImport(CoreBluetooth)
            triggerPeripheralsSearch()
            #endif
        } else {
            // Disconnected
            #if canImport(CoreBluetooth)
            stopScanning()
            if let peripheral = connectedPeripheral {
                centralManager?.cancelPeripheralConnection(peripheral)
                self.connectedPeripheral = nil
            }
            #endif
            
            if currentInfo?.isConnected == true {
                updateBatteryInfo(isConnected: false, level: nil, deviceName: nil)
            }
        }
        #endif
    }
    
    // MARK: - CoreBluetooth Search & Active Scanning
    
    #if canImport(CoreBluetooth)
    public func triggerPeripheralsSearch() {
        guard let central = centralManager, central.state == .poweredOn else {
            log("triggerPeripheralsSearch skipped: centralManager state is not poweredOn (state=\(centralManager?.state.rawValue ?? -1))")
            return
        }
        
        let targetName = currentInfo?.deviceName?.lowercased()
        log("triggerPeripheralsSearch: target='\(targetName ?? "nil")'")
        
        // 1. Try to retrieve already connected peripherals matching known services
        let connected = central.retrieveConnectedPeripherals(withServices: knownServiceUUIDs)
        log("retrieveConnectedPeripherals returned \(connected.count) devices")
        for peripheral in connected {
            let peripheralName = peripheral.name?.lowercased() ?? ""
            log(" - Connected peripheral: name='\(peripheral.name ?? "nil")', id=\(peripheral.identifier), state=\(peripheral.state.rawValue)")
            if let target = targetName, !target.isEmpty {
                if peripheralName.contains(target) || target.contains(peripheralName) ||
                   peripheralName.contains("shokz") || peripheralName.contains("openrun") {
                    log("Matched connected peripheral: '\(peripheral.name ?? "nil")'")
                    connectToPeripheral(peripheral)
                    return
                }
            }
        }
        
        // 2. If not found in retrieved list, start active scan
        startScanning()
    }
    
    private func startScanning() {
        guard let central = centralManager, central.state == .poweredOn else { return }
        guard !isScanning else {
            log("startScanning called while already scanning")
            return
        }
        
        self.isScanning = true
        log("Starting active BLE scan for all peripherals (12s window)...")
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Timeout scan after 12 seconds to capture slow-interval BLE advertisements
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: false) { [weak self] _ in
            self?.log("12s scan timeout reached")
            self?.stopScanning()
        }
    }
    
    public func scanNow() {
        log("scanNow triggered by user")
        #if canImport(CoreBluetooth)
        triggerPeripheralsSearch()
        #endif
    }
    
    private func stopScanning() {
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = nil
        if isScanning {
            centralManager?.stopScan()
            self.isScanning = false
            log("Stopped BLE scan")
        }
    }
    
    private func connectToPeripheral(_ peripheral: CBPeripheral) {
        log("connectToPeripheral: '\(peripheral.name ?? "nil")' (id: \(peripheral.identifier))")
        stopScanning()
        self.connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager?.connect(peripheral, options: nil)
    }
    #endif
    
    // MARK: - State Updates & Persistence
    
    public func updateBatteryInfo(isConnected: Bool, level: Int?, deviceName: String?) {
        let newInfo = HeadphoneBatteryInfo(
            isConnected: isConnected,
            batteryLevel: level,
            deviceName: deviceName,
            updatedAt: Date()
        )
        self.currentInfo = newInfo
        self.storage.headphoneBatteryInfo = newInfo
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "LockSugarWidget")
        #endif
    }
    
    /// Allows user or quick preset to set battery level for connected headphones
    public func setBatteryLevel(level: Int?) {
        guard let current = currentInfo, current.isConnected else { return }
        updateBatteryInfo(isConnected: true, level: level, deviceName: current.deviceName)
    }
    
    /// Extracts battery level from BLE advertisement service data if present.
    /// Supports:
    /// - 0x180F (Standard Battery Service): single byte 0-100
    /// - 0xFE2C (Google Fast Pair Service): component format 0b0VVVVVVV
    public static func parseBatteryLevel(from serviceData: [CBUUID: Data]) -> Int? {
        #if canImport(CoreBluetooth)
        // 1. Check standard 0x180F Battery Service Data
        let batteryUUID = CBUUID(string: "180F")
        if let data = serviceData[batteryUUID], let first = data.first {
            let level = Int(first)
            if (0...100).contains(level) {
                return level
            }
        }
        
        // 2. Check Google Fast Pair 0xFE2C Service Data
        let fastPairUUID = CBUUID(string: "FE2C")
        if let data = serviceData[fastPairUUID], data.count >= 2 {
            for byte in data.reversed() {
                let level = Int(byte & 0x7F)
                if (0...100).contains(level) && byte != 0x7F {
                    return level
                }
            }
        }
        #endif
        return nil
    }
    
    /// Helper for testing in Simulator and previews
    public func setManualBatteryLevel(level: Int?, isConnected: Bool, deviceName: String? = "OpenRun by Shokz") {
        updateBatteryInfo(isConnected: isConnected, level: level, deviceName: isConnected ? deviceName : nil)
    }
}

// MARK: - CBCentralManagerDelegate & CBPeripheralDelegate

#if canImport(CoreBluetooth)
extension BluetoothBatteryMonitor: CBCentralManagerDelegate, CBPeripheralDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("CBCentralManagerDidUpdateState: \(central.state.rawValue) (poweredOn=\(central.state == .poweredOn))")
        if central.state == .poweredOn {
            checkCurrentAudioRoute()
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let localName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        let peripheralName = peripheral.name ?? ""
        let targetName = currentInfo?.deviceName ?? ""
        
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map(\.uuidString).joined(separator: ", ") ?? "none"
        var serviceDataSummary = "none"
        if let sData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            serviceDataSummary = sData.map { "\($0.key.uuidString): \($0.value.map { String(format: "%02X", $0) }.joined())" }.joined(separator: "; ")
        }
        let mfgHex = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)?.map { String(format: "%02X", $0) }.joined() ?? "none"
        
        log("Discovered: name='\(peripheralName)', local='\(localName)', RSSI: \(RSSI), UUIDs: [\(serviceUUIDs)], SvcData: [\(serviceDataSummary)], Mfg: \(mfgHex)")
        
        let pNameLower = peripheralName.lowercased()
        let lNameLower = localName.lowercased()
        let tNameLower = targetName.lowercased()
        
        let matchesTarget = !tNameLower.isEmpty && (pNameLower.contains(tNameLower) || tNameLower.contains(pNameLower) || lNameLower.contains(tNameLower))
        let matchesShokz = pNameLower.contains("shokz") || pNameLower.contains("openrun") || lNameLower.contains("shokz") || lNameLower.contains("openrun")
        
        if matchesTarget || matchesShokz {
            log("Matched target device: '\(peripheralName)' (local: '\(localName)')")
            // Check advertisement service data first (fast path without connection)
            if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
               let batteryLevel = Self.parseBatteryLevel(from: serviceData) {
                let name = !localName.isEmpty ? localName : (!peripheralName.isEmpty ? peripheralName : targetName)
                log("Extracted battery level \(batteryLevel)% directly from service data for '\(name)'")
                updateBatteryInfo(isConnected: true, level: batteryLevel, deviceName: name)
                stopScanning()
                return
            }
            
            connectToPeripheral(peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("Connected to peripheral: '\(peripheral.name ?? "nil")'. Discovering services...")
        peripheral.discoverServices(nil)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            log("Error discovering services for '\(peripheral.name ?? "nil")': \(error.localizedDescription)")
            return
        }
        guard let services = peripheral.services else { return }
        log("Discovered \(services.count) services for '\(peripheral.name ?? "nil")': \(services.map(\.uuid.uuidString).joined(separator: ", "))")
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            log("Error discovering characteristics for service \(service.uuid.uuidString): \(error.localizedDescription)")
            return
        }
        guard let characteristics = service.characteristics else { return }
        log("Discovered \(characteristics.count) characteristics for service \(service.uuid.uuidString): \(characteristics.map(\.uuid.uuidString).joined(separator: ", "))")
        for characteristic in characteristics {
            let uuidStr = characteristic.uuid.uuidString.lowercased()
            if characteristic.uuid == batteryLevelCharacteristicUUID || uuidStr.contains("2a19") || uuidStr.contains("battery") {
                log("Attempting to read battery characteristic: \(characteristic.uuid.uuidString)")
                peripheral.readValue(for: characteristic)
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("Error reading characteristic \(characteristic.uuid.uuidString): \(error.localizedDescription)")
            return
        }
        let uuidStr = characteristic.uuid.uuidString.lowercased()
        guard characteristic.uuid == batteryLevelCharacteristicUUID || uuidStr.contains("2a19") || uuidStr.contains("battery"),
              let data = characteristic.value, !data.isEmpty else { return }
        
        let hexBytes = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        log("Read battery characteristic value for \(characteristic.uuid.uuidString): \(hexBytes) (\(data.count) bytes)")
        
        let rawLevel = Int(data[0])
        guard (0...100).contains(rawLevel) else {
            log("Value \(rawLevel) outside valid range (0...100)")
            return
        }
        
        let name = peripheral.name ?? currentInfo?.deviceName ?? "Bluetooth Device"
        log("Successfully updated battery level to \(rawLevel)% for '\(name)'")
        updateBatteryInfo(isConnected: true, level: rawLevel, deviceName: name)
    }
}
#endif
