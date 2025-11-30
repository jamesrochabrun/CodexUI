//
//  CodexConfigService.swift
//  CodexUI
//

import Foundation

/// Service to read Codex configuration from ~/.codex/ directory
@Observable
final class CodexConfigService {

  // MARK: - Config Properties

  private(set) var model: String = "unknown"
  private(set) var reasoningEffort: String = "medium"
  private(set) var cliVersion: String = "unknown"
  private(set) var userEmail: String?
  private(set) var planType: String?

  // MARK: - Private

  private let fileManager = FileManager.default
  private var codexPath: String {
    let home = fileManager.homeDirectoryForCurrentUser.path
    return "\(home)/.codex"
  }

  // MARK: - Init

  init() {
    refresh()
  }
  
  // MARK: - Public
  
  func refresh() {
    loadConfig()
    loadVersion()
    loadAuth()
  }
  
  // MARK: - Config.toml Parsing
  
  private func loadConfig() {
    let configPath = "\(codexPath)/config.toml"
    guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
      return
    }
    
    // Simple TOML parsing for key = "value" patterns
    for line in content.components(separatedBy: .newlines) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      
      if trimmed.hasPrefix("model =") {
        model = parseTomlString(trimmed, key: "model") ?? model
      } else if trimmed.hasPrefix("model_reasoning_effort =") {
        reasoningEffort = parseTomlString(trimmed, key: "model_reasoning_effort") ?? reasoningEffort
      }
    }
  }
  
  private func parseTomlString(_ line: String, key: String) -> String? {
    // Extract value from: key = "value"
    let pattern = "\(key)\\s*=\\s*\"([^\"]+)\""
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
          let valueRange = Range(match.range(at: 1), in: line) else {
      return nil
    }
    return String(line[valueRange])
  }
  
  // MARK: - Version.json Parsing
  
  private func loadVersion() {
    let versionPath = "\(codexPath)/version.json"
    guard let data = fileManager.contents(atPath: versionPath),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let version = json["latest_version"] as? String else {
      return
    }
    cliVersion = version
  }
  
  // MARK: - Auth.json / JWT Parsing
  
  private func loadAuth() {
    let authPath = "\(codexPath)/auth.json"
    guard let data = fileManager.contents(atPath: authPath),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tokens = json["tokens"] as? [String: Any],
          let idToken = tokens["id_token"] as? String else {
      return
    }
    
    // Decode JWT payload (middle part)
    let parts = idToken.components(separatedBy: ".")
    guard parts.count >= 2 else { return }
    
    if let claims = decodeJWTPayload(parts[1]) {
      userEmail = claims["email"] as? String
      
      // Plan type is nested in https://api.openai.com/auth
      if let authClaims = claims["https://api.openai.com/auth"] as? [String: Any] {
        planType = authClaims["chatgpt_plan_type"] as? String
      }
    }
  }
  
  private func decodeJWTPayload(_ base64: String) -> [String: Any]? {
    // JWT uses base64url encoding, need to convert to standard base64
    var base64 = base64
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    
    // Add padding if needed
    let remainder = base64.count % 4
    if remainder > 0 {
      base64 += String(repeating: "=", count: 4 - remainder)
    }
    
    guard let data = Data(base64Encoded: base64),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    return json
  }
}
