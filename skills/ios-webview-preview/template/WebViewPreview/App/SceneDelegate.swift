import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)

        // 内置脚本（vConsole）由 BuiltinScripts 在 loadAll() 里虚拟注入，
        // source 从 bundle 读，不需要 seed。

        if let url = URL(string: AppConfig.targetURL) {
            let webViewController = WebViewController(url: url)
            window.rootViewController = UINavigationController(rootViewController: webViewController)
        } else {
            window.rootViewController = Self.errorViewController(message: "Invalid URL in AppConfig.targetURL: \(AppConfig.targetURL)")
        }

        self.window = window
        window.makeKeyAndVisible()
    }

    private static func errorViewController(message: String) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: vc.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: vc.view.trailingAnchor, constant: -24),
        ])
        return vc
    }
}
