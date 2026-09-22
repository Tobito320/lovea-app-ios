@preconcurrency import Metal
import os
import UIKit

/// One GPU texture per layer. Paint layers are document-sized, image layers photo-sized.
/// ponytail: ganze Texturen pro Ebene; bei Speichernot später Kacheln.
@MainActor
final class LayerTextureStore {
    let device: MTLDevice
    let canvasSize: CGSize
    let budgetBytes: Int
    private var textures: [UUID: MTLTexture] = [:]

    init(device: MTLDevice, canvasSize: CGSize, budgetBytes: Int) {
        self.device = device
        self.canvasSize = canvasSize
        self.budgetBytes = budgetBytes
    }

    /// 40 % of the memory the app may still use. The simulator reports 0, then 2 GiB.
    static func defaultBudget() -> Int {
        let available = os_proc_available_memory()
        return available > 0 ? Int(Double(available) * 0.4) : 2 << 30
    }

    var bytesInUse: Int {
        textures.values.reduce(0) { $0 + $1.width * $1.height * 4 }
    }

    var width: Int { Int(canvasSize.width) }
    var height: Int { Int(canvasSize.height) }

    func texture(for layerID: UUID) -> MTLTexture? {
        textures[layerID]
    }

    func set(_ texture: MTLTexture, for layerID: UUID) {
        textures[layerID] = texture
    }

    @discardableResult
    func makeEmpty(for layerID: UUID) throws -> MTLTexture {
        try reserve(width * height * 4, replacing: layerID)
        guard let texture = GPU.makeTexture(device, width: width, height: height),
              let command = GPU.queue?.makeCommandBuffer() else { throw EngineError.deviceUnavailable }
        GPU.fill(texture, command: command)
        command.commit()
        textures[layerID] = texture
        return texture
    }

    func load(pngData: Data, for layerID: UUID) throws {
        guard let pixels = RasterOps.decode(pngData) else { throw EngineError.decode }
        try setPixels(pixels, for: layerID)
    }

    func setPixels(_ pixels: RasterOps.Pixels, for layerID: UUID) throws {
        try reserve(pixels.width * pixels.height * 4, replacing: layerID)
        let existing = textures[layerID].flatMap { $0.width == pixels.width && $0.height == pixels.height ? $0 : nil }
        guard let texture = GPU.upload(pixels.bytes, width: pixels.width, height: pixels.height, into: existing) else {
            throw EngineError.deviceUnavailable
        }
        textures[layerID] = texture
    }

    func pngData(for layerID: UUID) async -> Data? {
        guard let texture = textures[layerID] else { return nil }
        let pixels = RasterOps.Pixels(bytes: await GPU.readBytes(texture), width: texture.width, height: texture.height)
        return await Task.detached(priority: .utility) { RasterOps.encode(pixels) }.value
    }

    func remove(_ layerID: UUID) {
        textures[layerID] = nil
    }

    private func reserve(_ bytes: Int, replacing layerID: UUID) throws {
        let replaced = textures[layerID].map { $0.width * $0.height * 4 } ?? 0
        guard bytesInUse - replaced + bytes <= budgetBytes else { throw EngineError.memoryBudget }
    }
}
