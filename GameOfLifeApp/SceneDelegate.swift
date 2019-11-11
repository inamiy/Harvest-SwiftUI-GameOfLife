import UIKit
import Combine
import SwiftUI
import HarvestStore
import GameOfLife

class SceneDelegate: UIResponder, UIWindowSceneDelegate
{
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    )
    {
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)

            let store = Store<Root.Input, Root.State>(
                state: Root.State(pattern: .glider),
                mapping: Root.effectMapping(),
                world: makeRealWorld()
            )

            window.rootViewController = UIHostingController(
                rootView: AppView(store: store)
            )

            self.window = window
            window.makeKeyAndVisible()
        }
    }
}

private func makeRealWorld() -> Root.World<DispatchQueue>
{
    Root.World<DispatchQueue>(
        fileScheduler: DispatchQueue(label: "fileScheduler")
    )
}
