//
//  BLEManager.swift
//  BLE
//
//  Created by Marc Delling on 05.06.18.
//  Copyright © 2018 Silpion IT-Solutions GmbH. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BLEManagerDelegate: NSObjectProtocol {
    func didStopScanning(_ manager: BLEManager)
    func didConnect(_ manager: BLEManager)
    func didDisconnect(_ manager: BLEManager)
    func didUpdate(_ manager: BLEManager, status: String?)
    func didReceive(_ manager: BLEManager, message: String?)
}

class BLEManager: NSObject {
    
    let SerialServiceCBUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    let TxCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    let RxCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    let BaudCharacteristicUUID = CBUUID(string: "6E400004-B5A3-F393-E0A9-E50E24DCCA9E")
    let HWFCCharacteristicUUID = CBUUID(string: "6E400005-B5A3-F393-E0A9-E50E24DCCA9E")
    let NameCharacteristicUUID = CBUUID(string: "6E400006-B5A3-F393-E0A9-E50E24DCCA9E")
    let RSSI_range = -40..<(-15)  // optimal -22dB -> reality -48dB
    let notifyMTU = 20  // Extended Data Length 244 for iPhone 7, 7 Plus
    
    static var sharedInstance = BLEManager()
    
    weak var stopScanTimer : Timer?
    weak var delegate : BLEManagerDelegate?
    
    fileprivate var centralManager: CBCentralManager!
    fileprivate var discoveredPeripheral: CBPeripheral?
    fileprivate var uartTxCharacteristic: CBCharacteristic? {
        didSet {
            if let _ = self.uartTxCharacteristic {
                delegate?.didConnect(self)
            }
        }
    }
    fileprivate var uartRxCharacteristic: CBCharacteristic? {
        didSet {
            if let characteristic = self.uartRxCharacteristic {
                discoveredPeripheral?.setNotifyValue(true, for: characteristic)
            }
        }
    }
    fileprivate var baudCharacteristic: CBCharacteristic? {
        didSet {
            if let characteristic = self.baudCharacteristic {
                discoveredPeripheral?.readValue(for: characteristic)
            }
        }
    }
    fileprivate var hwfcCharacteristic: CBCharacteristic? {
        didSet {
            if let characteristic = self.hwfcCharacteristic {
                discoveredPeripheral?.readValue(for: characteristic)
            }
        }
    }
    
    fileprivate var receiveQueue = Data()
    fileprivate var sendQueue = [Data]()
    fileprivate var baud = UInt32(115200)
    fileprivate var hwfc = false
    
    var baudRate: UInt32 {
        get { return baud }
        set {
            baud = newValue
            if let characteristic = self.baudCharacteristic {
                discoveredPeripheral?.writeValue(baud.data, for: characteristic, type: .withResponse)
            }
        }
    }
    
    var hardwareFlowControl: Bool {
        get { return hwfc }
        set {
            hwfc = newValue
            if let characteristic = self.hwfcCharacteristic {
                discoveredPeripheral?.writeValue(hwfc.data, for: characteristic, type: .withResponse)
            }
        }
    }
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    public func write(data: Data) {
        if let characteristic = uartTxCharacteristic {
            sendQueue = data.chunked(by: 20)
            discoveredPeripheral?.writeValue(sendQueue.removeFirst(), for: characteristic, type: .withResponse)
        }
    }
    
    func applyStopScanTimer() {
        Timer.scheduledTimer(withTimeInterval: TimeInterval(9.0), repeats: false) { (_) in
            if self.centralManager.isScanning {
                self.centralManager.stopScan()
                self.delegate?.didStopScanning(self)
            }
        }
    }
    
    func killStopScanTimer() {
        if stopScanTimer != nil {
            stopScanTimer?.invalidate()
            stopScanTimer = nil
        }
    }
    
    func scan() {
        killStopScanTimer()
        centralManager.scanForPeripherals(withServices: [SerialServiceCBUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: true as Bool)])
        applyStopScanTimer()
        delegate?.didUpdate(self, status: "Scanning...")
    }
    
    func cleanup() {
        
        killStopScanTimer()
        uartTxCharacteristic = nil
        sendQueue.removeAll()
        
        guard let discoveredPeripheral = discoveredPeripheral else {
            return
        }
        
        guard discoveredPeripheral.state != .disconnected, let services = discoveredPeripheral.services else {
            // FIXME: state connecting
            centralManager.cancelPeripheralConnection(discoveredPeripheral)
            return
        }
        
        for service in services {
            if let characteristics = service.characteristics {
                for characteristic in characteristics {
                    if characteristic.uuid.isEqual(RxCharacteristicUUID) {
                        if characteristic.isNotifying {
                            discoveredPeripheral.setNotifyValue(false, for: characteristic)
                            //return // ??? not cancelling if setNotify false succeeds ???
                        }
                    }
                }
            }
        }
        
        centralManager.cancelPeripheralConnection(discoveredPeripheral)
    }
}

// MARK: - Central Manager delegate
extension BLEManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: () //scan()
        case .poweredOff, .resetting: cleanup()
        default: return
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        //guard RSSI_range.contains(RSSI.intValue) && discoveredPeripheral != peripheral else { return }
        print("didDiscover \(peripheral) with RSSI \(RSSI.intValue)")
        
        discoveredPeripheral = peripheral
        centralManager.connect(peripheral, options: [:])
        
        delegate?.didUpdate(self, status: "Discovered uart")
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error { print(error.localizedDescription) }
        cleanup()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        centralManager.stopScan()
        receiveQueue.removeAll()
        peripheral.delegate = self
        peripheral.discoverServices([SerialServiceCBUUID])
        delegate?.didUpdate(self, status: "Connected to " + (peripheral.name ?? "uart"))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if (peripheral == discoveredPeripheral) {
            cleanup()
            delegate?.didDisconnect(self)
        }
        //scan()
    }
    
}

// MARK: - Peripheral Delegate
extension BLEManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            cleanup()
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([TxCharacteristicUUID, RxCharacteristicUUID, BaudCharacteristicUUID, HWFCCharacteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if let error = error {
            print(error.localizedDescription)
            cleanup()
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == RxCharacteristicUUID {
                uartRxCharacteristic = characteristic
            } else if characteristic.uuid == TxCharacteristicUUID {
                uartTxCharacteristic = characteristic
            } else if characteristic.uuid == BaudCharacteristicUUID {
                baudCharacteristic = characteristic
            } else if characteristic.uuid == HWFCCharacteristicUUID {
                hwfcCharacteristic = characteristic
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
        } else if characteristic == uartRxCharacteristic {
            guard let newData = characteristic.value else { return }
            receiveQueue.append(newData)
            if newData[newData.count-1] == 0x0a {
                delegate?.didReceive(self, message: String(data: receiveQueue, encoding: .utf8))
                receiveQueue.removeAll()
            }
        } else if characteristic == baudCharacteristic {
            if let value = UInt32(data: characteristic.value) {
                baud = value
                print("Baud: \(baud)")
            }
        } else if characteristic == hwfcCharacteristic {
            hwfc = Bool(data: characteristic.value)
            print("HWFC: \(hwfc)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { print(error.localizedDescription) }
        guard characteristic.uuid == RxCharacteristicUUID else { return }
        if characteristic.isNotifying {
            print("Notification began on \(characteristic)")
        } else {
            print("Notification stopped on \(characteristic). Disconnecting...")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("write: \(error.localizedDescription)")
        } else {
            print("write successful")
            if sendQueue.count > 0, characteristic == self.uartTxCharacteristic {
                peripheral.writeValue(sendQueue.removeFirst(), for: characteristic, type: .withResponse)
            }
        }
    }
}

extension Data {
    var hexString : String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
    
    func chunked(by chunkSize: Int) -> [Data] {
        return stride(from: 0, to: self.count, by: chunkSize).map {
            Data(self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
    }
}

extension Bool {
    init(data: Data?) {
        if let data = data, data.count == 1 {
            self = (data[0] == 255)
        } else {
            self = false
        }
    }
    var data: Data {
        return Data(bytes: [self ? 255 : 0])
    }
}

extension UInt32 {
    init?(data: Data?) {
        guard let data = data, data.count == MemoryLayout<UInt32>.size else {
            return nil
        }
        self = data.withUnsafeBytes { $0.pointee }
    }
    var data: Data {
        var value = self // CFSwapInt32HostToBig(self)
        return Data(buffer: UnsafeBufferPointer(start: &value, count: 1))
    }
}
