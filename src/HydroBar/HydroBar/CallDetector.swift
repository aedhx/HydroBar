//
//  CallDetector.swift
//  HydroBar
//
//  Détecte un appel ou une visio en cours : une app capte le micro, ou la
//  caméra est allumée. Un rappel qui s'affiche en plein partage d'écran est
//  au mieux gênant ; il attend la fin de l'appel.
//
//  Aucune autorisation n'est nécessaire : on lit seulement si le micro ou la
//  caméra sont utilisés par une app, jamais ce qu'ils captent.
//

import Foundation
import CoreAudio
import CoreMediaIO

final class CallDetector {
    static let shared = CallDetector()

    private(set) var isInCall = false
    /// Appelé sur le fil principal quand un appel commence ou se termine.
    var onChange: ((Bool) -> Void)?

    private var timer: Timer?
    /// Assez court pour qu'un rappel programmé ne tombe pas en début d'appel,
    /// assez long pour rester invisible en énergie.
    private static let pollInterval: TimeInterval = 15

    private init() {}

    func start() {
        guard timer == nil else { return }
        poll()
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in self?.poll() }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        guard isInCall else { return }
        isInCall = false
        onChange?(false)
    }

    private func poll() {
        let inCall = Self.microphoneInUse() || Self.cameraInUse()
        guard inCall != isInCall else { return }
        isInCall = inCall
        onChange?(inCall)
    }

    // MARK: - Micro

    /// Une app capte le micro. On interroge chaque processus audio (macOS 14+)
    /// plutôt que les périphériques : un casque USB est aussi une sortie, et
    /// écouter de la musique dessus le marquerait « en cours d'utilisation ».
    static func microphoneInUse() -> Bool {
        let processes: [AudioObjectID] = audioObjects(of: AudioObjectID(kAudioObjectSystemObject),
                                                      selector: kAudioHardwarePropertyProcessObjectList)
        return processes.contains { process in
            uint32Property(of: process, selector: kAudioProcessPropertyIsRunningInput) == 1
        }
    }

    private static func audioObjects(of object: AudioObjectID, selector: AudioObjectPropertySelector) -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(mSelector: selector,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &objects) == noErr else { return [] }
        return objects
    }

    private static func uint32Property(of object: AudioObjectID, selector: AudioObjectPropertySelector) -> UInt32? {
        var address = AudioObjectPropertyAddress(mSelector: selector,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    // MARK: - Caméra

    static func cameraInUse() -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return false }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == noErr else { return false }

        address.mSelector = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere)
        return devices.contains { device in
            var running: UInt32 = 0
            var runningSize: UInt32 = 0
            let status = CMIOObjectGetPropertyData(device, &address, 0, nil,
                                                   UInt32(MemoryLayout<UInt32>.size), &runningSize, &running)
            return status == noErr && running != 0
        }
    }
}
