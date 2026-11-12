import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

public final class BluetoothBatteryMonitor: NSObject, ObservableObject {
    public static let shared = BluetoothBatteryMonitor()
    
    @Published public private(set) var currentInfo: HeadphoneBatteryInfo?
    @Published public private(set) var isScanning: Bool = false
    
    private let storage: SharedStorage
    
    #if canImport(CoreBluetooth)
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private let knownServiceUUIDs: [CBUUID] = [
        CBUUID(string: "180F"), // Battery Service
        CBUUID(string: "1800"), // Generic Access Profile
        CBUUID(string: "180A"), // Device Information Service
        CBUUID(string: "FE2C")  // Google Fast Pair Service (Shokz / Android fast pair)
    ]
    private let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")
    private var scanTimeoutTimer: Timer?
    #endif
    
    public init(storage: SharedStorage = .shared) {
        self.storage = storage
        self.currentInfo = storage.headphoneBatteryInfo
        super.init()
        
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
        checkCurrentAudioRoute()
    }
    
    public func checkCurrentAudioRoute() {
        #if canImport(AVFoundation) && !os(macOS) && !os(watchOS)
        let route = AVAudioSession.sharedInstance().currentRoute
        var isBluetoothConnected = false
        var deviceName: String? = nil
        
        for output in route.outputs {
            if output.portType == .bluetoothA2DP ||
               output.portType == .bluetoothHFP ||
               output.portType == .bluetoothLE {
                isBluetoothConnected = true
                deviceName = output.portName
                break
            }
        }
        
        if isBluetoothConnected {
            // Retain existing battery level if already known for this device
            let currentLevel = (currentInfo?.deviceName == deviceName) ? currentInfo?.batteryLevel : nil
            updateBatteryInfo(isConnected: true, level: currentLevel, deviceName: deviceName)
            
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
        guard let central = centralManager, central.state == .poweredOn else { return }
        
        let targetName = currentInfo?.deviceName?.lowercased()
        
        // 1. Try to retrieve already connected peripherals matching known services
        let connected = central.retrieveConnectedPeripherals(withServices: knownServiceUUIDs)
        for peripheral in connected {
            let peripheralName = peripheral.name?.lowercased() ?? ""
            if let target = targetName, !target.isEmpty {
                if peripheralName.contains(target) || target.contains(peripheralName) ||
                   peripheralName.contains("shokz") || peripheralName.contains("openrun") {
                    connectToPeripheral(peripheral)
                    return
                }
            } else {
                connectToPeripheral(peripheral)
                return
            }
        }
        
        // 2. If not found in retrieved list, start active scan
        startScanning()
    }
    
    private func startScanning() {
        guard let central = centralManager, central.state == .poweredOn else { return }
        guard !isScanning else { return }
        
        self.isScanning = true
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Timeout scan after 3 seconds to avoid lingering scan state and conserve battery
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.stopScanning()
        }
    }
    
    private func stopScanning() {
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = nil
        if isScanning {
            centralManager?.stopScan()
            self.isScanning = false
        }
    }
    
    private func connectToPeripheral(_ peripheral: CBPeripheral) {
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
    
    /// Helper for testing in Simulator and previews
    public func setManualBatteryLevel(level: Int?, isConnected: Bool, deviceName: String? = "OpenRun by Shokz") {
        updateBatteryInfo(isConnected: isConnected, level: level, deviceName: isConnected ? deviceName : nil)
    }
}

// MARK: - CBCentralManagerDelegate & CBPeripheralDelegate

#if canImport(CoreBluetooth)
extension BluetoothBatteryMonitor: CBCentralManagerDelegate, CBPeripheralDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            checkCurrentAudioRoute()
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let localName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)?.lowercased() ?? ""
        let peripheralName = (peripheral.name ?? "").lowercased()
        let targetName = (currentInfo?.deviceName ?? "").lowercased()
        
        // Match against connected audio route name, or Shokz / OpenRun keywords
        let matchesTarget = !targetName.isEmpty && (peripheralName.contains(targetName) || targetName.contains(peripheralName) || localName.contains(targetName))
        let matchesShokz = peripheralName.contains("shokz") || peripheralName.contains("openrun") || localName.contains("shokz") || localName.contains("openrun")
        
        if matchesTarget || matchesShokz {
            connectToPeripheral(peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Discover all services
        peripheral.discoverServices(nil)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            // Discover all characteristics for each service
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            // Check for standard Battery Level (0x2A19)
            if characteristic.uuid == batteryLevelCharacteristicUUID {
                peripheral.readValue(for: characteristic)
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == batteryLevelCharacteristicUUID,
              let data = characteristic.value,
              let firstByte = data.first else { return }
        
        let level = Int(firstByte)
        let name = peripheral.name ?? currentInfo?.deviceName ?? "Bluetooth Device"
        updateBatteryInfo(isConnected: true, level: level, deviceName: name)
    }
}
#endif
