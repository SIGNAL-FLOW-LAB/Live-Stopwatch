import SwiftUI
import AppKit
import Foundation

enum SFAppInfo {
    static var version: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
    }

    static var build: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "—"
    }

    static var versionText: String {
        "Version \(version)"
    }

    static var detailedVersionText: String {
        "Version \(version) (\(build))"
    }
}

struct SFAboutCard: View {
    let appName: String
    let appDescription: String
    let supportLinks: [SFSupportLink]

    var body: some View {
        VStack(spacing: 20) {
            appIdentity

            sfDivider

            supportSection

            sfDivider

            copyrightSection
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(SFTheme.white.opacity(0.06))
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                SFTheme.white.opacity(0.10),
                lineWidth: 1
            )
        )
        .cornerRadius(14)
    }

    // MARK: - App Identity

    private var appIdentity: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 86, height: 86)

            Text("SIGNAL FLOW \(appName)")
                .font(SFFont.title(24))
                .foregroundColor(SFTheme.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .padding(.top, 2)

            Text("by SIGNAL FLOW")
                .font(SFFont.title(15))
                .foregroundColor(SFTheme.mint)
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)
            
            Text("Version \(appVersion)")
                .font(SFFont.caption(13))
                .foregroundColor(SFTheme.white.opacity(0.62))

            Text(appDescription)
                .font(SFFont.body(14))
                .foregroundColor(SFTheme.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Support

    private var supportSection: some View {
        VStack(spacing: 9) {
            Text("SUPPORT")
                .font(SFFont.caption(12))
                .foregroundColor(SFTheme.white.opacity(0.52))

            ForEach(supportLinks) { item in
                Link(destination: item.url) {
                    Text(item.title)
                        .font(SFFont.body(14))
                        .foregroundColor(SFTheme.mint)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Copyright

    private var copyrightSection: some View {
        VStack(spacing: 3) {
            Text("Copyright © 2026 SIGNAL FLOW")
            Text("All rights reserved.")
        }
        .font(SFFont.caption(12))
        .foregroundColor(SFTheme.white.opacity(0.52))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Components

    private var sfDivider: some View {
        Rectangle()
            .fill(SFTheme.white.opacity(0.12))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Version

    private var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
    }
}

struct SFSupportLink: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}
