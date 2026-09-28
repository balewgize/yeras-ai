import Flutter
import Metal
import os
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "staylocal/device_capability")
    let channel = FlutterMethodChannel(
      name: "staylocal/device_capability", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getMemoryInfo":
        result([
          "totalBytes": ProcessInfo.processInfo.physicalMemory,
          "availableBytes": os_proc_available_memory(),
        ])
      case "getStorageInfo":
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let values = try? url.resourceValues(forKeys: [
          .volumeAvailableCapacityForImportantUsageKey,
          .volumeTotalCapacityKey,
        ])
        result([
          "freeBytes": values?.volumeAvailableCapacityForImportantUsage ?? 0,
          "totalBytes": values?.volumeTotalCapacity ?? 0,
        ])
      case "getGpuInfo":
        let device = MTLCreateSystemDefaultDevice()
        result([
          "renderer": device?.name ?? "Apple GPU",
          "metalSupported": device != nil,
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
