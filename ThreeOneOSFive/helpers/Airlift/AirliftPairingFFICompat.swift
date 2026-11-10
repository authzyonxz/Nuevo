// Compatibility declarations for AirliftFFI pairing symbols.
// Some Xcode runners expose the non-pairing C declarations from the
// XCFramework module but omit these newer pairing declarations. These
// declarations preserve the exact C ABI and use distinct Swift names.
import Foundation

typealias AirliftPairReadyCallback = @convention(c) (
    UnsafeMutableRawPointer?,
    UnsafePointer<CChar>?,
    UInt16,
    UnsafePointer<UnsafePointer<CChar>?>?,
    UnsafePointer<UnsafePointer<CChar>?>?,
    Int,
    UnsafeMutableRawPointer?
) -> Void

typealias AirliftPairPinCallback = @convention(c) (
    UnsafePointer<CChar>?,
    UnsafeMutableRawPointer?
) -> Void

struct AirliftPairResult {
    var error: UnsafeMutablePointer<CChar>?
    var device_name: UnsafeMutablePointer<CChar>?
    var device_model: UnsafeMutablePointer<CChar>?
    var device_udid: UnsafeMutablePointer<CChar>?
    var pairing_file_path: UnsafeMutablePointer<CChar>?
    var host_alt_irk_hex: UnsafeMutablePointer<CChar>?

    init() {
        error = nil
        device_name = nil
        device_model = nil
        device_udid = nil
        pairing_file_path = nil
        host_alt_irk_hex = nil
    }
}

@_silgen_name("al_pairing_run_host")
func airlift_pairing_run_host(
    _ bindAddress: UnsafePointer<CChar>?,
    _ port: UInt16,
    _ name: UnsafePointer<CChar>?,
    _ model: UnsafePointer<CChar>?,
    _ outputPath: UnsafePointer<CChar>?,
    _ hostAltIRKHex: UnsafePointer<CChar>?,
    _ readyCallback: AirliftPairReadyCallback?,
    _ pinCallback: AirliftPairPinCallback?,
    _ context: UnsafeMutableRawPointer?,
    _ output: UnsafeMutablePointer<AirliftPairResult>?
) -> Int32

@_silgen_name("al_pairing_result_free")
func airlift_pairing_result_free(_ result: UnsafeMutablePointer<AirliftPairResult>?)
