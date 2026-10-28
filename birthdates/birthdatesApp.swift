//
//  birthdatesApp.swift
//  birthdates
//


import SwiftUI
import SwiftData

@main
struct birthdatesApp: App {
    private let containerService = DataContainerService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(containerService.modelContainer)
        .commands {
            SidebarCommands()
        }
    }
}
