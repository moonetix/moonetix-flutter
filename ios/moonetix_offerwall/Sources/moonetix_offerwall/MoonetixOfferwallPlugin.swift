import Flutter
import MoonetixOfferwall
import UIKit

/// iOS side of the Moonetix plugin. It calls the native Moonetix iOS SDK (MoonetixOfferwall) and
/// forwards its events to Dart with `event` calls (`type`, and `code` and `message` for errors).
public class MoonetixOfferwallPlugin: NSObject, FlutterPlugin {
  static let channelName = "com.moonetix/offerwall"

  private let channel: FlutterMethodChannel?

  init(channel: FlutterMethodChannel? = nil) {
    self.channel = channel
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = MoonetixOfferwallPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "init":
      Moonetix.configure(appId: args["appId"] as? String ?? "")
      result(nil)
    case "open":
      wireEvents()
      Moonetix.open(token: args["token"] as? String ?? "", options: MoonetixOfferwallPlugin.options(from: args))
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func wireEvents() {
    Moonetix.onOpened = { [weak self] in self?.send(["type": "opened"]) }
    Moonetix.onClosed = { [weak self] in self?.send(["type": "closed"]) }
    Moonetix.onError = { [weak self] error in
      self?.send(["type": "error", "code": error.code.name, "message": error.message])
    }
  }

  /// Maps the Dart options (`title`, `toolbarColor` as ARGB, `showLogo`).
  static func options(from args: [String: Any]) -> MoonetixOptions {
    var color: UIColor?
    if let number = args["toolbarColor"] as? NSNumber {
      let argb = UInt32(truncatingIfNeeded: number.int64Value)
      color = UIColor(
        red: CGFloat((argb >> 16) & 0xFF) / 255.0,
        green: CGFloat((argb >> 8) & 0xFF) / 255.0,
        blue: CGFloat(argb & 0xFF) / 255.0,
        alpha: 1
      )
    }
    return MoonetixOptions(
      title: args["title"] as? String,
      toolbarColor: color,
      showLogo: args["showLogo"] as? Bool ?? true
    )
  }

  /// Sends an event map to Dart.
  func send(_ event: [String: Any]) {
    channel?.invokeMethod("event", arguments: event)
  }
}
