import Flutter
import MediaPlayer

/// Лайк / дизлайк в Control Center и на экране блокировки iOS.
/// Транспорт (play/pause/skip/seek) обрабатывает audio_service; здесь только customAction.
@objc class MiMusicRemoteCommandsPlugin: NSObject, FlutterPlugin {
  private static var handlerChannel: FlutterMethodChannel?

  static func register(with registrar: FlutterPluginRegistrar) {
    handlerChannel = FlutterMethodChannel(
      name: "com.ryanheise.audio_service.handler.methods",
      binaryMessenger: registrar.messenger()
    )
    let channel = FlutterMethodChannel(
      name: "mimusic/remote_commands",
      binaryMessenger: registrar.messenger()
    )
    let instance = MiMusicRemoteCommandsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    installLikeDislikeTargets()
  }

  private static func installLikeDislikeTargets() {
    guard handlerChannel != nil else { return }
    let center = MPRemoteCommandCenter.shared()
    center.likeCommand.isEnabled = true
    center.likeCommand.removeTarget(nil)
    center.likeCommand.addTarget { _ in
      handlerChannel?.invokeMethod(
        "customAction",
        arguments: ["name": "like", "extras": [:]] as [String: Any]
      )
      return .success
    }
    center.dislikeCommand.isEnabled = true
    center.dislikeCommand.removeTarget(nil)
    center.dislikeCommand.addTarget { _ in
      handlerChannel?.invokeMethod(
        "customAction",
        arguments: ["name": "dislike", "extras": [:]] as [String: Any]
      )
      return .success
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "refresh" {
      MiMusicRemoteCommandsPlugin.installLikeDislikeTargets()
      result(nil)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}
