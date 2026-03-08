//
//  ShareAuthErrorView.swift
//  ShareExtension
//
//  Created by Sourabh Mazumder on 8/3/2026.
//

import SwiftUI

struct ShareAuthErrorView: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String
    var onRetry: (() -> Void)?
    var onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: icon)
                        .font(.system(size: 44))
                        .foregroundColor(.red)
                }

                VStack(spacing: 10) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                VStack(spacing: 12) {
                    if let onRetry = onRetry {
                        Button(action: onRetry) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                Text("Try Again")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 40)
                    }

                    Button(action: onDismiss) {
                        Text(buttonTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(onRetry != nil ? .secondary : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(onRetry != nil ? Color(UIColor.secondarySystemBackground) : Color.blue)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.top, 8)

                Spacer()
            }
            .navigationTitle("Smart Todo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}
