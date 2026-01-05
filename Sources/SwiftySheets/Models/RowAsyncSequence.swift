import Foundation

// MARK: - Row AsyncSequence

/// An AsyncSequence that streams rows from a spreadsheet range.
/// Useful for memory-efficient processing of large datasets.
public struct RowAsyncSequence: AsyncSequence, Sendable {
    public typealias Element = [String]
    
    private let spreadsheet: Spreadsheet
    private let range: SheetRange
    private let valueRenderOption: ValueRenderOption
    private let dateTimeRenderOption: DateRenderOption
    
    init(
        spreadsheet: Spreadsheet,
        range: SheetRange,
        valueRenderOption: ValueRenderOption = .unformatted,
        dateTimeRenderOption: DateRenderOption = .serialNumber
    ) {
        self.spreadsheet = spreadsheet
        self.range = range
        self.valueRenderOption = valueRenderOption
        self.dateTimeRenderOption = dateTimeRenderOption
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            spreadsheet: spreadsheet,
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption
        )
    }
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        private let spreadsheet: Spreadsheet
        private let range: SheetRange
        private let valueRenderOption: ValueRenderOption
        private let dateTimeRenderOption: DateRenderOption
        
        private var rows: [[String]]?
        private var currentIndex: Int = 0
        private var didFetch = false
        
        init(
            spreadsheet: Spreadsheet,
            range: SheetRange,
            valueRenderOption: ValueRenderOption,
            dateTimeRenderOption: DateRenderOption
        ) {
            self.spreadsheet = spreadsheet
            self.range = range
            self.valueRenderOption = valueRenderOption
            self.dateTimeRenderOption = dateTimeRenderOption
        }
        
        public mutating func next() async throws(SheetsError) -> [String]? {
            // Fetch all rows on first call (Google Sheets API doesn't support pagination)
            if !didFetch {
                do {
                    rows = try await spreadsheet.values(
                        range: range,
                        valueRenderOption: valueRenderOption,
                        dateTimeRenderOption: dateTimeRenderOption
                    )
                } catch {
                    throw error
                }
                didFetch = true
            }
            
            guard let rows = rows, currentIndex < rows.count else {
                return nil
            }
            
            let row = rows[currentIndex]
            currentIndex += 1
            return row
        }
    }
}

// MARK: - Typed Row AsyncSequence

/// An AsyncSequence that streams typed rows from a spreadsheet range.
public struct TypedRowAsyncSequence<T: SheetRowDecodable>: AsyncSequence, Sendable where T: Sendable {
    public typealias Element = T
    
    private let spreadsheet: Spreadsheet
    private let range: SheetRange
    private let valueRenderOption: ValueRenderOption
    private let dateTimeRenderOption: DateRenderOption
    
    init(
        spreadsheet: Spreadsheet,
        range: SheetRange,
        valueRenderOption: ValueRenderOption = .unformatted,
        dateTimeRenderOption: DateRenderOption = .serialNumber
    ) {
        self.spreadsheet = spreadsheet
        self.range = range
        self.valueRenderOption = valueRenderOption
        self.dateTimeRenderOption = dateTimeRenderOption
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            spreadsheet: spreadsheet,
            range: range,
            valueRenderOption: valueRenderOption,
            dateTimeRenderOption: dateTimeRenderOption
        )
    }
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        private let spreadsheet: Spreadsheet
        private let range: SheetRange
        private let valueRenderOption: ValueRenderOption
        private let dateTimeRenderOption: DateRenderOption
        
        private var rows: [[String]]?
        private var currentIndex: Int = 0
        private var didFetch = false
        
        init(
            spreadsheet: Spreadsheet,
            range: SheetRange,
            valueRenderOption: ValueRenderOption,
            dateTimeRenderOption: DateRenderOption
        ) {
            self.spreadsheet = spreadsheet
            self.range = range
            self.valueRenderOption = valueRenderOption
            self.dateTimeRenderOption = dateTimeRenderOption
        }
        
        public mutating func next() async throws(SheetsError) -> T? {
            if !didFetch {
                do {
                    rows = try await spreadsheet.values(
                        range: range,
                        valueRenderOption: valueRenderOption,
                        dateTimeRenderOption: dateTimeRenderOption
                    )
                } catch {
                    throw error
                }
                didFetch = true
            }
            
            guard let rows = rows, currentIndex < rows.count else {
                return nil
            }
            
            let row = rows[currentIndex]
            currentIndex += 1
            
            do {
                return try T(row: row)
            } catch {
                throw .invalidResponse(status: 0)
            }
        }
    }
}
