//
//  SettingsView
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import SwiftUI
import SwiftData

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "通用与粘贴"
    case filtering = "屏蔽过滤"
    case storage = "存储留存"
    case about = "关于与权限"

    var id: String { rawValue }

    var displayName: String {
        NSLocalizedString(rawValue, comment: "")
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .filtering: return "hand.raised"
        case .storage: return "internaldrive"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var selection: SettingsSection = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.displayName, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            Group {
                switch selection {
                case .general:
                    GeneralSettingsView(settings: settings)
                case .filtering:
                    IgnoreSettingsView(settings: settings)
                case .storage:
                    StorageSettingsView(settings: settings)
                case .about:
                    AboutSettingsView()
                }
            }
            .padding()
        }
        .frame(minWidth: 640, idealWidth: 680, minHeight: 460, idealHeight: 500)
        .appAccentTint(settings.accentColorName)
    }
}
