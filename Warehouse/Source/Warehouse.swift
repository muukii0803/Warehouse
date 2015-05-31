// Warehouse.swift
//
// Copyright (c) 2015 muukii
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

public class Warehouse {
    func WHLog<T>(value: T) {
        #if WAREHOUSE_DEBUG
            println(T)
        #endif
    }
    
    public enum DirectoryType {
        case Document
        case Cache
        case Temporary
        
        func Path() -> String {
            switch self {
            case .Document:
                return Warehouse.documentDirectoryPath()
            case .Cache:
                return Warehouse.cacheDirectoryPath()
            case .Temporary:
                return Warehouse.temporaryDirectoryPath()
            }
        }
    }
    
    public var fileManager = NSFileManager.defaultManager()
    public var directoryType: DirectoryType = .Temporary
    
    public var subDirectoryPath: String? {
        get {
            return _subDirectoryPath
        }
        set (path) {
            // "Test" -> "/Test"
            if var path = path {
                if path.hasPrefix("/") {
                } else {
                    path = "/" + path
                }
                
                if path.hasSuffix("/") {
                    path = path.substringToIndex(path.endIndex.predecessor())
                } else {
                    
                }
                _subDirectoryPath = path
            } else {
                _subDirectoryPath = ""
            }
        }
    }
    
    private var _subDirectoryPath: String?
        
    public convenience init(directoryType: DirectoryType, subDirectoryPath: String?) {
        self.init()
        self.directoryType = directoryType
		self.subDirectoryPath = subDirectoryPath
        self.createDirectoryIfNeeded()
    }
    
   public func createDirectoryIfNeeded() -> Bool{
        let directoryPath = self.saveDirectoryAbsolutePath()
        var error: NSError?
        if self.fileManager.createDirectoryAtPath(directoryPath, withIntermediateDirectories: true, attributes: nil, error: &error) {
            if error == nil {
                WHLog("Create Directory Success \(directoryPath)")
                return true
            } else {
                WHLog("Create Directory Failed \(directoryPath)")
                return false
            }
        } else {
            WHLog("Create Directory Failed \(directoryPath)")
            return false
        }
    }
    
    private func saveAndWait(#savePath: String, contents: NSData) -> Bool {
        
        if self.createDirectoryIfNeeded() {
            if self.fileManager.createFileAtPath(savePath, contents: contents, attributes: nil) {
                WHLog("File create success \(savePath)")
                return true
            } else {
                WHLog("File create failure \(savePath)")
                return false
            }
        } else {
            WHLog("Failed create directory")
            return false
        }
    }
    
    public func saveFile(#fileName: String,
        contents: NSData,
        success :((savedRelativePath: String?) -> Void)?,
        faiure:((error: NSError?) -> Void)?) {
            
        let subDirectoryPath = self.subDirectoryPath ?? ""
        let path = self.directoryType.Path() + "\(subDirectoryPath)/" + fileName
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), { () -> Void in
                
                let result: Bool = self.saveAndWait(savePath: path, contents: contents)
                if result {
                    
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        
                        let relativePath = Warehouse.translateAbsoluteToRelative(path)
                        success?(savedRelativePath: relativePath)
                    })
                } else {
                    
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        
                        faiure?(error: nil)
                        return
                    })
                }
            })
    }
    
    public func saveFileAndWait(#fileName: String?, contents: NSData?) -> String? {
        
        if let fileName = fileName, contents = contents {
            
            let path = self.saveDirectoryAbsolutePath() + fileName
            let result = self.saveAndWait(savePath: path, contents: contents)
            
            if result {
                
                let relativePath = Warehouse.translateAbsoluteToRelative(path)
                return relativePath
            } else {
                
                return nil
            }
        } else {
            return nil
        }
    }
    
    public func saveDirectoryAbsolutePath() -> String {
        
        let subDirectoryPath = self.subDirectoryPath ?? ""
        let absolutePath = self.directoryType.Path() + "\(subDirectoryPath)/"
        return absolutePath
    }
    
    // MARK: - Class Methos
    
    public class func openFile(#relativePath: String?) -> NSData? {
        
        if let path = relativePath {
            if let absolutePath = Warehouse.translateRelativeToAbsolute(path) {
                let data = NSData(contentsOfFile: absolutePath)
                return data
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    /**
    File Exists (directory is false)
    
    :param: relativePath
    
    :returns:
    */
    public class func fileExistsAtPath(#relativePath: String?) -> Bool {
        
        if let absolutePath = Warehouse.translateRelativeToAbsolute(relativePath) {
            
            var isDirectory: ObjCBool = false
            var results: Bool = false
            results = NSFileManager.defaultManager().fileExistsAtPath(absolutePath, isDirectory: &isDirectory)
            
            if results && !isDirectory {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    public class func homeDirectoryPath() -> String {
        return NSHomeDirectory()
    }
    
    public class func temporaryDirectoryPath() -> String{
        var path = NSTemporaryDirectory()
        if path.hasSuffix("/") {
            path = path.substringToIndex(path.endIndex.predecessor())
        }
        return path
    }
    
    public class func documentDirectoryPath() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        return paths.first as! String
    }
    
    public class func cacheDirectoryPath() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        return paths.first as! String
    }
    
    public class func translateAbsoluteToRelative(path :String?) -> String? {
        if let path = path {
            if path.hasPrefix(self.homeDirectoryPath()) {
                return path.stringByReplacingOccurrencesOfString(self.homeDirectoryPath(), withString: "", options: nil, range: nil)
            } else {
                return path
            }
        } else {
            return nil
        }
    }
    
    public class func translateRelativeToAbsolute(path :String?) -> String? {
        if let path = path {
            if path.hasPrefix(self.homeDirectoryPath()) {
                return path
            } else {
                return self.homeDirectoryPath().stringByAppendingPathComponent(path);
            }
        } else {
            return nil
        }
    }
}
