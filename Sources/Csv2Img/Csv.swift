import Foundation
import CoreGraphics

/** Csv data structure

 ``Csv`` is a struct to store information to parse csv into table.

 ``Csv`` automatically recognize first row as column and others as rows.

 ```swift
 let rawCsv = """
 a,b,c
 1,2,3
 4,5,6
 7,8,9
 10,11,12
 """
 let csv = Csv.fromString(rawCsv)
 Output:
 | a  | b  | c  |
 | 1  | 2  | 3  |
 | 4  | 5  | 6  |
 | 7  | 8  | 9  |
 | 10 | 11 | 12 |
 ```
*/
public struct Csv {

    /// initialization
    ///
    /// `separator` is applied to each row and generate items per row.
    /// `columnNames` is array of column whose type is `String`.
    /// `Row` is array of row whose type is ``Row``
    public init(
        separator: String=",",
        columnNames: [Csv.ColumnName],
        rows: [Csv.Row]
    ) {
        self.imageMarker = ImageMaker(fontSize: 12)
        self.separator = separator
        self.columnNames = columnNames
        self.rows = rows
    }

    /// an separator applied to each row and column.
    public var separator: String
    /// an array of column name with type ``ColumnName``.
    public var columnNames: [ColumnName]
    /// an array of row whose type is ``Row`.
    public var rows: [Row]
    /// ``ImageMarker`` has responsibility to generate png-image from csv.
    private let imageMarker: ImageMakerType

    /// `data` has result of converstion from csv to png-image.
    private var data: Data?
}

extension Csv {
    /// Row (a line)
    ///
    /// Row is hrizontally separated group except first line.
    ///
    /// First line is treated as ``ColumnName``.
    ///
    /// eg.
    ///
    /// 1 2 3 4
    ///
    /// 5 6 7 8
    ///
    /// →Row is [5, 6, 7, 8].
    ///
    ///
    /// Because this class is usually initialized via ``Csv``, you do not have to take care about ``Row`` in detail.
    ///
    public struct Row {

        public init(index: Int, values: [String]) {
            self.index = index
            self.values = values
        }

        public var index: Int
        public var values: [String]

    }

    /// ColumnName (a head line)
    ///
    /// Column is at the first group of hrizontally separated groups.
    ///
    /// following lines are treated as ``Row``.
    ///
    /// eg.
    ///
    /// 1 2 3 4
    ///
    /// 5 6 7 8
    /// →ColumnName is [1, 2, 3, 4] and Row is [5, 6, 7, 8].
    ///
    /// Because this class is usually initialized via ``Csv``, you do not have to take care about ``ColumnName`` in detail.
    ///
    public struct ColumnName {

        public init(value: String) {
            self.value = value
        }

        public var value: String
    }
}

extension Csv {

    /// `Error` related with Csv implmentation.
    public enum Error: Swift.Error {
        /// Specified network url is invalid or failed to download csv data.
        case invalidDownloadResource(url: String, data: Data)
        /// Specified local url is invalid (file may not exist).
        case invalidLocalResource(url: String, data: Data)
        /// If file is not accessible due to security issue.
        case cannotAccessFile(url: String)
    }

    /// Generate `Csv` from `String` data.
    ///
    /// You cloud call `Csv.fromString` if you can own raw-CSV data.
    ///
    /// ```swift
    /// let rawCsv = """
    /// a,b,c
    /// 1,2,3
    /// 4,5,6
    /// 7,8,9
    /// 10,11,12
    /// """
    /// let csv = Csv.fromString(rawCsv)
    /// Output:
    /// | a  | b  | c  |
    /// | 1  | 2  | 3  |
    /// | 4  | 5  | 6  |
    /// | 7  | 8  | 9  |
    /// | 10 | 11 | 12 |
    ///```
    ///
    /// You cloud change separator by giving value to `separator` parameter.
    ///
    ///```swift
    /// let dotSeparated = """
    /// a.b.c
    /// 1.2.3
    /// 4.5.6
    /// 7.8.9
    /// """
    /// let csv = Csv.fromString(dotSeparated, separator: ".")
    /// Output:
    /// | a  | b  | c  |
    /// | 1  | 2  | 3  |
    /// | 4  | 5  | 6  |
    /// | 7  | 8  | 9  |
    /// | 10 | 11 | 12 |
    /// ```
    ///
    /// If certain row-item is very long, you could trim it with `maxLength`-th length.
    ///
    ///```swift
    /// let longCsv = """
    /// a.b.c
    /// 1.2.33333333333333333333333333333333333333333
    /// 4.5.6
    /// 7.8.9
    /// """
    /// let csv = Csv.fromString(dotSeparated, separator: ".", maxLength: 7)
    /// Output:
    /// | a  | b  | c        |
    /// | 1  | 2  | 3333333  |
    /// | 4  | 5  | 6        |
    /// | 7  | 8  | 9        |
    /// | 10 | 11 | 12       |
    /// ```
    ///
    /// - Parameters:
    ///     - str: Row String
    ///     - separator: Default separator in a row is `","`. You cloud change it by giving separator to `separator` parameter.
    ///     - maxLength: Default value is nil. if `maxLength` is not nil, every row-item length is limited by `maxLength`.
    public static func fromString(_ str: String, separator: String = ",", maxLength: Int? = nil) -> Csv {
        var csv = Csv(
            separator: separator,
            columnNames: [],
            rows: []
        )
        var lines = str.components(separatedBy: CharacterSet(charactersIn: "\r\n"))
        lines = lines.filter({ !$0.isEmpty })
        var ignoredIndexes: [Int] = []
        for (i, line) in lines.enumerated() {
            var items = line
                .split(separator: Character(separator), omittingEmptySubsequences: false)
                .map({ String($0) })
            if i == 0 {
                csv.columnNames = items.enumerated().compactMap({ (index, name) in
                    if name.isEmpty {
                        ignoredIndexes.append(index)
                        return nil
                    }
                    return ColumnName(value: name)
                })
            } else {
                items = items.enumerated().compactMap { (index, item) in
                    if ignoredIndexes.contains(index) {
                        return nil
                    }
                    let str: String
                    if let maxLength = maxLength, item.count > maxLength {
                        print("Too long value: \(item), it is shortened.")
                        str = String(item.prefix(maxLength)) + "..."
                    } else {
                        str = item
                    }
                    return str
                }
                let row = Row(
                    index: i,
                    values: items
                )
                csv.rows.append(row)
            }
        }
        return csv
    }

    /// Generate `Csv` from network url (like `HTTPS`).
    ///
    /// - Parameters:
    ///     - url: network url, commonly `HTTPS` schema.
    ///     - separator: Default separator in a row is `","`. You cloud change it by giving separator to `separator` parameter.
    public static func fromURL(_ url: URL, separator: String = ",") throws -> Csv {
        let data = try Data(contentsOf: url)
        guard let str = String(data: data, encoding: .utf8) else {
            throw Error.invalidDownloadResource(url: url.absoluteString, data: data)
        }
        return .fromString(str)
    }

    /// Generate `Csv` from local url (like `file://Users/...`).
    ///
    /// - Parameters:
    ///     - file: local url, commonly `file://` schema. Relative-path is not enable, please specify by absolute-path rule.
    ///     - separator: Default separator in a row is `","`. You cloud change it by giving separator to `separator` parameter.
    public static func fromFile(_ file: URL, separator: String = ",") throws -> Csv {
        // https://www.hackingwithswift.com/forums/swift/accessing-files-from-the-files-app/8203
        if file.startAccessingSecurityScopedResource() {
            let data = try Data(contentsOf: file)
            guard let str = String(data: data, encoding: .utf8) else {
                throw Error.invalidLocalResource(url: file.absoluteString, data: data)
            }
            return .fromString(str)
        } else {
            throw Error.cannotAccessFile(url: file.absoluteString)
        }
    }

    /**
     Generate CGImage
     - Parameters:
        - fontSize: Determine the fontsize of characters in output-table image.
     - Note:
     `fontSize` determines the size of output image and it can be as large as you want. Please consider the case that output image is too large to open image. Although output image becomes large, it is recommended to set fontSize amply enough (maybe larger than `12pt`) to see image clearly.
     - Returns: CGImage
     */
    public func cgImage(fontSize: CGFloat? = nil) -> CGImage {
        if let fontSize = fontSize {
            imageMarker.setFontSize(fontSize)
        }
        return imageMarker.make(csv: self)
    }

    /**
     Generate Data
     - Parameters:
        - fontSize: Determine the fontsize of characters in output-table image.
     - Note:
     `fontSize` determines the size of output image and it can be as large as you want. Please consider the case that output image is too large to open image. Although output image becomes large, it is recommended to set fontSize amply enough (maybe larger than `12pt`) to see image clearly.
     - Returns: `Optional<Data>`
     */
    public func pngData(fontSize: CGFloat? = nil) -> Data? {
        let image = cgImage(fontSize: fontSize)
        return image.convertToData()
    }

    /**
     - parameters:
        - to url: local file path where png-image will be saved.
     - Returns: If saving csv image to file, returns `true`. Otherwise, return `False`.
     */
    public func write(to url: URL) -> Bool {
        let data: Data? = pngData()
        guard let data = data else {
            return false
        }
        do {
            if !FileManager.default.fileExists(atPath: url.absoluteString) {
                FileManager.default.createFile(atPath: url.absoluteString, contents: data)
            } else {
                try data.write(to: url)
            }
            return true
        } catch {
            print(error)
            return false
        }
    }
}
