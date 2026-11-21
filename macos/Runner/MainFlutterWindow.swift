import AuthenticationServices
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var redditAuthHandler: MacRedditAuthHandler?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    redditAuthHandler = MacRedditAuthHandler(
      window: self,
      messenger: flutterViewController.engine.binaryMessenger
    )

    super.awakeFromNib()
  }

  override func close() {
    redditAuthHandler?.invalidate()
    redditAuthHandler = nil
    super.close()
  }
}

@MainActor
private final class MacRedditAuthHandler: NSObject,
  ASWebAuthenticationPresentationContextProviding
{
  private weak var window: NSWindow?
  private let channel: FlutterMethodChannel
  private var activeSession: ASWebAuthenticationSession?
  private var pendingResult: FlutterResult?
  private var activeSessionId: Int = 0

  private static let reservedCustomSchemes: Set<String> = [
    "http", "https", "file", "ftp", "mailto", "tel", "javascript",
    "data", "vbscript", "about", "blob", "chrome", "edge", "shell",
  ]

  init(window: NSWindow, messenger: FlutterBinaryMessenger) {
    self.window = window
    self.channel = FlutterMethodChannel(
      name: "me.neon16bit.savedex/reddit_auth",
      binaryMessenger: messenger
    )
    super.init()
    self.channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  func invalidate() {
    channel.setMethodCallHandler(nil)
    cancelPending(notifyCanceled: false)
  }

  private static func isAllowedCustomScheme(_ scheme: String) -> Bool {
    let scalars = Array(scheme.unicodeScalars)
    guard !scalars.isEmpty, scalars.count <= 64,
      !reservedCustomSchemes.contains(scheme)
    else {
      return false
    }
    guard let first = scalars.first, first >= "a" && first <= "z" else {
      return false
    }
    return scalars.dropFirst().allSatisfy { scalar in
      (scalar >= "a" && scalar <= "z")
        || (scalar >= "0" && scalar <= "9")
        || scalar == "+"
        || scalar == "-"
        || scalar == "."
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startDesktopCustomSchemeAuth":
      guard
        let args = call.arguments as? [String: Any],
        let authUrl = args["authUrl"] as? String,
        let rawScheme = args["callbackScheme"] as? String,
        !rawScheme.isEmpty,
        let url = URL(string: authUrl)
      else {
        result(
          FlutterError(
            code: "INVALID_ARGS",
            message: "Missing authUrl or callbackScheme argument.",
            details: nil
          )
        )
        return
      }

      let callbackScheme = rawScheme.lowercased()
      guard
        Self.isAllowedCustomScheme(callbackScheme),
        let urlScheme = url.scheme?.lowercased(),
        urlScheme == "https",
        let host = url.host,
        !host.isEmpty
      else {
        result(
          FlutterError(
            code: "INVALID_REDIRECT_URI",
            message: "Invalid custom callback scheme or authorization URL.",
            details: nil
          )
        )
        return
      }

      cancelPending(notifyCanceled: true)
      activeSessionId &+= 1
      let sessionId = activeSessionId
      pendingResult = result

      let session = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackScheme
      ) { [weak self] callbackURL, error in
        DispatchQueue.main.async {
          guard let self = self, self.activeSessionId == sessionId else {
            return
          }
          let currentResult = self.pendingResult
          self.pendingResult = nil
          self.activeSession = nil
          guard let currentResult = currentResult else { return }

          if let error = error {
            if let authError = error as? ASWebAuthenticationSessionError,
              authError.code == .canceledLogin
            {
              currentResult(
                FlutterError(
                  code: "CANCELED",
                  message: "Authorization was canceled.",
                  details: nil
                )
              )
            } else {
              currentResult(
                FlutterError(
                  code: "AUTH_FAILED",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            }
            return
          }

          guard let callbackURL = callbackURL else {
            currentResult(
              FlutterError(
                code: "NO_CALLBACK",
                message: "No callback URL received.",
                details: nil
              )
            )
            return
          }

          currentResult(callbackURL.absoluteString)
        }
      }

      session.presentationContextProvider = self
      session.prefersEphemeralWebBrowserSession = false
      activeSession = session

      if !session.start() {
        activeSessionId &+= 1
        activeSession = nil
        pendingResult = nil
        result(
          FlutterError(
            code: "BROWSER_LAUNCH_FAILED",
            message: "Could not start ASWebAuthenticationSession.",
            details: nil
          )
        )
      }

    case "cancelDesktopCustomSchemeAuth":
      cancelPending(notifyCanceled: true)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func cancelPending(notifyCanceled: Bool) {
    activeSessionId &+= 1
    let session = activeSession
    let currentResult = pendingResult
    activeSession = nil
    pendingResult = nil
    session?.cancel()
    if notifyCanceled, let currentResult = currentResult {
      currentResult(
        FlutterError(
          code: "CANCELED",
          message: "Authorization was canceled.",
          details: nil
        )
      )
    }
  }

  func presentationAnchor(
    for session: ASWebAuthenticationSession
  ) -> ASPresentationAnchor {
    return window
      ?? NSApplication.shared.windows.first { $0.isKeyWindow }
      ?? ASPresentationAnchor()
  }
}
