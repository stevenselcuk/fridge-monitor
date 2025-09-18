import SwiftUI
import CoreBluetooth
import Combine
import UserNotifications

internal class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func sendFridgeOpenNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Fridge Alert!"
        content.body = "Your refrigerator door was just opened."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

struct DoorOpenEvent: Codable, Identifiable {
    let id = UUID()
    let date: Date
}

class FridgeDataManager: ObservableObject {
    @Published var events: [DoorOpenEvent] = []
    
    var todayOpenCount: Int {
        events.filter { Calendar.current.isDateInToday($0.date) }.count
    }
    
    func addOpenEvent() {
        DispatchQueue.main.async {
            self.events.insert(DoorOpenEvent(date: Date()), at: 0)
        }
    }
    
    func resetToday() {
        DispatchQueue.main.async {
            self.events.removeAll { Calendar.current.isDateInToday($0.date) }
        }
    }
}

enum ConnectionState {
    case disconnected, scanning, connecting, connected, failed
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    let fridgeServiceUUID = CBUUID(string: "c48e6067-5295-43d8-9c59-16616a5a300a")
    let doorCountCharUUID = CBUUID(string: "a1e8f2de-570a-45b3-851f-365a6a364d1f")
    let batteryLevelCharUUID = CBUUID(string: "2a19")
    let resetCounterCharUUID = CBUUID(string: "f0b1a051-a20c-43f1-b1e4-39f5c43a3d53")
    
    var centralManager: CBCentralManager!
    var fridgePeripheral: CBPeripheral?
    var resetCharacteristic: CBCharacteristic?

    @Published var state: ConnectionState = .disconnected
    @Published var doorOpenCount: Int = 0
    @Published var m5BatteryLevel: Int = -1
    private var lastKnownCount: Int = -1
    
    var dataManager: FridgeDataManager
    
    var connectionStatusText: String {
        switch state {
        case .disconnected: return "Disconnected"
        case .scanning: return "Searching for Fridge Monitor..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected & Monitoring"
        case .failed: return "Connection Failed"
        }
    }
    
    init(dataManager: FridgeDataManager) {
        self.dataManager = dataManager
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        state = .scanning
        centralManager.scanForPeripherals(withServices: [fridgeServiceUUID], options: nil)
    }
    
    func sendResetCommand() {
        guard let peripheral = fridgePeripheral, let characteristic = resetCharacteristic else { return }
        let data = "1".data(using: .utf8)!
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        DispatchQueue.main.async {
            self.doorOpenCount = 0
            self.dataManager.resetToday()
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { startScanning() } else { state = .disconnected }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        centralManager.stopScan()
        fridgePeripheral = peripheral
        fridgePeripheral?.delegate = self
        state = .connecting
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        state = .connected
        peripheral.discoverServices([fridgeServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        state = .failed
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        fridgePeripheral = nil
        resetCharacteristic = nil
        state = .disconnected
        m5BatteryLevel = -1
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == fridgeServiceUUID {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            if characteristic.uuid == resetCounterCharUUID {
                resetCharacteristic = characteristic
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        DispatchQueue.main.async {
            switch characteristic.uuid {
            case self.doorCountCharUUID:
                let count32 = data.withUnsafeBytes { $0.load(as: Int32.self) }
                let count = Int(count32)
                
                self.doorOpenCount = count
                
                if self.lastKnownCount != -1 && count > self.lastKnownCount {
                    self.dataManager.addOpenEvent()
                    
                    if UIApplication.shared.applicationState != .active {
                        NotificationManager.shared.sendFridgeOpenNotification()
                    }
                }
                self.lastKnownCount = count

            case self.batteryLevelCharUUID:
                if !data.isEmpty {
                    self.m5BatteryLevel = Int(data[0])
                }
                
            default:
                break
            }
        }
    }
}

struct MainView: View {
    @ObservedObject var bleManager: BLEManager
    @ObservedObject var dataManager: FridgeDataManager
    
    private var batteryIconName: String {
        guard bleManager.m5BatteryLevel >= 0 else { return "questionmark.circle" }
        switch bleManager.m5BatteryLevel {
        case 76...100: return "battery.100"
        case 51...75: return "battery.75"
        case 26...50: return "battery.50"
        case 6...25: return "battery.25"
        default: return "battery.0"
        }
    }

    private var batteryIconColor: Color {
        guard bleManager.m5BatteryLevel >= 0 else { return .gray }
        return bleManager.m5BatteryLevel > 20 ? .white : .red
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.15).ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    if bleManager.state == .connected {
                        HStack(spacing: 5) {
                            Image(systemName: batteryIconName)
                                .foregroundColor(batteryIconColor)
                            Text(bleManager.m5BatteryLevel >= 0 ? "\(bleManager.m5BatteryLevel)%" : "--%")
                        }
                        .padding(8).background(Color.black.opacity(0.2)).cornerRadius(10)
                    }
                }
                .padding(.trailing)
                
                Text("Fridge Monitor").font(.largeTitle).fontWeight(.bold)
                
                Spacer()
                
                Text("Today's Count")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("\(dataManager.todayOpenCount)")
                    .font(.system(size: 150, weight: .bold))
                    .foregroundColor(.cyan)

                Spacer()
                
                if bleManager.state == .disconnected || bleManager.state == .failed {
                    Button(action: { bleManager.startScanning() }) {
                        Text("Scan Again")
                            .fontWeight(.bold).padding().background(Color.white)
                            .foregroundColor(.blue).cornerRadius(15)
                    }
                    .padding(.bottom)
                }
                
                Text(bleManager.connectionStatusText)
                    .font(.footnote).padding(.bottom)
            }
            .foregroundColor(.white)
            .padding()
        }
    }
}

struct StatisticsView: View {
    @ObservedObject var dataManager: FridgeDataManager
    
    var body: some View {
        NavigationView {
            List {
                if dataManager.events.isEmpty {
                    Text("No door openings recorded yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(dataManager.events) { event in
                        HStack {
                            Image(systemName: "door.left.hand.open")
                                .foregroundColor(.blue)
                            Text("Opened at")
                            Text(event.date, style: .time)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(event.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

struct SettingsView: View {
    @ObservedObject var bleManager: BLEManager

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Actions")) {
                    Button(action: {
                        bleManager.sendResetCommand()
                    }) {
                        Label("Reset Counter on Device", systemImage: "arrow.counterclockwise.circle")
                            .foregroundColor(.red)
                    }
                    .disabled(bleManager.state != .connected)
                }
            }
            .navigationTitle("Settings")
        }
    }
}


@main
struct FridgeApp: App {
    @StateObject private var dataManager = FridgeDataManager()
    @StateObject private var bleManager: BLEManager
    
    init() {
        let data = FridgeDataManager()
        _dataManager = StateObject(wrappedValue: data)
        _bleManager = StateObject(wrappedValue: BLEManager(dataManager: data))
        
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                MainView(bleManager: bleManager, dataManager: dataManager)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                StatisticsView(dataManager: dataManager)
                    .tabItem {
                        Label("History", systemImage: "list.bullet")
                    }

                SettingsView(bleManager: bleManager)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
        }
    }
}

