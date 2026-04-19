#if canImport(UIKit)
import UIKit

@MainActor
open class App: UIResponder, UIApplicationDelegate, UISceneDelegate {

    public var window: UIWindow?
    public var resolver: Root?

    open var body: any View {
        fatalError("Must override body property in your App subclass")
    }

    /// Entry point for `@main`. `UIResponder` doesn't provide `main()`, so
    /// subclasses annotated with `@main` would fail to compile without this.
    /// Uses `NSStringFromClass(self)` — dynamic dispatch through `class func`
    /// resolves `self` to the actual subclass at call time, so UIKit instantiates
    /// the correct delegate.
    public class func main() {
        UIApplicationMain(
            CommandLine.argc,
            CommandLine.unsafeArgv,
            nil,
            NSStringFromClass(self)
        )
    }

    open func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    open func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = type(of: self)
        return configuration
    }

    open func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
    open func applicationDidEnterBackground(_ application: UIApplication) {}
    open func applicationWillEnterForeground(_ application: UIApplication) {}
    open func applicationDidBecomeActive(_ application: UIApplication) {}
    open func applicationWillResignActive(_ application: UIApplication) {}

    open func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let resolver = Root()
        self.resolver = resolver
        let rootPlatformView = resolver.mount(body)

        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        vc.view.addSubview(rootPlatformView)
        rootPlatformView.pin(to: vc.view)

        window.rootViewController = vc
        window.makeKeyAndVisible()
    }

    open func sceneDidDisconnect(_ scene: UIScene) {}
    open func sceneDidBecomeActive(_ scene: UIScene) {}
    open func sceneWillResignActive(_ scene: UIScene) {}
    open func sceneWillEnterForeground(_ scene: UIScene) {}
    open func sceneDidEnterBackground(_ scene: UIScene) {}
}

#elseif canImport(AppKit)
import AppKit

@MainActor
open class App: NSObject, NSApplicationDelegate {

    public var window: NSWindow?
    public var resolver: Root?

    open var body: any View {
        fatalError("Must override body property in your App subclass")
    }

    open func applicationDidFinishLaunching(_ notification: Notification) {
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ForgeSwift App"
        window.center()
        self.window = window

        let resolver = Root()
        self.resolver = resolver
        let rootPlatformView = resolver.mount(body)

        let container = NSView(frame: contentRect)
        container.addSubview(rootPlatformView)
        rootPlatformView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rootPlatformView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            rootPlatformView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        window.contentView = container
        window.makeKeyAndOrderFront(nil)
    }

    open func applicationWillTerminate(_ notification: Notification) {}
    open func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    open func applicationDidBecomeActive(_ notification: Notification) {}
    open func applicationDidResignActive(_ notification: Notification) {}
    open func applicationDidHide(_ notification: Notification) {}
    open func applicationDidUnhide(_ notification: Notification) {}
}

#endif
