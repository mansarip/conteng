//
//  ContentView.swift
//  Conteng
//
//  Created by Luqman on 11/06/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            DrawingView()
                .background(Color.clear)
        }
        .edgesIgnoringSafeArea(.all)
    }
}
