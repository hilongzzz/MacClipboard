//
//  CustomCommand.swift
//  MacClipboard
//
//  Created by Yunlong Zhang on 2026/11/15.
//

import Foundation

/// 自定义 shell 命令动作：把选中文本通过 stdin 传给命令，stdout 作为结果写回剪贴板。
enum CustomCommand {

    static func run(command: String, on text: String) -> String? {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]

        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            stdin.fileHandleForWriting.write(Data(text.utf8))
            stdin.fileHandleForWriting.closeFile()
            let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }

            let output = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .newlines)
            return (output?.isEmpty == false) ? output : nil
        } catch {
            print("自定义命令执行失败: \(error)")
            return nil
        }
    }
}
