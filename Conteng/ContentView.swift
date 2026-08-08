//
//  ContentView.swift
//  Conteng
//
//  Created by Luqman on 11/06/2025.
//

import SwiftUI

struct ContentView: View {
    let document: DrawingDocument
    @ObservedObject var preferences: DrawingPreferences
    let canvasID: CanvasID

    var body: some View {
        ZStack {
            DrawingView(
                document: document,
                preferences: preferences,
                canvasID: canvasID
            )
                .background(Color.clear)

            VStack {
                MiniToolbar(preferences: preferences)
                    .padding(.top, 12)
                Spacer()
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
