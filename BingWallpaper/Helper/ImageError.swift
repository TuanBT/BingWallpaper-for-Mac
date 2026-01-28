//
//  ImageError.swift
//  BingWallpaper
//
//  Created by Laurenz Lazarus on 23.03.24.
//

import Foundation

enum ImageError: LocalizedError {
    case dataNotValid
    case downloadFailed(underlying: Error?)
    case saveFailed(underlying: Error?)
    case loadFailed(underlying: Error?)
    
    var errorDescription: String? {
        switch self {
        case .dataNotValid:
            return "Image data is not valid"
        case .downloadFailed(let error):
            return "Failed to download image: \(error?.localizedDescription ?? "Unknown error")"
        case .saveFailed(let error):
            return "Failed to save image: \(error?.localizedDescription ?? "Unknown error")"
        case .loadFailed(let error):
            return "Failed to load image: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}

enum NetworkError: LocalizedError {
    case noConnection
    case invalidResponse
    case requestFailed(statusCode: Int)
    case decodingFailed(underlying: Error?)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .invalidResponse:
            return "Invalid server response"
        case .requestFailed(let statusCode):
            return "Request failed with status code: \(statusCode)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error?.localizedDescription ?? "Unknown error")"
        case .timeout:
            return "Request timed out"
        }
    }
}

enum WallpaperError: LocalizedError {
    case appleScriptFailed(message: String?)
    case setWallpaperFailed(underlying: Error?)
    case noImageAvailable
    
    var errorDescription: String? {
        switch self {
        case .appleScriptFailed(let message):
            return "AppleScript failed: \(message ?? "Unknown error")"
        case .setWallpaperFailed(let error):
            return "Failed to set wallpaper: \(error?.localizedDescription ?? "Unknown error")"
        case .noImageAvailable:
            return "No image available to set as wallpaper"
        }
    }
}
