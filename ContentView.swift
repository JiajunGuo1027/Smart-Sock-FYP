//
//  ContentView.swift
//  Smart Sock
//
//  Created by 郭家骏 on 07/03/2024.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var fsrThreshold: Float = 50.0 // Default value, mid-range
    @State private var flexThreshold: Float = -5 // Default value, mid-range
    @State private var showAlert = false
    @State private var alertMessage = ""
    @StateObject private var bluetoothManager = BluetoothManager()
    
    // Add an initializer. And set the "onThresholdExceeded" closure for "BluetoothManager".
    init() {
        _bluetoothManager = StateObject(wrappedValue: BluetoothManager())
    }

    // The FetchRequest for SensorDataEntity
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SensorDataEntity.timestamp, ascending: true)],
        animation: .default)
    private var sensorDataItems: FetchedResults<SensorDataEntity>

    var body: some View {
        NavigationView {
              List {
                  // FSR Threshold setting section
                  Section(header: Text("FSR Threshold")) {
                      HStack {
                          Slider(value: $fsrThreshold, in: 0...100, step: 1)
                              .onChange(of: fsrThreshold) { newValue, _ in
                                  bluetoothManager.fsrThreshold = newValue
                              }
                          TextField("Threshold", value: $fsrThreshold, formatter: NumberFormatter())
                              .frame(width: 50)
                              .textFieldStyle(.roundedBorder)
                              .onChange(of: fsrThreshold) { newValue, _ in
                                  bluetoothManager.fsrThreshold = newValue
                              }
                      }
                  }
                  // Flex Threshold setting section
                  Section(header: Text("Flex Threshold")) {
                      HStack {
                          Slider(value: $flexThreshold, in: -10...0, step: 0.1)
                              .onChange(of: flexThreshold) { newValue, _ in
                                  bluetoothManager.flexThreshold = newValue
                              }
                          TextField("Threshold", value: $flexThreshold, formatter: NumberFormatter())
                              .frame(width: 50)
                              .textFieldStyle(.roundedBorder)
                              .onChange(of: flexThreshold) { newValue, _ in
                                  bluetoothManager.flexThreshold = newValue
                              }
                      }
                  }
                  
                // Anklet and wristband data display section
                Section(header: Text(bluetoothManager.statusMessage)) {
                    if bluetoothManager.isConnected {
                        //Display the names of the connected devices
                        ForEach(bluetoothManager.connectedDevices, id: \.self) { deviceName in
                            Text(deviceName)
                        }
                        // Display all data
                        ForEach(sensorDataItems) { data in
                            VStack(alignment: .leading) {
                               Text("FSR Change: \(data.fsrChange)")
                               Text("Flex Change: \(data.flexChange)")
                               Text("Heart Rate: \(data.heartRate)bpm")
                               Text("SpO2: \(data.spo2)%")
                               Text("Timestamp: \(data.timestamp.map { itemFormatter.string(from: $0) } ?? "N/A")")
                            }
                }
                .onDelete(perform: deleteItems)
            } else {
                // A message is displayed when the device is not connected or searched.
                Text("Make sure your Bluetooth device is on and in range.")
            }
        }
    }
    .navigationTitle("Smart Sock")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addData) {
                        Label("Add Sensor Data", systemImage: "plus")
                    }
                }
            }
            // Show Threshold
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Threshold"), message: Text(alertMessage), dismissButton: .default(Text("Confirm")))
            }
        }
        .onAppear {
            bluetoothManager.fsrThreshold = fsrThreshold
            bluetoothManager.flexThreshold = flexThreshold
            bluetoothManager.onThresholdExceeded = { sensorType in
                DispatchQueue.main.async {
                    self.alertMessage = "\(sensorType) sensor detected swelling."
                    self.showAlert = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }
    }
    
    // Load latest data
    private func addData() {
        withAnimation {
            let newData = SensorDataEntity(context: viewContext)
            newData.fsrChange = bluetoothManager.lastFsrChange
            newData.flexChange = bluetoothManager.lastFlexChange
            // heartRate and spo2 are stored as Int16 in Core Data, so convert these values accordingly
            newData.heartRate = Int16(bluetoothManager.lastHeartRate)
            newData.spo2 = Int16(bluetoothManager.lastSpo2)
            newData.timestamp = Date()
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    // Delete data
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { sensorDataItems[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
