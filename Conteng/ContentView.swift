//
//  ContentView.swift
//  Conteng
//
//  Created by Luqman on 11/06/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var strokes: [[CGPoint]] = []

    var body: some View {
        ZStack {
            DrawingView(strokes: $strokes)
                .background(Color.clear)
        }
        .edgesIgnoringSafeArea(.all)
    }
}
