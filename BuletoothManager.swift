//
//  BluetoothManager.swift
//  Smart Sock
//
//  Created by 郭家骏 on 07/03/2024.
//

import Foundation
import CoreBluetooth

extension Data {
    func toFloat() -> Float? {
        guard self.count == 4 else { return nil }
        let value = withUnsafeBytes { $0.load(fromByteOffset: 0, as: Float32.self) }
        return value
    }

    func toInt16() -> Int16? {
        guard self.count >= 2 else { return nil }
        return self.withUnsafeBytes { $0.load(as: Int16.self) }
    }
}

let customSpo2CharacteristicUUIDString = "12345678-2002-1027-1234-123456789001"

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager: CBCentralManager!
    var peripherals = [CBPeripheral]()
    
    // Save peripheral references for the anklet and bracelet separately
    var handBandPeripheral: CBPeripheral?
    var smartSockPeripheral: CBPeripheral?
    
    // Service and CharacteristicUUID of anklet
    let sensorServiceUUID = CBUUID(string: "1101")
    let fsrCharacteristicUUID = CBUUID(string: "2101")
    let flexCharacteristicUUID = CBUUID(string: "2102")
    
    // Wristband services and CharacteristicUUID
    let heartRateServiceUUID = CBUUID(string: "180D")
    let heartRateCharacteristicUUID = CBUUID(string: "2A37")
    let spo2CharacteristicUUID = CBUUID(string: customSpo2CharacteristicUUIDString)

    // Publish attribute
    @Published var statusMessage: String = "Searching for Devices..."
    @Published var isConnected = false
    @Published var connectedDevices: [String] = [] {
        didSet {
            print("Connected Devices updated: \(connectedDevices)")
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    @Published var lastFsrValue: Float = 0.0
    @Published var lastFlexValue: Float = 0.0
    @Published var lastFsrChange: Float = 0.0 {
        didSet {
            print("LastFsrChange updated to: \(lastFsrChange)")
        }
    }
    @Published var lastFlexChange: Float = 0.0 {
        didSet {
            print("LastFlexChange updated to: \(lastFlexChange)")
        }
    }
    @Published var lastHeartRate: Int = 0 {
        didSet {
            print("LastHeartRate updated to: \(lastHeartRate)")
        }
    }
    @Published var lastSpo2: Int = 0 {
        didSet {
            print("LastSpo2 updated to: \(lastSpo2)")
        }
    }
    
    // Threshold attribute
    @Published var fsrThreshold: Float = 50.0 // Default value, mid-range
    @Published var flexThreshold: Float = -2.5 // Default value, mid-range
       
    // Callback when the threshold is exceeded
    var onThresholdExceeded: ((_ sensorType: String) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Bluetooth enabled, start scanning devices
            startScanning()
            statusMessage = "Bluetooth is ON. Scanning for devices..."
        case .poweredOff:
            // The Bluetooth function is disabled, prompting the user to turn on Bluetooth
            print("Bluetooth is powered off. Please turn it on.")
            statusMessage = "Bluetooth is powered off. Please turn it on."
        case .resetting:
            // Bluetooth is resetting and you can wait or initialize CBCentralManager again
            print("Bluetooth is resetting. Waiting for it to be available.")
        case .unauthorized:
            // The application is not authorized to use Bluetooth, prompting the user
            print("Bluetooth usage not authorized. Please check settings.")
        case .unsupported:
            // Device does not support Bluetooth, prompting the user
            print("Bluetooth is not supported on this device.")
        case .unknown:
            // Bluetooth status unknown, waiting for update
            print("Bluetooth state is unknown. Waiting for update.")
        @unknown default:
            print("A new state was added that is not handled")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Check to see if it's the peripheral we want
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID], serviceUUIDs.contains(sensorServiceUUID) || serviceUUIDs.contains(heartRateServiceUUID) {
            // Saves strong references to discovered peripherals
            peripherals.append(peripheral)
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        if !(connectedDevices.contains(peripheral.name ?? "Unknown Device")) {
                connectedDevices.append(peripheral.name ?? "Unknown Device")
            }
        // When the connection is successful, the specific device reference is saved as required
        if peripheral.name == "HeartRate_SPO2_Monitor" {
            handBandPeripheral = peripheral
        } else if peripheral.name == "Ankle_Swelling_Monitor" {
            smartSockPeripheral = peripheral
        }
        peripheral.discoverServices(nil)
    }
    
    func clearPeripherals() {
        peripherals.removeAll() // Call this method when appropriate to clean up the reference
    }

    // Cleaning peripherals when disconnected or no longer needed
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let index = connectedDevices.firstIndex(of: peripheral.name ?? "Unknown Device") {
            connectedDevices.remove(at: index)
        }

        if peripheral == handBandPeripheral {
            handBandPeripheral = nil // If disconnected, set it to nil
        } else if peripheral == smartSockPeripheral {
            smartSockPeripheral = nil // If an anklet is disconnected, set it to nil
        }
        
        isConnected = false
        
        if let index = peripherals.firstIndex(of: peripheral) {
            peripherals.remove(at: index)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == sensorServiceUUID || service.uuid == heartRateServiceUUID {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.read) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Check if there was an error during the update of the characteristic.
            if let error = error {
                print("Error updating value for characteristic \(characteristic.uuid): \(error.localizedDescription)")
                return
            }
            // Verify that the method is called
            print("Characteristic \(characteristic.uuid) updated value")
            // Print the raw data received
            if let data = characteristic.value {
                print("Received data: \(data as NSData)")
            }
        // Ensure that the data is not nil, otherwise print to the console and exit the function.
        guard let data = characteristic.value else {
            print("No data received from characteristic \(characteristic.uuid).")
            return
        }
        // Execute the following block on the main thread to update the UI or perform other tasks.
        DispatchQueue.main.async {
            switch characteristic.uuid {
                        case self.fsrCharacteristicUUID:
                            if let floatValue = data.toFloat() {
                                self.lastFsrChange = floatValue
                                if floatValue > self.fsrThreshold {
                                    self.onThresholdExceeded?("FSR")
                                }
                            }
                        case self.flexCharacteristicUUID:
                            if let floatValue = data.toFloat() {
                                self.lastFlexChange = floatValue
                                if floatValue < self.flexThreshold {
                                    self.onThresholdExceeded?("Flex")
                                }
                            }
                case self.heartRateCharacteristicUUID:
                    if let intValue = data.toInt16() {
                        self.lastHeartRate = Int(intValue)  // Convert Int16 to Int
                    }
                case self.spo2CharacteristicUUID:
                    if let intValue = data.toInt16() {
                        self.lastSpo2 = Int(intValue)
                    }
                // If the UUID does not match any known characteristics, print an unhandled message.
                    default:
                        print("Unhandled Characteristic UUID: \(characteristic.uuid)")
                }
            }
    }

    private func handleSensorData(characteristicUUID: CBUUID, value: Float?) {
        guard let value = value else { return }
        
        // Update the corresponding published property
        if characteristicUUID == fsrCharacteristicUUID {
            lastFsrValue = value
        } else if characteristicUUID == flexCharacteristicUUID {
            lastFlexValue = value
        }
        
    }
    
    //The startScanning method in this code now checks the status of the Bluetooth Center manager first and only starts scanning when the status is.poweredon. This is an additional protection measure, ensuring that scanning is performed only when Bluetooth is turned on.
    func startScanning() {
        if centralManager.state == .poweredOn {
            // Start scanning for all related services
            centralManager.scanForPeripherals(withServices: [sensorServiceUUID, heartRateServiceUUID], options: nil)
        } else {
            print("Bluetooth must be powered on before scanning.")
        }
    }
}
