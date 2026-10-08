import CoreBluetooth
import Foundation

/// Was die Funkschicht dem Modell meldet. Nur Werte, die sich sicher über Threads schicken lassen.
enum TrackerEreignis: Sendable {
    enum BluetoothStatus: Sendable { case an, aus, nichtErlaubt, nichtVerfuegbar }
    case bluetooth(BluetoothStatus)
    case sucht
    case nichtGefunden
    case verbindet
    case verbunden(name: String?)
    case getrennt
    case daten(Data)
    case fehler(String)
}

/// Dünner CoreBluetooth-Rahmen um den Tracker. Alles CoreBluetooth läuft auf einer eigenen seriellen
/// Warteschlange; nach außen gehen nur `TrackerEreignis`-Werte. Das Zentralobjekt wird erst bei
/// `starten()` angelegt, nie beim App-Start, weil schon das Anlegen die Bluetooth-Abfrage zeigt.
///
/// Der Tracker nimmt nur eine Verbindung und sendet nach dem Trennen nicht mehr, bis man ihn antippt.
/// Darum bleibt ein `connect` offen: iOS verbindet von selbst, sobald er wieder sendet.
final class TrackerFunk: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, @unchecked Sendable {
    static let kennungSchluessel = "lovea.tracker.kennung"

    private let queue = DispatchQueue(label: "com.onlyus.lovea.tracker.ble")
    private let melden: @Sendable (TrackerEreignis) -> Void
    private let dienstUUID = CBUUID(string: TrackerProtokoll.dienst)
    private let schreibenUUID = CBUUID(string: TrackerProtokoll.schreiben)
    private let antwortUUID = CBUUID(string: TrackerProtokoll.antwort)

    // Nur auf `queue` anfassen.
    private var zentrale: CBCentralManager?
    private var geraet: CBPeripheral?
    private var schreiber: CBCharacteristic?
    private var benachrichtigt = false
    private var gewolltGetrennt = false
    private var suchStopp: DispatchWorkItem?

    init(melden: @escaping @Sendable (TrackerEreignis) -> Void) {
        self.melden = melden
        super.init()
    }

    static var gemerkteKennung: UUID? {
        UserDefaults.standard.string(forKey: kennungSchluessel).flatMap(UUID.init(uuidString:))
    }

    // MARK: Von außen

    func starten() {
        queue.async {
            self.gewolltGetrennt = false
            if let zentrale = self.zentrale {
                if zentrale.state == .poweredOn { self.verbindenOderSuchen(zentrale) }
            } else {
                self.zentrale = CBCentralManager(delegate: self, queue: self.queue)
            }
        }
    }

    func trennen(vergessen: Bool) {
        queue.async {
            self.gewolltGetrennt = true
            self.suchStopp?.cancel()
            self.zentrale?.stopScan()
            if let geraet = self.geraet { self.zentrale?.cancelPeripheralConnection(geraet) }
            if vergessen {
                UserDefaults.standard.removeObject(forKey: Self.kennungSchluessel)
                self.geraet = nil
            }
            self.schreiber = nil
            self.benachrichtigt = false
            self.melden(.getrennt)
        }
    }

    func senden(_ daten: Data) {
        queue.async {
            guard let geraet = self.geraet, let schreiber = self.schreiber, self.benachrichtigt else { return }
            let art: CBCharacteristicWriteType = schreiber.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            geraet.writeValue(daten, for: schreiber, type: art)
        }
    }

    // MARK: Zentrale

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            melden(.bluetooth(.an))
            if !gewolltGetrennt { verbindenOderSuchen(central) }
        case .poweredOff:
            melden(.bluetooth(.aus))
        case .unauthorized:
            melden(.bluetooth(.nichtErlaubt))
        case .unsupported:
            melden(.bluetooth(.nichtVerfuegbar))
        default:
            break // .unknown und .resetting sind kurz nach dem Anlegen normal
        }
    }

    private func verbindenOderSuchen(_ zentrale: CBCentralManager) {
        if let kennung = Self.gemerkteKennung, let bekannt = zentrale.retrievePeripherals(withIdentifiers: [kennung]).first {
            verbinden(bekannt, ueber: zentrale)
            return
        }
        melden(.sucht)
        zentrale.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        let stopp = DispatchWorkItem { [weak self] in
            guard let self, self.geraet == nil else { return }
            self.zentrale?.stopScan()
            self.melden(.nichtGefunden)
        }
        suchStopp = stopp
        queue.asyncAfter(deadline: .now() + 30, execute: stopp)
    }

    private func verbinden(_ peripheral: CBPeripheral, ueber zentrale: CBCentralManager) {
        geraet = peripheral
        peripheral.delegate = self
        melden(.verbindet)
        zentrale.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        guard let name, name.hasPrefix(TrackerProtokoll.namenspraefix) else { return }
        suchStopp?.cancel()
        central.stopScan()
        verbinden(peripheral, ueber: central)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Self.kennungSchluessel)
        peripheral.discoverServices([dienstUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard !gewolltGetrennt else { return }
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        schreiber = nil
        benachrichtigt = false
        guard !gewolltGetrennt else { return }
        melden(.getrennt)
        // Offenes connect: iOS verbindet, sobald der Tracker wieder sendet (Antippen, Bewegung).
        central.connect(peripheral)
    }

    // MARK: Gerät

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let dienst = peripheral.services?.first(where: { $0.uuid == dienstUUID }) else {
            melden(.fehler("Funkdienst des Trackers nicht gefunden"))
            return
        }
        peripheral.discoverCharacteristics([schreibenUUID, antwortUUID], for: dienst)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let merkmale = service.characteristics ?? []
        schreiber = merkmale.first { $0.uuid == schreibenUUID }
        if let antwort = merkmale.first(where: { $0.uuid == antwortUUID }) {
            peripheral.setNotifyValue(true, for: antwort)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == antwortUUID, characteristic.isNotifying, schreiber != nil else { return }
        benachrichtigt = true
        melden(.verbunden(name: peripheral.name))
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == antwortUUID, let wert = characteristic.value else { return }
        melden(.daten(wert))
    }
}
