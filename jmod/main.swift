//
//  main.swift
//  jmod
//
//  Created by Josh Billions on 7/18/22.
//

import Foundation

enum Argument: String, CaseIterable {
    case path = "--path"
    
    var index: Int? {
        CommandLine.arguments.firstIndex(of: rawValue)
    }
    
    var exists: Bool {
        index != nil
    }
    
    var stringValue: String? {
        guard let index = index,
              CommandLine.arguments.count > index + 1 else { return nil }
        return CommandLine.arguments[index + 1]
    }
}

enum Flag: String, CaseIterable {
    case dryRun = "--dryrun"
    case expand = "--expand"
    case collapse = "--collapse"
    case recursive = "--recursive"
    
    var index: Int? {
        CommandLine.arguments.firstIndex(of: rawValue)
    }
    
    var exists: Bool {
        index != nil
    }
}

struct JSONModifier {
    private let arguments: [Argument]
    private let flags: [Flag]
    private let startPath: String
    
    init() {
        arguments = Argument.allCases.filter({$0.exists})
        flags = Flag.allCases.filter({$0.exists})
        guard let pathIndex = arguments.firstIndex(of: .path),
              let path = arguments[pathIndex].stringValue,
              flags.contains(.expand) || flags.contains(.collapse) else {
            fatalError("jmod --path /path/to --recursive (--expand/--collapse)")
        }
        startPath = path
    }
    
    func start() {
        if flags.contains(.recursive) {
            let allPaths = allJSONPaths(in: startPath)
            for path in allPaths {
                process(fileAt: path)
            }
        } else {
           process(fileAt: startPath)
        }
    }
    
    private func process(fileAt path: String) {
        if flags.contains(.expand) {
            expandJSON(at: path)
        } else if flags.contains(.collapse) {
            collapseJSON(at: path)
        }
    }
    
    private func allJSONPaths(in path: String, existingJSONPaths: Set<String> = []) -> [String] {
        var existing = existingJSONPaths
        print("Evaluating \(path)")
        let url = URL(fileURLWithPath: path)
        if url.isFileURL,
           url.lastPathComponent.contains(".json") {
            print("Added JSON file")
            existing.insert(path)
        } else if url.hasDirectoryPath {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: path)
                for innerPath in contents {
                    let allPaths = allJSONPaths(in: url.appendingPathComponent(innerPath).path, existingJSONPaths: existing)
                    allPaths.forEach({existing.insert($0)})
                }
            } catch let error {
                print("Failed to list directory at \(path): \(error.localizedDescription)")
            }
        }
        return Array(existing)
    }
    
    private func collapseJSON(at path: String) {
        guard path.hasSuffix(".json") else { return }
        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            let object = try JSONSerialization.jsonObject(with: data)
            let cleanedData = try JSONSerialization.data(withJSONObject: object, options: .withoutEscapingSlashes)
            if flags.contains(.dryRun) { return }
            try cleanedData.write(to: url.appendingPathExtension(".new"))
            try FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: url.appendingPathExtension(".new"), to: url)
        } catch let error {
            fatalError("Failed to collapse JSON file at \(path): \(error.localizedDescription)")
        }
    }
    
    private func expandJSON(at path: String) {
        guard path.hasSuffix(".json") else { return }
        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            let object = try JSONSerialization.jsonObject(with: data)
            let cleanedData = try JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes, .prettyPrinted])
            if flags.contains(.dryRun) { return }
            try cleanedData.write(to: url.appendingPathExtension(".new"))
            try FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: url.appendingPathExtension(".new"), to: url)
        } catch let error {
            fatalError("Failed to expand JSON file at \(path): \(error.localizedDescription)")
        }
    }
}

let modifier = JSONModifier()
modifier.start()
