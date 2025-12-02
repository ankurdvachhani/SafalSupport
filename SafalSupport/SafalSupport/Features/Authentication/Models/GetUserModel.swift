//
//  GetUserModel.swift
//  SafalIRDrainMate
//
//  Created by Apple on 31/07/25.
//

import Foundation

// MARK: - UserResponse
struct GetUserModel: Codable {
    let success: Bool
    let data: GetUserModelData?
    let message: String?
}

// MARK: - UserData
struct GetUserModelData: Codable {
    let id: String?
    let companySlug: String?
    let applicationSlug: String?
    let firstName: String?
    let lastName: String?
    let role: String?
    let country: String?
    let userSlug: String?
    let metadata: GetUserModelMetadata?
    let status: String?
    let comment: [String]?
    let createdAt: String?
    let updatedAt: String?
    let v: Int?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case companySlug
        case applicationSlug
        case firstName
        case lastName
        case role
        case country
        case userSlug
        case metadata
        case status
        case comment
        case createdAt
        case updatedAt
        case v = "__v"
        case email
    }
}

// MARK: - Metadata
struct GetUserModelMetadata: Codable {
    let organizationId: String?
    let ncpiNumber: String?
}
