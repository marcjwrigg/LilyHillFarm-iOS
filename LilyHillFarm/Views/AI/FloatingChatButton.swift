//
//  FloatingChatButton.swift
//  LilyHillFarm
//
//  Floating action button to open Marc AI chat
//

import SwiftUI

struct FloatingChatButton: View {
    let aiService: AIService
    let supabaseManager: SupabaseManager
    @State private var showChat = false

    var body: some View {
        Button {
            showChat = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)

                // Marc's avatar
                Image("marc-avatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
        }
        .sheet(isPresented: $showChat) {
            ChatView(
                aiService: aiService,
                supabaseManager: supabaseManager
            )
        }
    }
}
