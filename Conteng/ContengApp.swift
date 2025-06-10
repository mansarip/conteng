//
//  ContengApp.swift
//  Conteng
//
//  Created by Luqman on 11/06/2025.
//

import SwiftUI

@main
struct ContengApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // WindowGroup tak digunakan di sini
        // Window akan handle dalam AppDelegate
        Settings {
            EmptyView()
        }
    }
}
