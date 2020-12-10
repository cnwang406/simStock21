//
//  SceneDelegate.swift
//  simStock21
//
//  Created by peiyu on 2020/6/24.
//  Copyright © 2020 peiyu. All rights reserved.
//

import UIKit
import SwiftUI
import BackgroundTasks

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        // Get the managed object context from the shared persistent container.
//        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
//        let context = coreData.shared.context

        // Create the SwiftUI view and set the context as the value for the managedObjectContext environment keyPath.
        // Add `@Environment(\.managedObjectContext)` in the views that will need the context.
        let list = simStockList()
        let contentView = simStockListView(list: list)//.environment(\.managedObjectContext, context)

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
            simLog.addLog("=== sceneWillConnectTo ===")
            BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.mystock.simStock21.BGTask", using: DispatchQueue.global()) { (task) in
                simLog.addLog("背景剩餘時間: \(UIApplication.shared.backgroundTimeRemaining)s")
                let queue = OperationQueue()
                queue.maxConcurrentOperationCount = 1
                queue.addOperation {
                    simLog.addLog("BGTask running...")
                    list.requestTWSE()
                }
                task.expirationHandler = {
                    queue.cancelAllOperations()
                    simLog.addLog("BGTask canceled.")
                }
                let lastOperation = queue.operations.last
                lastOperation?.completionBlock = {
                    simLog.addLog("BGTask finished.")
                    task.setTaskCompleted(success: !(lastOperation?.isCancelled ?? false))
                }
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        simLog.addLog("=== sceneDidBecomeActive ===")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        simLog.addLog("=== sceneWillResignActive ===")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        simLog.addLog("=== sceneDidEnterBackground ===")
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
//        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
        try? coreData.shared.context.save()
        do {
            let request = BGAppRefreshTaskRequest(identifier: "com.mystock.simStock21.BGTask")
            request.earliestBeginDate = Date(timeIntervalSinceNow: 60) //背景預留時間
            try BGTaskScheduler.shared.submit(request)
            simLog.addLog("BGTask submitted")
        } catch {
            simLog.addLog("Failed to submit BGTask")
        }
    }
    
    func windowScene(_ windowScene: UIWindowScene, didUpdate previousCoordinateSpace: UICoordinateSpace, interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation, traitCollection previousTraitCollection: UITraitCollection) {

    }


}
