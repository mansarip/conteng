//
//  AboutWindow.swift
//  Conteng
//
//  Created by Luqman on 11/06/2025.
//
import SwiftUI

struct AboutWindow: View {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 96, height: 96)
                .cornerRadius(20)
                .shadow(radius: 5)

            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App Name")
                .font(.title)
                .bold()
                .padding(.top, 10)

            // CREDIT
            Text("""
Created by Luqman "Abu Musa"
in Behrang 2020

Version \(appVersion)
""")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true) 

            Spacer(minLength: 10)
        }
        .padding(30)
        .frame(width: 300, height: 290)
    }
}