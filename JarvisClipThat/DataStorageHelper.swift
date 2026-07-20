import Foundation

enum DataStorageHelper {
    private static var folderURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = paths[0].appendingPathComponent("JarvisClipThat", isDirectory: true)
                
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        return appSupportURL
    }
    
    static func saveData<T: Encodable>(_ data: T, to fileName: String) {
        let fileURL = folderURL.appendingPathComponent(fileName)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let encodedData = try encoder.encode(data)
            try encodedData.write(to: fileURL, options: [.atomic])
        } catch {
            print("Save error: \(error.localizedDescription)")
        }
    }
    
    static func loadData<T: Decodable>(_ filename: String, as type: T.Type) -> T? {
        let fileURL = folderURL.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            print("Load error: \(error.localizedDescription)")
            return nil
        }
    }
}
