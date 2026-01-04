import Foundation

@resultBuilder
public struct BatchUpdateBuilder {
    public static func buildBlock(_ components: BatchUpdateRequest.Request...) -> [BatchUpdateRequest.Request] {
        components
    }
    
    public static func buildBlock(_ components: [BatchUpdateRequest.Request]...) -> [BatchUpdateRequest.Request] {
        components.flatMap { $0 }
    }
    
    public static func buildEither(first component: [BatchUpdateRequest.Request]) -> [BatchUpdateRequest.Request] {
        component
    }
    
    public static func buildEither(second component: [BatchUpdateRequest.Request]) -> [BatchUpdateRequest.Request] {
        component
    }
    
    public static func buildOptional(_ component: [BatchUpdateRequest.Request]?) -> [BatchUpdateRequest.Request] {
        component ?? []
    }
    
    // Support for single element expressions
    public static func buildExpression(_ expression: BatchUpdateRequest.Request) -> [BatchUpdateRequest.Request] {
        [expression]
    }
    
    public static func buildExpression(_ expression: BatchRequestConvertible) -> [BatchUpdateRequest.Request] {
        [expression.request]
    }
    
    public static func buildExpression(_ expression: [BatchUpdateRequest.Request]) -> [BatchUpdateRequest.Request] {
        expression
    }
}
