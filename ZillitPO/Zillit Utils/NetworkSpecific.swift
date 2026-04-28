//
//  FCURLRequest.swift

import Foundation
import UIKit
//import FirebaseAnalytics
//import AWSCore
import Network

public enum FCURLRequestType: String {
    case get     = "GET"
    case post    = "POST"
    case put     = "PUT"
    case head    = "HEAD"
    case patch   = "PATCH"
    case delete  = "DELETE"
    case options = "OPTIONS"
    case trace   = "TRACE"
}

// Reminder: We need moduledata change in FCURLSession - func getMediaFromURL(_ url: URL, moduleData : [String:Any] ,completion: @escaping (Data?, Error?) -> Void)

public class FCURLRequest {
    public var requestObject: URLRequest?
    public init(urlPath: String, type: FCURLRequestType, header: [String: String]? = nil, parameters: [String: String]? = nil, body: Any? = nil, otherProjectID: String, otherUserID: String) {
            
        var queryString = urlPath.range(of: "?") != nil ? "&" : "?"
        if let params = parameters {
            for (key, value) in params {
                queryString += key + "=" + value + "&"
           }
        }
        
        if let encodedString = queryString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            queryString = encodedString
        }
        if let url = URL(string: urlPath + queryString) {
            requestObject = URLRequest(url: url)
            let  deviceId = "\(Util.deviceId())"
            var paramData: [String:Any] = [:]
            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            var moduledata : String = ""
            
            paramData = ["user_id": otherUserID, "project_id": otherProjectID, "device_id": deviceId,"time_stamp":timestamp]
            if let jsonData = try? JSONSerialization.data(withJSONObject: paramData, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let encryptDescreption = SocketIOManager.default_.getEncryptedHeaderText(string: jsonString)
                moduledata = encryptDescreption
                self.requestObject?.setValue(encryptDescreption, forHTTPHeaderField: "moduledata")
            }
    
            var cookieValue = requestObject?.value(forHTTPHeaderField: "Cookie")
            cookieValue = cookieValue?.replacingOccurrences(of: ",", with: "")
            requestObject?.setValue(cookieValue, forHTTPHeaderField: "Cookie")
            self.requestObject?.httpMethod = type.rawValue
            self.requestObject?.setValue(Util.getAppVersion(), forHTTPHeaderField: "iosversion")
            self.requestObject?.setValue("application/json", forHTTPHeaderField: "Content-Type")
            self.requestObject?.setValue("application/json", forHTTPHeaderField: "Accept")
            self.requestObject?.setValue(Util.getDeviceInfo(), forHTTPHeaderField: "userAgent")
     
            if let header = header {
                for (key, value) in header {
                    self.requestObject?.setValue(value, forHTTPHeaderField: key)
                }
            }
            if self.requestObject?.value(forHTTPHeaderField: "Content-Type") == nil {
                self.requestObject?.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            if self.requestObject?.value(forHTTPHeaderField: "Accept") == nil {
                self.requestObject?.setValue("application/json", forHTTPHeaderField: "Accept")
            }
            var httpBodyPayload : String = ""
            if let body = body as? [String: Any] {
                self.requestObject?.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
            } else if let body = body as? String {
                self.requestObject?.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                self.requestObject?.httpBody = body.data(using: String.Encoding.utf8)
            } else if let body = body as? [[String:Any]] {
                self.requestObject?.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
            } else if let body = body as? Data {
                if let json = try? JSONSerialization.jsonObject(with: body, options: []) {
#if DEBUG
                    // Debug pre-serialization - (ONLY IN DEBUG MODE)
                    debugPrint("🔍 Normalized JSON Object: \(json)".trunc(3000))
                    //----------------------
#endif
                    if let normalizedData = try? JSONSerialization.data(
                        withJSONObject: json,
                        options: [.sortedKeys , .withoutEscapingSlashes]
                    ) {
                        let normalizedString = String(data: normalizedData, encoding: .utf8) ?? ""
#if DEBUG
                        // Debug pre-serialization - (ONLY IN DEBUG MODE)
                        debugPrint("📝 Serialized JSON String:\n\(normalizedString)".trunc(3000))
                        //----------------------
#endif
                        self.requestObject?.httpBody = normalizedData
                        httpBodyPayload = normalizedString
                    }
                }
            }

            let finalJSONString: String
            if httpBodyPayload.isEmpty {
                // Empty payload case: assign empty string as value
                finalJSONString = """
                {"payload":"","moduledata":"\(moduledata)"}
                """
            } else {
                // Non-empty payload case: include actual payload
                finalJSONString = """
                {"payload":\(httpBodyPayload),"moduledata":"\(moduledata)"}
                """
            }

            // Generate SHA256 hash with salt
            let combinedHash = Util.generateSHA256WithSalt(requestBody: finalJSONString)
            // Set the hash in the request header
            self.requestObject?.setValue(combinedHash, forHTTPHeaderField: "bodyhash")
            self.requestObject?.timeoutInterval = 60

        }
    }
    
    public init(urlPath: String, type: FCURLRequestType, header: [String: String]? = nil, parameters: [String: String]? = nil, body: Any? = nil, projectID:String? = nil, userID:String? = nil, scanDeviceID:String? = nil) {
        
        var queryString = urlPath.range(of: "?") != nil ? "&" : "?"
        if let params = parameters {
            for (key, value) in params {
                queryString += key + "=" + value + "&"
           }
        }
        
        if let encodedString = queryString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            queryString = encodedString
        }
        if let url = URL(string: urlPath + queryString) {
            requestObject = URLRequest(url: url)
           
            let deviceId = "\(Util.deviceId())"
            var scanDeviceId = ""
            var userId = ""
            var projectId = ""
            var paramData: [String:Any] = [:]
            var moduledata : String = ""
            
            if let scanDeviceID = scanDeviceID, !scanDeviceID.isEmpty{
                scanDeviceId = "\(scanDeviceID)"
                let timestamp = Int(Date().timeIntervalSince1970 * 1000)
                paramData = ["device_id": deviceId,"scanner_device_id":scanDeviceId,"time_stamp":timestamp]
            } else {
                if(projectID == "notMandatory"){
                    let timestamp = Int(Date().timeIntervalSince1970 * 1000)

                     paramData = ["device_id": deviceId,"time_stamp":timestamp]
                }
                else if(projectID != "notMandatory" && userID == "notMandatory"){
                    if let storedProjectID = UserDefaults.standard.string(forKey: "zillitprojectId") {
                        projectId = "\(storedProjectID)"
                    }
                    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
                     paramData = ["project_id":projectId,"device_id": deviceId,"time_stamp":timestamp]
                }else{
                    if let storedUserID = UserDefaults.standard.string(forKey: "zillitprojectuserId") {
                        userId = "\(storedUserID)"
                    }
                   
                    if let storedProjectID = UserDefaults.standard.string(forKey: "zillitprojectId") {
                        projectId = "\(storedProjectID)"
                    }
                    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
                     paramData = ["user_id": userId,"project_id":projectId,"device_id": deviceId,"time_stamp":timestamp]
                }
            }
            if let jsonData = try? JSONSerialization.data(withJSONObject: paramData, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let encryptDescreption = SocketIOManager.default_.getEncryptedHeaderText(string: jsonString)
                self.requestObject?.setValue(encryptDescreption, forHTTPHeaderField: "moduledata")
                moduledata = encryptDescreption
            }
    
            var cookieValue = requestObject?.value(forHTTPHeaderField: "Cookie")
            cookieValue = cookieValue?.replacingOccurrences(of: ",", with: "")
            requestObject?.setValue(cookieValue, forHTTPHeaderField: "Cookie")
            self.requestObject?.httpMethod = type.rawValue
            self.requestObject?.setValue(Util.getAppVersion(), forHTTPHeaderField: "iosversion")
            self.requestObject?.setValue(Util.getAppVersion(), forHTTPHeaderField: "osversion")
            self.requestObject?.setValue(Util.getCurrentDeviceType(), forHTTPHeaderField: "device-type")
            self.requestObject?.setValue("application/json", forHTTPHeaderField: "Content-Type")
            self.requestObject?.setValue("application/json", forHTTPHeaderField: "Accept")
            self.requestObject?.setValue(Util.getDeviceInfo(), forHTTPHeaderField: "user-agent")
            self.requestObject?.setValue("\(Reachability.getNetworkType())", forHTTPHeaderField: "network")
            if let header = header {
                for (key, value) in header {
                    self.requestObject?.setValue(value, forHTTPHeaderField: key)
                }
            }
            if self.requestObject?.value(forHTTPHeaderField: "Content-Type") == nil {
                self.requestObject?.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            if self.requestObject?.value(forHTTPHeaderField: "Accept") == nil {
                self.requestObject?.setValue("application/json", forHTTPHeaderField: "Accept")
            }
            

            // --- Inside your request setup logic ---
            var httpBodyPayload : String = ""
            if let body = body as? [String: Any] {
                let sorted = recursivelySortedDictionary(body)
                self.requestObject?.httpBody = try? JSONSerialization.data(withJSONObject: sorted, options: [])
            } else if let body = body as? String {
                self.requestObject?.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                self.requestObject?.httpBody = body.data(using: .utf8)
            } else if let body = body as? [[String: Any]] {
                let sortedArray = body.map { recursivelySortedDictionary($0) }
                self.requestObject?.httpBody = try? JSONSerialization.data(withJSONObject: sortedArray, options: [])
            } else if let body = body as? Data {
                if let json = try? JSONSerialization.jsonObject(with: body, options: []) {
#if DEBUG
                    // Debug pre-serialization - (ONLY IN DEBUG MODE)
                    debugPrint("🔍 Normalized JSON Object: \(json)".trunc(3000))
                    //----------------------
#endif
                    if let normalizedData = try? JSONSerialization.data(
                        withJSONObject: json,
                        options: [.sortedKeys , .withoutEscapingSlashes]
                    ) {
                        let normalizedString = String(data: normalizedData, encoding: .utf8) ?? ""
#if DEBUG
                        // Debug pre-serialization - (ONLY IN DEBUG MODE)
                        debugPrint("📝 Serialized JSON String:\n\(normalizedString)".trunc(3000))
                        //----------------------
#endif
                        self.requestObject?.httpBody = normalizedData
                        httpBodyPayload = normalizedString
                    }
                }
            }

            let finalJSONString: String
            if httpBodyPayload.isEmpty {
                // Empty payload case: assign empty string as value
                finalJSONString = """
                {"payload":"","moduledata":"\(moduledata)"}
                """
            } else {
                // Non-empty payload case: include actual payload
                finalJSONString = """
                {"payload":\(httpBodyPayload),"moduledata":"\(moduledata)"}
                """
            }

            // Generate SHA256 hash with salt
            let combinedHash = Util.generateSHA256WithSalt(requestBody: finalJSONString)
            // Set the hash in the request header
            self.requestObject?.setValue(combinedHash, forHTTPHeaderField: "bodyhash")
            self.requestObject?.timeoutInterval = 60
        }
    }
}


func recursivelySortedDictionary(_ dict: [String: Any]) -> [String: Any] {
    var sortedDict = [String: Any]()

    for key in dict.keys.sorted() {
        if let subDict = dict[key] as? [String: Any] {
            sortedDict[key] = recursivelySortedDictionary(subDict)
        } else if let subArray = dict[key] as? [Any] {
            sortedDict[key] = subArray.map { element -> Any in
                if let itemDict = element as? [String: Any] {
                    return recursivelySortedDictionary(itemDict)
                }
                return element
            }
        } else {
            sortedDict[key] = dict[key]
        }
    }

    return sortedDict
}



struct MultipartBoxFormDataRequest {
    private let boundary: String = UUID().uuidString
    var httpBody = NSMutableData()
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func addTextField(named name: String, value: String) {
        httpBody.appendString(textFormField(named: name, value: value))
    }
    
    private func textFormField(named name: String, value: String) -> String {
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        fieldString += "Content-Type: text/plain; charset=ISO-8859-1\r\n"
        fieldString += "Content-Transfer-Encoding: 8bit\r\n"
        fieldString += "\r\n"
        fieldString += "\(value)\r\n"
        
        return fieldString
    }
    
    
    func addDataField(fieldName:String, data: Data, mimeType: String) {
        httpBody.append(dataFormField(fieldName:fieldName,data: data, mimeType: mimeType))
    }
    
    private func dataFormField(fieldName:String,
                               data: Data,
                               mimeType: String) -> Data {
        let fieldData = NSMutableData()
        
        fieldData.appendString("--\(boundary)\r\n")
        let  fileName = "\(Date().timeIntervalSince1970).jpeg"
        fieldData.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        fieldData.appendString("Content-Type: \(mimeType)\r\n")
        fieldData.appendString("\r\n")
        fieldData.append(data)
        fieldData.appendString("\r\n")
        return fieldData as Data
    }
    
    func asURLRequest(_ folderId:String,_ enterPrizeId:String) -> URLRequest {
        var httpBodyPayload : String = ""
        var moduledata : String = ""
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==", forHTTPHeaderField: "Authorization")
        request.setValue(Util.getAppVersion(), forHTTPHeaderField: "appVersion")
        request.setValue(Util.getAppVersion(), forHTTPHeaderField: "iosversion")
        request.setValue(Util.getDeviceName(), forHTTPHeaderField: "devicename")
        request.setValue(Util.getDeviceInfo(), forHTTPHeaderField: "deviceinfo")
        request.setValue(Util.getDeviceType(), forHTTPHeaderField: "requesttype")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Util.getDeviceName(), forHTTPHeaderField: "userAgent")
        request.setValue("\(Reachability.getNetworkType())", forHTTPHeaderField: "network")
        
        let deviceId = "\(Util.deviceId())"
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let paramData: [String:Any] = ["device_id": deviceId,"folder_id" :folderId ,"enterprise_client_id" : enterPrizeId,"time_stamp":timestamp]
        if let jsonData = try? JSONSerialization.data(withJSONObject: paramData, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let encryptDescreption = SocketIOManager.default_.getEncryptedHeaderText(string: jsonString)
            request.setValue(encryptDescreption, forHTTPHeaderField: "moduledata")
            moduledata = encryptDescreption
            //            debugPrint("decrypt Data value: \(SocketIOManager.default_.getDecriptionheaderText(string: encryptDescreption))")
        }
        httpBody.appendString("--\(boundary)--")
        request.httpBody = httpBody as Data
        if let stringBody = String(data: httpBody as Data, encoding: .utf8) {
            httpBodyPayload = stringBody
        }
        debugPrint("httpBodyPayload value : \(httpBodyPayload)")
        let finalJSONString: String
        if httpBodyPayload.isEmpty {
            // Empty payload case: assign empty string as value
            finalJSONString = """
                 {"payload":"","moduledata":"\(moduledata)"}
                 """
        } else {
            // Non-empty payload case: include actual payload
            finalJSONString = """
                 {"payload":\(httpBodyPayload),"moduledata":"\(moduledata)"}
                 """
        }
        
        // Generate SHA256 hash with salt
        let combinedHash = Util.generateSHA256WithSalt(requestBody: finalJSONString)
        // Set the hash in the request header
        request.setValue(combinedHash, forHTTPHeaderField: "bodyhash")
        //#if DEBUG
        //        let reqString = "\n------------------------------\n URL     :  \(url.absoluteString) \nHeader       :  \(request.allHTTPHeaderFields ?? [:])  \nBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \n------------------------------\n"
        //        debugPrint(reqString)
        //#endif
        return request
    }
    
}

struct MultipartFormDataRequest {
    private let boundary: String = UUID().uuidString
    var httpBody = NSMutableData()
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func addTextField(named name: String, value: String) {
        httpBody.appendString(textFormField(named: name, value: value))
    }
    
    private func textFormField(named name: String, value: String) -> String {
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        fieldString += "Content-Type: text/plain; charset=ISO-8859-1\r\n"
        fieldString += "Content-Transfer-Encoding: 8bit\r\n"
        fieldString += "\r\n"
        fieldString += "\(value)\r\n"
        return fieldString
    }
    
    
    func addDataField(fieldName: String, fileName: String, data: Data, mimeType: String) {
        httpBody.append(dataFormField(fieldName: fieldName,fileName:fileName,data: data, mimeType: mimeType))
    }
    
    private func dataFormField(fieldName: String,
                               fileName: String,
                               data: Data,
                               mimeType: String) -> Data {
        let fieldData = NSMutableData()
        fieldData.appendString("--\(boundary)\r\n")
        fieldData.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        fieldData.appendString("Content-Type: \(mimeType)\r\n")
        fieldData.appendString("\r\n")
        fieldData.append(data)
        fieldData.appendString("\r\n")
        return fieldData as Data
    }
    
    func asURLRequest(mediaKey : String) -> URLRequest {
        var httpBodyPayload : String = ""
        var moduledata : String = ""
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==", forHTTPHeaderField: "Authorization")
        request.setValue(Util.getAppVersion(), forHTTPHeaderField: "appVersion")
        request.setValue(Util.getAppVersion(), forHTTPHeaderField: "iosversion")
        request.setValue(Util.getDeviceName(), forHTTPHeaderField: "devicename")
        request.setValue(Util.getDeviceInfo(), forHTTPHeaderField: "deviceinfo")
        request.setValue(Util.getDeviceType(), forHTTPHeaderField: "requesttype")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Util.getDeviceName(), forHTTPHeaderField: "userAgent")
        request.setValue("\(Reachability.getNetworkType())", forHTTPHeaderField: "network")
        
        
        let bucket = (appUserDefault.getDynamicRegionData()?.upload_bucket ?? "")
        let region = (appUserDefault.getDynamicRegionData()?.aws_region ?? "")
        let deviceId = "\(Util.deviceId())"
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        
        let paramData: [String:Any] = ["device_id": deviceId , "key": mediaKey,"bucket": bucket,"region" : region,"time_stamp":timestamp]
        if let jsonData = try? JSONSerialization.data(withJSONObject: paramData, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let encryptDescreption = SocketIOManager.default_.getEncryptedHeaderText(string: jsonString)
            request.setValue(encryptDescreption, forHTTPHeaderField: "moduledata")
            moduledata = encryptDescreption
            //            debugPrint("decrypt Data value: \(SocketIOManager.default_.getDecriptionheaderText(string: encryptDescreption))")
        }
        httpBody.appendString("--\(boundary)--")
        request.httpBody = httpBody as Data
        if let stringBody = String(data: httpBody as Data, encoding: .utf8) {
            httpBodyPayload = stringBody
        }
        debugPrint("httpBodyPayload value : \(httpBodyPayload)")
        let finalJSONString: String
        if httpBodyPayload.isEmpty {
            // Empty payload case: assign empty string as value
            finalJSONString = """
                 {"payload":"","moduledata":"\(moduledata)"}
                 """
        } else {
            // Non-empty payload case: include actual payload
            finalJSONString = """
                 {"payload":\(httpBodyPayload),"moduledata":"\(moduledata)"}
                 """
        }
        
        // Generate SHA256 hash with salt
        let combinedHash = Util.generateSHA256WithSalt(requestBody: finalJSONString)
        // Set the hash in the request header
        request.setValue(combinedHash, forHTTPHeaderField: "bodyhash")
        //#if DEBUG
        //        let reqString = "\n------------------------------\n URL     :  \(url.absoluteString) \nHeader       :  \(request.allHTTPHeaderFields ?? [:])  \nBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \n------------------------------\n"
        //        debugPrint(reqString)
        //#endif
        return request
    }
    
}

extension NSMutableData {
    func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}



//========================================================================================================================================================

public class FCURLSession: NSObject {

    public static let sharedInstance = FCURLSession()
    public var session: URLSession?
    public var bgSession: URLSession?
    weak var delegate: URLSessionDelegate!

    fileprivate override init() {
        super.init()
        initSession()
     }
  
   private func initSession(){
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 5
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 60
        sessionConfig.timeoutIntervalForResource = 60
        let bgsessionConfig = URLSessionConfiguration.background(withIdentifier: "com.zillit.network.bgSession")
        bgsessionConfig.timeoutIntervalForRequest = 60
        bgsessionConfig.timeoutIntervalForResource = 60
        session = Foundation.URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: queue)
        bgSession = Foundation.URLSession(configuration: bgsessionConfig, delegate: self, delegateQueue: queue)
    }
    
     public func cancelAllTasks() {
        session?.getAllTasks { tasks in
            tasks.forEach { task in
                task.cancel() // Cancel the task
            }
        }
        bgSession?.getAllTasks { tasks in
            tasks.forEach { task in
                task.cancel() // Cancel the task
            }
        }
        initSession()
      }
    
   }

extension FCURLSession: URLSessionDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error == nil {
            task.resume()
        }
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        debugPrint("urlSessionDidFinishEvents")
    }

}

extension URLSession {
    
    public func codableResultTask(with request: URLRequest) -> URLSessionDataTask {
        return self.dataTask(with: request)
    }
    
    
    
    public func codableResultTaskInDict(with request: URLRequest, completion: ((Result<[String: Any]?, Error>) -> Void)? = nil) -> URLSessionDataTask {
        
        return self.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error as NSError?, error.code == NSURLErrorCancelled {
                    debugPrint("NSURLErrorCancelled called from project switch page.")
                    return
                }
                if let error = error as? HTTPURLResponse, error.statusCode == URLError.Code.notConnectedToInternet.rawValue {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(error.statusCode)")
                    completion?(.failure(FCCustomError(message:LOCSTRINGS.InternetConnectionPopUp.localized())))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 400 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_400_ERROR )"
                        
                        var TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        if let messageElements = responseModel.messageElements,
                           !messageElements.isEmpty {
                            TranslatedMessage = self.convertSearchReplacer(_message: TranslatedMessage, _messageElements: messageElements)
                        }
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            return
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_400_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                
                else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
#if DEBUG
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "") \n------------------------------\n"
                    debugPrint(reqString.trunc(3000))
#endif
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    
                    if ServerRequest.IF_DEBUG == true  {
                        let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_401_ERROR
                        completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                        return
                    }
                    else {
                        completion?(.failure(error ?? FCCustomError(message:"")))
                        return
                    }
                }
                
                else   if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: nil )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (responseModel.message ?? CONSTANTS.SERVER_404_ERROR)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: "")))
                            return
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_404_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                else  if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 406 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return}
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: nil )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (responseModel.message ?? CONSTANTS.SERVER_406_ERROR)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: responseModel.message ??  CONSTANTS.SERVER_406_ERROR)))
                            return
                        }
                        
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_406_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                
                else  if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 502 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
#if DEBUG
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "") \n------------------------------\n"
                    debugPrint(reqString.trunc(3000))
#endif
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    if ServerRequest.IF_DEBUG == true  {
                        let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_502_ERROR
                        completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                        return
                    }
                    else {
                        let apiUrl = request.url?.absoluteString ?? ""
                        if apiUrl.contains("https://notificationapi.zillit.com/api/v2/project/unread") || apiUrl.contains("https://notificationapi.zillit.com/api/v2/device/unread") || apiUrl.contains("https://locationapi.zillit.com/api/v2/location/log")  {
                            completion?(.failure(error ?? FCCustomError(message: "")))
                            return
                        }else{
                            let errorMessage = CONSTANTS.SERVER_502_ERROR
                            completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                            return
                        }
                    }
                }
                
                else   if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 422 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_404_ERROR )"
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            return
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_404_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                
                else   if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 1051 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)   \(String(describing: String(data: data, encoding: .utf8)))")
                    
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    completion?(.failure(FCCustomError(message:"")))
                    return
                    //                    completion?(.failure(error ?? FCCustomError(message:error?.localizedDescription ??  "Something went wrong ")))
                    //                    if ServerRequest.IF_DEBUG == true  {
                    //                        let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + "Something went wrong"
                    //                        completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                    //                        return
                    //                    }
                    //                    else {
                    //                        completion?(.failure(error ?? FCCustomError(message:"")))
                    //                        return
                    //                    }
                }
                guard let data = data, error == nil else {
#if DEBUG
                    if let httpResponse = response as? HTTPURLResponse {
                        debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    }
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "") \n------------------------------\n"
                    debugPrint(reqString.trunc(3000))
#endif
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: response as? HTTPURLResponse ,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    completion?(.failure(FCCustomError(message:"")))
                    return
                }
                
#if DEBUG
                let reqString = "\n-------------FCURLSESSION6-----------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Data         : \((String(data: data, encoding: .utf8) ?? "").trunc(3000)) ....... \n------------------------------\n"
                if let httpResponse = response as? HTTPURLResponse{
                    debugPrint("FCURLSESSION6 -- APIResponseStatusCode -- \(httpResponse.statusCode)")
                }
                debugPrint(reqString.trunc(3000))
#endif
                do {
                    let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                    
                    let TranslatedMessage = "\(responseModel.message ?? "")"
                    AnalyticsManager.logApiSuccess(request: request,
                                                   error: error ,
                                                   translatedMessage: TranslatedMessage )
                    
                    let sucessModel = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    completion?(.success(sucessModel))
                    
                } catch {
                    completion?(.success(nil))
                    debugPrint("Parsing Error", error)
                }
            }
        }
    }
    
    public func codableResultTask<T: Decodable>(with request: URLRequest, completion: ((Result<T?, Error>) -> Void)? = nil) -> URLSessionDataTask {
        
        return self.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error as NSError?, error.code == NSURLErrorCancelled {
                    debugPrint("NSURLErrorCancelled called from project switch page.")
                    return
                }
                if let error = error as? HTTPURLResponse, error.statusCode == URLError.Code.notConnectedToInternet.rawValue {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(error.statusCode)")
                    completion?(.failure(FCCustomError(message:LOCSTRINGS.InternetConnectionPopUp.localized())))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 400 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_400_ERROR )"
                        var TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        if let messageElements = responseModel.messageElements,
                           !messageElements.isEmpty {
                            TranslatedMessage = self.convertSearchReplacer(_message: TranslatedMessage, _messageElements: messageElements)
                        }
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: response as? HTTPURLResponse ,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            return
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_400_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                
                else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
#if DEBUG
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "") \n------------------------------\n"
                    debugPrint(reqString.trunc(3000))
#endif
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    if ServerRequest.IF_DEBUG == true  {
                        let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_401_ERROR
                        completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                        if(appUserDefault.getAppOpenScreen() != .registartion && appUserDefault.getAppOpenScreen() != .intro){
                            Util.logOutUser()
                            
                        }//   // resetUser on 401 ERROR
                        return
                    }
                    else {
                        completion?(.failure(error ?? FCCustomError(message:"")))
                        if(appUserDefault.getAppOpenScreen() != .registartion && appUserDefault.getAppOpenScreen() != .intro){
                            Util.logOutUser()
                        }// resetUser on 401 ERROR
                        return
                    }
                }
                
                else  if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return}
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_403_ERROR )"
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if let url = request.url?.absoluteString,url.contains(CONSTANTS.ChatGPTURL) {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                        }else{
                            if ServerRequest.IF_DEBUG == true  {
                                let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                                completion?(.failure(FCCustomError(message: errorMessage)))
                                if(appUserDefault.getAppOpenScreen() != .allProjects && appUserDefault.getAppOpenScreen() != .allProjects){
                                    Util.redirectAllProjectScreen()
                                }
                                return
                            }
                            else {
                                if(appUserDefault.getAppOpenScreen() != .allProjects && appUserDefault.getAppOpenScreen() != .allProjects){
                                    Util.redirectAllProjectScreen()
                                }
                                completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                                return
                            }
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_406_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            if(appUserDefault.getAppOpenScreen() != .allProjects && appUserDefault.getAppOpenScreen() != .allProjects){
                                Util.redirectAllProjectScreen()
                            }
                            return
                        }
                        else {
                            completion?(.failure(error))
                            if(appUserDefault.getAppOpenScreen() != .allProjects && appUserDefault.getAppOpenScreen() != .allProjects){
                                Util.redirectAllProjectScreen()
                            }
                            return
                        }
                        
                    }
                }
                
                else   if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_404_ERROR )"
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            return
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_404_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                else  if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 406 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return}
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_406_ERROR )"
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            return
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_406_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                
                else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 500 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    var errorMessage = (error?.localizedDescription ?? "")
#if DEBUG
                    if let data = data {
                        do {
                            let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                            errorMessage = "\(responseModel.message ?? CONSTANTS.SERVER_500_ERROR )"
                        } catch {
                            debugPrint("Parsing Error", error)
                        }
                    }
                    
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(errorMessage) \n------------------------------\n"
                    debugPrint(reqString.trunc(3000))
#endif
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    if ServerRequest.IF_DEBUG == true  {
                        let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_500_ERROR
                        completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                        return
                    }
                    else {
                        let apiUrl = request.url?.absoluteString ?? ""
                        if apiUrl.contains("https://notificationapi.zillit.com/api/v2/project/unread") || apiUrl.contains("https://notificationapi.zillit.com/api/v2/device/unread") || apiUrl.contains("https://locationapi.zillit.com/api/v2/location/log") {
                            completion?(.failure(error ?? FCCustomError(message: "")))
                            return
                        }else{
                            let errorMessage = CONSTANTS.SERVER_500_ERROR
                            completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                            return
                        }
                    }
                }
                
                
                else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 502 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    var errorMessage = (error?.localizedDescription ?? "")
#if DEBUG
                    if let data = data {
                        do {
                            let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                            errorMessage = "\(responseModel.message ?? CONSTANTS.SERVER_502_ERROR )"
                        } catch {
                            debugPrint("Parsing Error", error)
                        }
                    }
                    
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(errorMessage) \n------------------------------\n"
                    debugPrint(reqString.trunc(3000))
#endif
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    if ServerRequest.IF_DEBUG == true  {
                        let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_502_ERROR
                        completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                        return
                    }
                    else {
                        let apiUrl = request.url?.absoluteString ?? ""
                        if apiUrl.contains("https://notificationapi.zillit.com/api/v2/project/unread") || apiUrl.contains("https://notificationapi.zillit.com/api/v2/device/unread") || apiUrl.contains("https://locationapi.zillit.com/api/v2/location/log")  {
                            completion?(.failure(error ?? FCCustomError(message: "")))
                            return
                        }else{
                            let errorMessage = CONSTANTS.SERVER_502_ERROR
                            completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                            return
                        }
                    }
                }
                else   if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 422 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_404_ERROR )"
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            return
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_404_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                
                else   if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 1051 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)   \(String(describing: String(data: data, encoding: .utf8)))")
                    
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    completion?(.failure(FCCustomError(message:"")))
                    return
                }
                guard let data = data, error == nil else {
#if DEBUG
                    if let httpResponse = response as? HTTPURLResponse {
                        debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    }
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "") \n------------------------------\n"
                    debugPrint(reqString.trunc(3000))
#endif
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: response as? HTTPURLResponse ,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    completion?(.failure(FCCustomError(message:"")))
                    return
                }
                
#if DEBUG
                let reqString = "\n-------------FCURLSESSION6-----------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Data         : \((String(data: data, encoding: .utf8) ?? "").trunc(3000)) ....... \n------------------------------\n"
                if let httpResponse = response as? HTTPURLResponse{
                    debugPrint("FCURLSESSION6 -- APIResponseStatusCode -- \(httpResponse.statusCode)")
                }
                debugPrint(reqString.trunc(3000))
#endif
                do {
                    let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                    
                    let responseMessage = "\(responseModel.message ?? "Something went wrong")"
                    let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                    
                    AnalyticsManager.logApiSuccess(request: request,
                                                   error: error ,
                                                   translatedMessage: TranslatedMessage )
                    
                    let sucessModel = try JSONDecoder().decode(T.self, from: data)
                    completion?(.success(sucessModel))
                    
                } catch {
                    completion?(.success(nil))
                    debugPrint("Parsing Error", error)
                }
            }
        }
    }

    public func codableMultipartResultTask(with request: URLRequest,
                                           completion: ((Result<Data?, Error>) -> Void)? = nil) -> URLSessionDataTask {
        
        return self.dataTask(with: request) { data, response, error in
            
            DispatchQueue.main.async {
                
                if let error = error as NSError?, error.code == NSURLErrorCancelled {
                    
                    debugPrint("NSURLErrorCancelled called from project switch page.")
                    
                    return
                    
                }
                
                if let error = error as? HTTPURLResponse, error.statusCode == URLError.Code.notConnectedToInternet.rawValue {
                    
                    debugPrint("codableResultTask:: APIResponseStatusCode \(error.statusCode)")
                    
                    completion?(.failure(FCCustomError(message:LOCSTRINGS.InternetConnectionPopUp.localized())))
                    
                    return
                    
                }
                
                
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 400 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_400_ERROR )"
                        
                        var TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        if let messageElements = responseModel.messageElements,
                           !messageElements.isEmpty {
                            TranslatedMessage = self.convertSearchReplacer(_message: TranslatedMessage, _messageElements: messageElements)
                        }
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            return
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_400_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                
                
                else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    
#if DEBUG
                    
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "") \n------------------------------\n"
                    
                    debugPrint(reqString.trunc(3000))
                    
#endif
                    
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    
                    
                    if ServerRequest.IF_DEBUG == true  {
                        
                        let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_401_ERROR
                        
                        completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                        
                        if(appUserDefault.getAppOpenScreen() != .registartion && appUserDefault.getAppOpenScreen() != .intro){
                            
                            Util.logOutUser()
                            
                            
                            
                        }//   // resetUser on 401 ERROR
                        
                        return
                        
                    }
                    
                    else {
                        
                        completion?(.failure(error ?? FCCustomError(message:"")))
                        
                        if(appUserDefault.getAppOpenScreen() != .registartion && appUserDefault.getAppOpenScreen() != .intro){
                            
                            Util.logOutUser()
                            
                        }// resetUser on 401 ERROR
                        
                        return
                        
                    }
                    
                }
                
                
                
                else  if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
                    
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    
                    guard let data = data, error == nil else {
                        
                        return}
                    
                    do {
                        
                        
                        
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_403_ERROR )"
                        
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
                        
                        
#if DEBUG
                        
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        
                        debugPrint(reqString.trunc(3000))
                        
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if let url = request.url?.absoluteString,url.contains(CONSTANTS.ChatGPTURL) {
                            
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            
                        }else{
                            
                            if ServerRequest.IF_DEBUG == true  {
                                
                                let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                                
                                completion?(.failure(FCCustomError(message: errorMessage)))
                                
                                if(appUserDefault.getAppOpenScreen() != .allProjects && appUserDefault.getAppOpenScreen() != .allProjects){
                                    
                                    Util.redirectAllProjectScreen()
                                    
                                }
                                
                                return
                                
                            }
                            
                            else {
                                
                                if(appUserDefault.getAppOpenScreen() != .allProjects && appUserDefault.getAppOpenScreen() != .allProjects){
                                    
                                    Util.redirectAllProjectScreen()
                                    
                                }
                                
                                completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                                
                                return
                                
                            }
                            
                        }
                        
                        
                        
                    } catch {
                        
                        
                        
                        if ServerRequest.IF_DEBUG == true  {
                            
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_406_ERROR
                            
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            
                            debugPrint("Parsing Error", error)
                            
                            if(appUserDefault.getAppOpenScreen() != .allProjects && appUserDefault.getAppOpenScreen() != .allProjects){
                                
                                Util.redirectAllProjectScreen()
                                
                            }
                            
                            return
                            
                        }
                        
                        else {
                            
                            completion?(.failure(error))
                            
                            if(appUserDefault.getAppOpenScreen() != .allProjects && appUserDefault.getAppOpenScreen() != .allProjects){
                                
                                Util.redirectAllProjectScreen()
                                
                            }
                            
                            return
                            
                        }
                        
                        
                        
                    }
                    
                }
                
                
                
                else   if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    
                    guard let data = data, error == nil else {
                        
                        return
                        
                    }
                    
                    do {
                        
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_404_ERROR )"
                        
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
                        
                        
#if DEBUG
                        
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        
                        debugPrint(reqString.trunc(3000))
                        
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            
                            return
                            
                        }
                        
                        else {
                            
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            
                            return
                            
                        }
                        
                        
                        
                    } catch {
                        
                        
                        
                        if ServerRequest.IF_DEBUG == true  {
                            
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_404_ERROR
                            
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            
                            debugPrint("Parsing Error", error)
                            
                            return
                            
                        }
                        
                        else {
                            
                            completion?(.failure(error))
                            
                            return
                            
                        }
                        
                        
                        
                    }
                    
                }
                
                else  if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 406 {
                    
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    
                    guard let data = data, error == nil else {
                        
                        return}
                    
                    do {
                        
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_406_ERROR )"
                        
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
                        
                        
#if DEBUG
                        
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        
                        debugPrint(reqString.trunc(3000))
                        
#endif
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            
                            return
                            
                        }
                        
                        else {
                            
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            
                            return
                            
                        }
                        
                        
                        
                    } catch {
                        
                        
                        
                        if ServerRequest.IF_DEBUG == true  {
                            
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_406_ERROR
                            
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            
                            debugPrint("Parsing Error", error)
                            
                            return
                            
                        }
                        
                        else {
                            
                            completion?(.failure(error))
                            
                            return
                            
                        }
                        
                        
                        
                    }
                    
                }
                
                
                
                else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 500 {
                    
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    
                    var errorMessage = (error?.localizedDescription ?? "")
                    
#if DEBUG
                    
                    if let data = data {
                        
                        do {
                            
                            let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                            
                            errorMessage = "\(responseModel.message ?? CONSTANTS.SERVER_500_ERROR )"
                            
                        } catch {
                            
                            debugPrint("Parsing Error", error)
                            
                        }
                        
                    }
                    
                    
                    
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(errorMessage) \n------------------------------\n"
                    
                    debugPrint(reqString.trunc(3000))
                    
#endif
                    
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    
                    
                    if ServerRequest.IF_DEBUG == true  {
                        
                        let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_500_ERROR
                        
                        completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                        
                        return
                        
                    }
                    
                    else {
                        
                        let apiUrl = request.url?.absoluteString ?? ""
                        if apiUrl.contains("https://notificationapi.zillit.com/api/v2/project/unread") || apiUrl.contains("https://notificationapi.zillit.com/api/v2/device/unread") || apiUrl.contains("https://locationapi.zillit.com/api/v2/location/log")  {
                            completion?(.failure(error ?? FCCustomError(message: "")))
                            return
                        }else{
                            let errorMessage = CONSTANTS.SERVER_500_ERROR
                            completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                            return
                        }
                        
                        
                        
                    }
                    
                }
                
                
                else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 502 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    var errorMessage = (error?.localizedDescription ?? "")
#if DEBUG
                    if let data = data {
                        do {
                            let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                            errorMessage = "\(responseModel.message ?? CONSTANTS.SERVER_502_ERROR )"
                        } catch {
                            debugPrint("Parsing Error", error)
                        }
                    }
                    
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(errorMessage) \n------------------------------\n"
                    debugPrint(reqString.trunc(3000))
#endif
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    if ServerRequest.IF_DEBUG == true  {
                        let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_502_ERROR
                        completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                        return
                    }
                    else {
                        let apiUrl = request.url?.absoluteString ?? ""
                        if apiUrl.contains("https://notificationapi.zillit.com/api/v2/project/unread") || apiUrl.contains("https://notificationapi.zillit.com/api/v2/device/unread") || apiUrl.contains("https://locationapi.zillit.com/api/v2/location/log")  {
                            completion?(.failure(error ?? FCCustomError(message: "")))
                            return
                        }else{
                            let errorMessage = CONSTANTS.SERVER_502_ERROR
                            completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                            return
                        }
                    }
                }
                
                else   if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 422 {
                    
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    
                    guard let data = data, error == nil else {
                        
                        return
                        
                    }
                    
                    do {
                        
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_404_ERROR )"
                        
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
                        
                        
#if DEBUG
                        
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        
                        debugPrint(reqString.trunc(3000))
                        
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        
                        
                        if ServerRequest.IF_DEBUG == true  {
                            
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            
                            return
                            
                        }
                        
                        else {
                            
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            
                            return
                            
                        }
                        
                        
                        
                    } catch {
                        
                        
                        
                        if ServerRequest.IF_DEBUG == true  {
                            
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_404_ERROR
                            
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            
                            debugPrint("Parsing Error", error)
                            
                            return
                            
                        }
                        
                        else {
                            
                            completion?(.failure(error))
                            
                            return
                            
                        }
                        
                        
                        
                    }
                    
                }
                
                
                
                else   if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 1051 {
                    
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    
                    guard let data = data, error == nil else {
                        
                        return
                        
                    }
                    
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)   \(String(describing: String(data: data, encoding: .utf8)))")
                    
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    completion?(.failure(FCCustomError(message:"")))
                    
                    return
                    
                }
                
                guard let data = data, error == nil else {
                    
#if DEBUG
                    if let httpResponse = response as? HTTPURLResponse {
                        debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    }
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "") \n------------------------------\n"
                    
                    debugPrint(reqString.trunc(3000))
                    
#endif
                    
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: response as? HTTPURLResponse ,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    completion?(.failure(FCCustomError(message:"")))
                    
                    return
                    
                }
                
                
                
#if DEBUG
                
                let reqString = "\n-------------FCURLSESSION6-----------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Data         : \((String(data: data, encoding: .utf8) ?? "").trunc(3000)) ....... \n------------------------------\n"
                
                if let httpResponse = response as? HTTPURLResponse{
                    
                    debugPrint("FCURLSESSION6 -- APIResponseStatusCode -- \(httpResponse.statusCode)")
                    
                }
                
                debugPrint(reqString.trunc(3000))
                
#endif
                
                // Inline (was `do { ... } catch { ... }` in the parent
                // project; the throwing calls were stripped out, so the
                // `catch` had become unreachable).
                let responseMessage = ""

                let TranslatedMessage = Translator.shared.translate(key: responseMessage)

                AnalyticsManager.logApiSuccess(request: request,
                                               error: error ,
                                               translatedMessage: TranslatedMessage )


                let sucessModel = data

                completion?(.success(sucessModel))
                
            }
            
        }
        
    }
    
    public func codableResultTaskWithCacheResponse<T: Decodable>(
        with request: URLRequest,
        completion: ((Result<T?, Error>) -> Void)? = nil
    ) -> URLSessionDataTask {
        
        DispatchQueue.global(qos: .background).async {
            if let cachedResponse = URLCache.shared.cachedResponse(for: request),
               let successModel = try? JSONDecoder().decode(T.self, from: cachedResponse.data) {
                DispatchQueue.main.async {
                    debugPrint("Using cached response")
                    completion?(.success(successModel))
                }
            }
        }
        
        return self.dataTask(with: request) { data, response, error in
            if let error = error as? URLError,
               (error.code == .dataNotAllowed ||
                InternetConnectionManager.isConnectedToNetwork() == false) {
                DispatchQueue.global(qos: .background).async {
                    if let cachedResponse = URLCache.shared.cachedResponse(for: request),
                       let successModel = try? JSONDecoder().decode(T.self, from: cachedResponse.data) {
                        DispatchQueue.main.async {
                            debugPrint("Offline: Using cached response")
                            completion?(.success(successModel))
                        }
                    } else {
                        debugPrint("Offline: No cached data available")
                        DispatchQueue.main.async {
                            completion?(.failure(error))
                        }
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                if let error = error as NSError?,
                   error.code == NSURLErrorCancelled {
                    debugPrint("NSURLErrorCancelled called from project switch page.")
                    DispatchQueue.global(qos: .background).async {
                        if let cachedResponse = URLCache.shared.cachedResponse(for: request),
                           let successModel = try? JSONDecoder().decode(T.self, from: cachedResponse.data) {
                            DispatchQueue.main.async {
                                debugPrint("Offline: Using cached response")
                                completion?(.success(successModel))
                            }
                        } else {
                            debugPrint("Offline: No cached data available")
                            DispatchQueue.main.async {
                                completion?(.failure(error))
                            }
                        }
                    }
                    return
                }
                
                if let error = error as? HTTPURLResponse,
                   error.statusCode == URLError.Code.notConnectedToInternet.rawValue {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(error.statusCode)")
                    DispatchQueue.global(qos: .background).async {
                        if let cachedResponse = URLCache.shared.cachedResponse(for: request),
                           let successModel = try? JSONDecoder().decode(T.self, from: cachedResponse.data) {
                            DispatchQueue.main.async {
                                debugPrint("Offline: Using cached response")
                                completion?(.success(successModel))
                            }
                        } else {
                            debugPrint("Offline: No cached data available")
                            DispatchQueue.main.async {
                                completion?(.failure(FCCustomError(message: error.debugDescription )))
                            }
                        }
                    }
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 400 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_400_ERROR )"
                        
                        var TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        if let messageElements = responseModel.messageElements,
                           !messageElements.isEmpty {
                            TranslatedMessage = self.convertSearchReplacer(_message: TranslatedMessage, _messageElements: messageElements)
                        }
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            return
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_400_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                
                else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
#if DEBUG
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "") \n------------------------------\n"
                    debugPrint(reqString.trunc(3000))
#endif
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    if ServerRequest.IF_DEBUG == true  {
                        let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_401_ERROR
                        completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                        if(appUserDefault.getAppOpenScreen() != .registartion && appUserDefault.getAppOpenScreen() != .intro){
                            Util.logOutUser()
                        }//   // resetUser on 401 ERROR
                        return
                    }
                    else {
                        completion?(.failure(error ?? FCCustomError(message:"")))
                        if(appUserDefault.getAppOpenScreen() != .registartion && appUserDefault.getAppOpenScreen() != .intro){
                            Util.logOutUser()
                        }// resetUser on 401 ERROR
                        return
                    }
                }
                
                else  if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return}
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_403_ERROR )"
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if let url = request.url?.absoluteString,url.contains(CONSTANTS.ChatGPTURL) {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                        }else{
                            if ServerRequest.IF_DEBUG == true  {
                                let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                                completion?(.failure(FCCustomError(message: errorMessage)))
                                if(appUserDefault.getAppOpenScreen() != .allProjects && appUserDefault.getAppOpenScreen() != .allProjects){
                                    Util.redirectAllProjectScreen()
                                }
                                return
                            }
                            else {
                                completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                                if(appUserDefault.getAppOpenScreen() != .allProjects && appUserDefault.getAppOpenScreen() != .allProjects){
                                    Util.redirectAllProjectScreen()
                                }
                                return
                            }
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_406_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            if(appUserDefault.getAppOpenScreen() != .allProjects && appUserDefault.getAppOpenScreen() != .allProjects){
                                Util.redirectAllProjectScreen()
                            }
                            return
                        }
                        else {
                            completion?(.failure(error))
                            if(appUserDefault.getAppOpenScreen() != .allProjects && appUserDefault.getAppOpenScreen() != .allProjects){
                                Util.redirectAllProjectScreen()
                            }
                            return
                        }
                        
                    }
                }
                
                else   if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_404_ERROR )"
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            return
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_404_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                else  if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 406 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return}
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_406_ERROR )"
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            return
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_406_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                
                else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 500 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    var errorMessage = (error?.localizedDescription ?? "")
#if DEBUG
                    if let data = data {
                        do {
                            let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                            errorMessage = "\(responseModel.message ?? CONSTANTS.SERVER_500_ERROR )"
                        } catch {
                            debugPrint("Parsing Error", error)
                        }
                    }
                    
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(errorMessage) \n------------------------------\n"
                    debugPrint(reqString.trunc(3000))
#endif
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    
                    if ServerRequest.IF_DEBUG == true  {
                        let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_500_ERROR
                        completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                        return
                    }
                    else {
                        let apiUrl = request.url?.absoluteString ?? ""
                        if apiUrl.contains("https://notificationapi.zillit.com/api/v2/project/unread") || apiUrl.contains("https://notificationapi.zillit.com/api/v2/device/unread") || apiUrl.contains("https://locationapi.zillit.com/api/v2/location/log")  {
                            completion?(.failure(error ?? FCCustomError(message: "")))
                            return
                        }else{
                            let errorMessage = CONSTANTS.SERVER_500_ERROR
                            completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                            return
                        }
                    }
                }
                
                else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 502 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    var errorMessage = (error?.localizedDescription ?? "")
#if DEBUG
                    if let data = data {
                        do {
                            let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                            errorMessage = "\(responseModel.message ?? CONSTANTS.SERVER_502_ERROR )"
                        } catch {
                            debugPrint("Parsing Error", error)
                        }
                    }
                    
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(errorMessage) \n------------------------------\n"
                    debugPrint(reqString.trunc(3000))
#endif
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    if ServerRequest.IF_DEBUG == true  {
                        let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_502_ERROR
                        completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                        return
                    }
                    else {
                        let apiUrl = request.url?.absoluteString ?? ""
                        if apiUrl.contains("https://notificationapi.zillit.com/api/v2/project/unread") || apiUrl.contains("https://notificationapi.zillit.com/api/v2/device/unread") || apiUrl.contains("https://locationapi.zillit.com/api/v2/location/log")  {
                            completion?(.failure(error ?? FCCustomError(message: "")))
                            return
                        }else{
                            let apiUrl = request.url?.absoluteString ?? ""
                            if apiUrl.contains("https://notificationapi.zillit.com/api/v2/project/unread") || apiUrl.contains("https://notificationapi.zillit.com/api/v2/device/unread") || apiUrl.contains("https://locationapi.zillit.com/api/v2/location/log")  {
                                completion?(.failure(error ?? FCCustomError(message: "")))
                                return
                            }else{
                                let errorMessage = CONSTANTS.SERVER_502_ERROR
                                completion?(.failure(error ?? FCCustomError(message: errorMessage)))
                                return
                            }
                        }
                    }
                }
                else   if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 422 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    do {
                        let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                        let responseMessage = "\(responseModel.message ?? CONSTANTS.SERVER_404_ERROR )"
                        let TranslatedMessage = Translator.shared.translate(key: responseMessage)
                        
#if DEBUG
                        let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "\(responseModel)") \n------------------------------\n"
                        debugPrint(reqString.trunc(3000))
#endif
                        
                        AnalyticsManager.logApiFailure(request: request,
                                                       httpResponse: httpResponse,
                                                       error: error ,
                                                       translatedMessage: TranslatedMessage )
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + (TranslatedMessage)
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            return
                        }
                        else {
                            completion?(.failure(error ?? FCCustomError(message: TranslatedMessage)))
                            return
                        }
                        
                    } catch {
                        
                        if ServerRequest.IF_DEBUG == true  {
                            let errorMessage = "\(request.url?.absoluteString ?? "")" + "\n" + CONSTANTS.SERVER_404_ERROR
                            completion?(.failure(FCCustomError(message: errorMessage)))
                            debugPrint("Parsing Error", error)
                            return
                        }
                        else {
                            completion?(.failure(error))
                            return
                        }
                        
                    }
                }
                
                else   if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 1051 {
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    guard let data = data, error == nil else {
                        return
                    }
                    debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)   \(String(describing: String(data: data, encoding: .utf8)))")
                    
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: httpResponse,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    completion?(.failure(FCCustomError(message:"")))
                    return
                    
                }
                guard let data = data, error == nil else {
#if DEBUG
                    if let httpResponse = response as? HTTPURLResponse {
                        debugPrint("codableResultTask:: APIResponseStatusCode \(httpResponse.statusCode)")
                    }
                    let reqString = "\n-----------FCURLSESSION5-------------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Error         : \(error?.localizedDescription ?? "") \n------------------------------\n"
                    debugPrint(reqString.trunc(3000))
#endif
                    AnalyticsManager.logApiFailure(request: request,
                                                   httpResponse: response as? HTTPURLResponse ,
                                                   error: error ,
                                                   translatedMessage: nil )
                    
                    completion?(.failure(FCCustomError(message:"")))
                    return
                }
                
#if DEBUG
                let reqString = "\n-------------FCURLSESSION6-----------------\n\(request.httpMethod ?? "") URL     :  \(request.url?.absoluteString ?? "") \nHeader       :  \(request.allHTTPHeaderFields ?? [:]) \nRequestBody         : \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "") \nRecieved Data         : \((String(data: data, encoding: .utf8) ?? "")) ....... \n------------------------------\n"
                debugPrint(reqString.trunc(3000))
                
#endif
                
                do {
                    let responseModel = try JSONDecoder().decode(GenericNetworkResponse.self, from: data)
                    
                    // Handle successful response
                    let responseMessage = responseModel.message ?? "Something went wrong"
                    let translatedMessage = Translator.shared.translate(key: responseMessage)
                    
                    AnalyticsManager.logApiSuccess(request: request,
                                                   error: error ,
                                                   translatedMessage: translatedMessage )
                    
                    // Store response in cache
                    if let response = response,
                       error == nil  {
                        let cachedResponse = CachedURLResponse(response: response, data: data)
                        URLCache.shared.storeCachedResponse(cachedResponse, for: request)
                    }
                    
                    // Attempt to decode the actual response model
                    let successModel = try JSONDecoder().decode(T.self, from: data)
                    
                    // Call completion with success
                    completion?(.success(successModel))
                } catch {
                    // Handle decoding error
                    debugPrint("Error decoding JSON:", error)
                    // Print received data for debugging
                    if let responseData = String(data: data, encoding: .utf8) {
                        debugPrint("Received data:", responseData)
                    }
                    // Call completion with failure
                    completion?(.failure(error))
                }
            }
        }
    }
    
    func fetchMediaFromURL(
        media: String,
        bucket: String,
        region: String,
        completion: ((Result<Data?, Error>) -> Void)? = nil
    ) {
        
        var endPoint = ServerRequest.MEDIA_Base_URL
        switch S3FileUploadMangerConfig.shared.storageSource {
        case .box(_, _): endPoint.append("box/file")
        case .s3: endPoint.append("s3/file")
        }
        
        guard let url = URL(string: endPoint) else {
            DispatchQueue.main.async {
                completion?(.failure(FCCustomError(message: "Invalid URL: \(endPoint)")))
            }
            return
        }
        
        let deviceId = "\(Util.deviceId())"
        let userID = appUserDefault.getLoginUserData()?.userID ?? ""
        let projectId = appUserDefault.getLoginUserData()?.projectID ?? ""
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        
        var moduleData: [String: Any] = [
            "bucket": bucket,
            "region": region,
            "key": media,
            "user_id": userID,
            "project_id": projectId,
            "device_id": deviceId,
            "time_stamp":timestamp
        ]
        
        if let projectData = appUserDefault.getProjectData(),
           let boxClientID = projectData.enterpriseClientId,
           !boxClientID.isEmpty,
           let fileID = Util.getBoxFileID(media) {
            moduleData = [
                "enterprise_client_id": boxClientID,
                "file_id": fileID,
                "user_id": userID,
                "project_id": projectId,
                "device_id": deviceId,
                "time_stamp":timestamp
            ]
        }
        
        FCURLSession.sharedInstance.session?.getMediaFromURL(url, moduleData: moduleData) { data, error in
            DispatchQueue.main.async {
                if let error = error {
                    debugPrint("Error getting media: \(error.localizedDescription)")
                    completion?(.failure(FCCustomError(message: error.localizedDescription)))
                } else {
                    debugPrint("loadDocuments() stringUrl: \(bucket)/\(media)", data?.count ?? 0)
                    completion?(.success(data))
                }
            }
        }
    }
    
    func getMediaFromURL(_ url: URL, moduleData : [String:Any] ,completion: @escaping (Data?, Error?) -> Void) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        var moduleData = moduleData
        moduleData["time_stamp"] = timestamp
        
        // Create a URLSession configuration with default settings
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        // Create a URLSession object with the configuration
        let session = URLSession(configuration: configuration)
        
        // Create a GET request with the provided URL
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==", forHTTPHeaderField: "Authorization")
        request.setValue(Util.getAppVersion(), forHTTPHeaderField: "appVersion")
        request.setValue(Util.getAppVersion(), forHTTPHeaderField: "iosversion")
        request.setValue(Util.getDeviceName(), forHTTPHeaderField: "devicename")
        request.setValue(Util.getDeviceInfo(), forHTTPHeaderField: "deviceinfo")
        request.setValue(Util.getDeviceType(), forHTTPHeaderField: "requesttype")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Util.getDeviceName(), forHTTPHeaderField: "userAgent")
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: moduleData, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            debugPrint(jsonString) // Use the jsonString as needed
            let encryptDescreption = SocketIOManager.default_.getEncryptedHeaderText(string: jsonString)
            request.setValue(encryptDescreption, forHTTPHeaderField: "moduledata")
        }
        // Create a data task with the request and handle the response
        debugPrint("getDataFromURL()  Requested Data : ",request)
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                // Check for errors
                guard error == nil else {
                    debugPrint("getDataFromURL()  error : ", (error?.localizedDescription ?? "Unknown Error"))
                    completion(nil, error)
                    return
                }
                // Check if a response was received
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(nil, NSError(domain: "InvalidResponseError", code: 0, userInfo: nil))
                    return
                }
                if let response = response , let contentType = httpResponse.mimeType {
                    debugPrint("getDataFromURL()  Headers : ",request.allHTTPHeaderFields ?? [:])
                    debugPrint("getDataFromURL()  Response : ",response)
                    debugPrint("getDataFromURL()  MIME TYPE : ",contentType)
                    debugPrint("getDataFromURL()  statusCode : ",httpResponse.statusCode)
                }
                // Check if the response status code indicates success (200 OK)
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(nil, NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil))
                    return
                }
                
                // Check if the response data is valid image data
                guard let data = data else {
                    completion(nil, NSError(domain: "InvalidImageDataError", code: 0, userInfo: nil))
                    return
                }
                
                // Call the completion handler with the image
                completion(data, nil)
            }
        }
        // Start the data task
        task.resume()
    }
    
}

public protocol FCCodableDataTask {
    var urlDataTask: URLSessionDataTask? { get }
}

public protocol FCURLRequestProtocol {
    var urlRequest: URLRequest? { get }
}

struct FCCustomError: Error {
    let message: String
}


extension URLSession {
    
    func convertSearchReplacer(_message : String ,
                               _messageElements : [MessageElementsArray]? ) -> String {
        var TranslatedMessage = _message
        if let messageElements = _messageElements,
           !messageElements.isEmpty {
            for replacement in messageElements {
                if let search = replacement.search as? String, // Safely cast to String
                   let replacer = replacement.replacer {
                    let replacerString = self.convertdepartmentString(input: String(describing: replacer))
                    TranslatedMessage = TranslatedMessage.replacingOccurrences(of: search, with: replacerString)
                }
            }
        }
        return TranslatedMessage
    }
    
    func convertdepartmentString(input: String) -> String {
        var output = input
        // Replace {{}} with :
        output = output.replacingOccurrences(of: "\\{", with: " ", options: .regularExpression)
        output = output.replacingOccurrences(of: "\\}", with: " ", options: .regularExpression)
        let components = output.components(separatedBy: " ")
        let translatedComponents = components.map {
            Translator.shared.translate(key: $0) }
        let result = translatedComponents.joined(separator: " ")
        return result
    }
}


//========================================================================================================================================================
