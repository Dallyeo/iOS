//
//  APIResponse.swift
//  Dallyeo
//
//  BE 공통 응답 래퍼 ({ success, data, error }) 및 오류 타입
//

import Foundation

/// BE 공통 응답 포맷. null 필드는 서버에서 생략됨(NON_NULL).
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: APIErrorBody?
}

/// BE ApiError 바디. (필드는 코드 확인 전 추정 — code/message. 승환 확인 후 보정)
struct APIErrorBody: Decodable, Error {
    let code: String?
    let message: String?
}

/// 클라이언트 레벨 오류
enum APIClientError: Error {
    case invalidURL
    case transport(Error)       // 네트워크 실패
    case badStatus(Int)         // 2xx 아님 + 에러 바디 없음
    case business(APIErrorBody) // success=false (서버 비즈니스 오류)
    case emptyData              // success=true 인데 data 없음
    case decoding(Error)
}

/// data 없이 success만 오는 응답 파싱용
struct EmptyBody: Decodable {}
