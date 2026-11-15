//
//  AboutSettings
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/7/29.
//

import SwiftUI
import SwiftData

struct AboutSettingsView: View {
    @State private var hasAccessibilityPermission: Bool = false

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.5.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return String(format: NSLocalizedString("版本 %@ (Build %@)", comment: ""), version, build)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "paperclip.circle.fill")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("MacClipboard")
                            .font(.title2)
                            .bold()
                        Text(versionText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                HStack {
                    Label("辅助功能权限 (Accessibility)", systemImage: hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(hasAccessibilityPermission ? .green : .orange)

                    Spacer()

                    Button("前往设置") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            } header: {
                Text("系统权限状态")
            } footer: {
                Text(hasAccessibilityPermission
                     ? NSLocalizedString("权限已正常开启，支持自动模拟 Cmd+V 执行快捷粘贴。", comment: "")
                     : NSLocalizedString("缺失辅助功能权限时，无法自动模拟 Cmd+V 粘贴。请在系统设置中允许。", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            checkPermission()
        }
    }

    private func checkPermission() {
        hasAccessibilityPermission = AutoPaster.checkAccessibilityPermission(prompt: false)
    }
}
