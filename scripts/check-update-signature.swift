#!/usr/bin/env swift
import CryptoKit
import Foundation

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: check-update-signature.swift <archive> <signature> <public key>\n".utf8))
    exit(64)
}

let archive = URL(fileURLWithPath: arguments[arguments.startIndex])
guard
    let signature = Data(base64Encoded: arguments[arguments.startIndex + 1]),
    let keyData = Data(base64Encoded: arguments[arguments.startIndex + 2]),
    let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)
else {
    FileHandle.standardError.write(Data("The signature or the public key isn't valid base64 EdDSA data.\n".utf8))
    exit(1)
}

let data = try Data(contentsOf: archive, options: .mappedIfSafe)
if key.isValidSignature(signature, for: data) {
    print("The update's signature matches the app's public key.")
} else {
    FileHandle.standardError.write(Data("The update's signature doesn't match the app's public key.\n".utf8))
    exit(1)
}
