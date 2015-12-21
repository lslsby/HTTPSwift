//
//  HTTPRequest.swift
//  Gas
//
//  Created by Adden on 12/12/15.
//  Copyright © 2015 adden. All rights reserved.
//

import Foundation

class HTTPResponse : NSObject {
    
    var error: String! = nil;
    // 如果用户在同一个Class里面有多个Url请求, 在delegate方法里面可以用url来判断用户请求的是哪个请求
    var url: String! = nil;
    
    // 记录的是最后一条数据块的header回应, 正常的情况下只有一条reponse的header, 对于大数据块可能有对个回应头
    // 这里只记录最后一条
    var receiveHeader: NSURLResponse! = nil;
    var receiveData: NSMutableData! = nil;
    
    // 上传或者下载的进度
    var process: Float! = 0.0;
    
    // 下载文件的在本地存储的URL
    var filePath: NSURL! = nil;
    
    // 服务器返回数据, 解析, 如果使用, 需要把HTTPRequest里面的jsonResolution的值设为true
    // 针对AE的服务器返回设置, 非AE不要使用
    var errorCode: Int! = nil;
    var errorMessage: String! = nil;
    var result: [Any]! = nil;
}

@objc
protocol HTTPRequestDelegete : NSObjectProtocol {
    
    optional func onRequestSuccess(response: HTTPResponse) -> Void;
    optional func onRequestProgress(response: HTTPResponse) -> Void;
    optional func onRequestFailed(response: HTTPResponse) -> Void;
}

struct JsonKey {
    
    static let errorCodeKey = "ErrorCode";
    static let errorMessageKey = "ErrorMessage";
    static let resultKey = "Result";
}

enum HTTPRequestMethod : String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
}

class HTTPRequest : NSObject, NSURLSessionDataDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate {
    
    weak var delegate: HTTPRequestDelegete? = nil;
    // 是否需要把返回的数据解析成HTTPResponse里面的json格式
    var jsonResolution: Bool = false;
    
    private var response: HTTPResponse! = nil;
    private var url: String! = nil;
    private var task: NSURLSessionTask! = nil;
    
    // 私有的全局变量
    private static var session: NSURLSession! = nil;
    private static var configuration: NSURLSessionConfiguration! = nil;
    private static var requestList: [HTTPRequest]! = nil;
    private static var oneToken: dispatch_once_t = 0;
    
    private init(url: String) {
        
        super.init();
        self.url = url;
        self.response = HTTPResponse();
        self.response.receiveData = NSMutableData();
        self.response.url = url;
        
        dispatch_once(&HTTPRequest.oneToken) { [unowned self] () -> Void in
            let configuration: NSURLSessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration();
            
            // 配置缓存路径
            let cachePath: String = "/CacheDirectory";
            let pathList: [String] = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true);
            let path: NSString = pathList[0];
            let bundleIdentifier: String = NSBundle.mainBundle().bundleIdentifier!;
            let fullCachePath: String = ((path as NSString).stringByAppendingPathComponent(bundleIdentifier) as NSString).stringByAppendingPathComponent(cachePath);
            GasLogger.log("URLSession缓存路径: " + fullCachePath);
            let myCache: NSURLCache = NSURLCache(memoryCapacity: 16384, diskCapacity: 268435456, diskPath: fullCachePath);
            configuration.URLCache = myCache;
            configuration.requestCachePolicy = NSURLRequestCachePolicy.UseProtocolCachePolicy;
            configuration.allowsCellularAccess = true;
            
            HTTPRequest.configuration = configuration;
            
            let session: NSURLSession = NSURLSession(configuration: configuration, delegate: self, delegateQueue: NSOperationQueue.mainQueue());
            HTTPRequest.session = session;
            
            HTTPRequest.requestList = Array<HTTPRequest>();
        };
    }
    
    static func shareCookie(urlString: String!) -> [String: String]? {
        
        if (nil == urlString) {
            return nil;
        }
        
        let url: NSURL = NSURL(string: urlString)!;
        
        let cookieStorage: [NSHTTPCookie]? = NSHTTPCookieStorage.sharedHTTPCookieStorage().cookiesForURL(url);
        
        if (nil == cookieStorage) {
            return nil;
        }
        
        let shareCookie: [String: String] = NSHTTPCookie.requestHeaderFieldsWithCookies(cookieStorage!);
        
        return shareCookie;
    }
    
    static func get(urlString: String, headerField: [String: String]?, delegate: HTTPRequestDelegete?, shareCookie: Bool = true, json: Bool = false) -> HTTPRequest {
        
        return HTTPRequest.dataTask(urlString, method: HTTPRequestMethod.GET, headerField: headerField, parameter: nil, delegate: delegate, shareCookie: shareCookie);
    }
    
    static func post(urlString: String, headerField: [String: String]?, parameter: [String: String]?, delegate: HTTPRequestDelegete?, shareCookie: Bool = true) -> HTTPRequest {
        
        return HTTPRequest.dataTask(urlString, method: HTTPRequestMethod.POST, headerField: headerField, parameter: parameter, delegate: delegate, shareCookie: shareCookie);
    }
    
    static func upload(urlString: String, headerField: [String: String]?, parameter: [String: String]?, delegate: HTTPRequestDelegete?, fromData: NSData, shareCookie: Bool = true) -> HTTPRequest {
        
        return HTTPRequest.uploadTask(urlString, method: HTTPRequestMethod.PUT, headerField: headerField, parameter: parameter, delegate: delegate, fromData: fromData, fromFile: nil);
    }
    
    static func upload(urlString: String, var headerField: [String: String]?, parameter: [String: String]?, delegate: HTTPRequestDelegete?, fromFile: NSURL, shareCookie: Bool = true) -> HTTPRequest {
        
        if (nil == headerField) {
            headerField = ["Content-Type": "multipart/form-data"];
        }
        else {
            headerField!["Content-Type"] = "multipart/form-data";
        }
        return HTTPRequest.uploadTask(urlString, method: HTTPRequestMethod.PUT, headerField: headerField, parameter: parameter, delegate: delegate, fromData: nil, fromFile: fromFile);
    }
    
    static func download(urlString: String, delegate: HTTPRequestDelegete?, shareCookie: Bool = true) -> HTTPRequest {
        return HTTPRequest.downloadTask(urlString, delegate: delegate, shareCookie: shareCookie);
    }
    
    private static func dataTask(urlString: String, method: HTTPRequestMethod, headerField: [String: String]?, parameter: [String: String]?, delegate: HTTPRequestDelegete?, shareCookie: Bool = true) -> HTTPRequest {
        
        let httpRequest: HTTPRequest = HTTPRequest.initHTTPRequest(urlString, delegate: delegate);
        
        let request: NSURLRequest = HTTPRequest.constructRequest(urlString, method: method, headerField: headerField, parameter: parameter, shareCookie: shareCookie);
        
        httpRequest.task = HTTPRequest.session.dataTaskWithRequest(request);
        httpRequest.task.resume();
        
        return httpRequest;
    }
    
    private static func uploadTask(urlString: String, method: HTTPRequestMethod, headerField: [String: String]?, parameter: [String: String]?, delegate: HTTPRequestDelegete?, fromData: NSData?, fromFile: NSURL?, shareCookie: Bool = true) -> HTTPRequest {
        
        let httpRequest: HTTPRequest = HTTPRequest.initHTTPRequest(urlString, delegate: delegate);
        
        let request: NSURLRequest = HTTPRequest.constructRequest(urlString, method: method, headerField: headerField, parameter: parameter, shareCookie: shareCookie);
        
        if (nil != fromData) {
            httpRequest.task = HTTPRequest.session.uploadTaskWithRequest(request, fromData: fromData!);
            httpRequest.task.resume();
        }
        else if (nil != fromFile) {
            httpRequest.task = HTTPRequest.session.uploadTaskWithRequest(request, fromFile: fromFile!);
            httpRequest.task.resume();
        }
        
        return httpRequest;
    }
    
    private static func downloadTask(urlString: String, delegate: HTTPRequestDelegete?, shareCookie: Bool) -> HTTPRequest {
        
        let httpRequest: HTTPRequest = HTTPRequest.initHTTPRequest(urlString, delegate: delegate);
        
        let request: NSURLRequest = HTTPRequest.constructRequest(urlString, method: HTTPRequestMethod.GET, headerField: nil, parameter: nil, shareCookie: shareCookie);
 
        httpRequest.task = HTTPRequest.session.downloadTaskWithRequest(request);
        httpRequest.task.resume();
        return httpRequest;
    }
    
    private static func initHTTPRequest(urlString: String, delegate: HTTPRequestDelegete?) -> HTTPRequest {
        let httpRequest: HTTPRequest = HTTPRequest(url: urlString);
        httpRequest.delegate = delegate;
        HTTPRequest.requestList.append(httpRequest);
        
        return httpRequest;
    }
    
    private static func constructRequest(urlString: String, method: HTTPRequestMethod, headerField: [String: String]?, parameter: [String: String]?, shareCookie: Bool) -> NSURLRequest {
        
        let newUrl: String = urlString.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!;
        let requestUrl: NSURL = NSURL(string: newUrl)!;
        let request: NSMutableURLRequest = NSMutableURLRequest(URL: requestUrl);
        request.HTTPMethod = method.rawValue;
        
        if (nil != headerField) {
            for (key, value) in headerField! {
                request.setValue(value, forHTTPHeaderField: key);
            }
        }
        
        if (nil != parameter) {
            var parameterString: String = "";
            for (key, value) in parameter! {
                parameterString.appendContentsOf(key + "=" + value + "&");
            }
            
            parameterString = (parameterString as NSString).substringWithRange(NSMakeRange(0, parameterString.characters.count - 1));
            
            request.HTTPBody = parameterString.dataUsingEncoding(NSUTF8StringEncoding);
        }
        
        if (shareCookie) {
            request.HTTPShouldHandleCookies = true;
        }
        else {
            request.HTTPShouldHandleCookies = false;
        }
        
        return request;
    }
    
    func stop() -> Void {
        
        for (var i: Int = HTTPRequest.requestList.count - 1; i >= 0; i--) {
            if (self == HTTPRequest.requestList[i]) {
                self.task = nil;
                HTTPRequest.requestList.removeAtIndex(i);
                break;
            }
        }
    }
    
    static func stopAllRequest() -> Void {
        
        for (var i: Int = HTTPRequest.requestList.count - 1; i >= 0; i--) {
            HTTPRequest.requestList[i].task = nil;
        }
        requestList.removeAll();
    }
    
    //    static func removeRequest(removeRequest request: HTTPRequest) -> Bool {
    //
    //        return true;
    //    }
    //
    //    static func removeRequest(removeUrl url: String) -> Bool {
    //        return true;
    //    }
    
    private static func findRequest(dataTask task: NSURLSessionTask) -> HTTPRequest! {
        
        var httpRequest: HTTPRequest! = nil;
        for (var i: Int = 0; i < HTTPRequest.requestList.count; i++) {
            if (task == HTTPRequest.requestList[i].task) {
                httpRequest = HTTPRequest.requestList[i];
                break;
            }
        }
        
        return httpRequest;
    }
    
    private static func findRequest(findUrl url: String) -> HTTPRequest! {
        
        var httpRequest: HTTPRequest! = nil;
        for (var i: Int = 0; i < HTTPRequest.requestList.count; i++) {
            if (url == HTTPRequest.requestList[i].url) {
                httpRequest = HTTPRequest.requestList[i];
                break;
            }
        }
        
        return httpRequest;
    }
    
    // MARK: - NSURLSessionDataDelegate
    
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        
        GasLogger.log(response);
        let httpRequest: HTTPRequest! = HTTPRequest.findRequest(dataTask: dataTask);
        if (nil == httpRequest) {
            return;
        }
        
        httpRequest.response.receiveHeader = response;
        completionHandler(NSURLSessionResponseDisposition.Allow);
    }
    
    /**
    接收HTTP回应报文的Body体回调, 这里处理资源正常的情况
    
    - parameter session:  由session发起的
    - parameter dataTask: 哪个任务
    - parameter data:     body的一个数据块, 也可能是全部
    */
    func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        
//        GasLogger.log();
        let httpRequest: HTTPRequest! = HTTPRequest.findRequest(dataTask: dataTask);
        if (nil == httpRequest) {
            return;
        }
        
        let httpReponseHeader: NSHTTPURLResponse = httpRequest.response.receiveHeader as! NSHTTPURLResponse;
        let statusCode: Int = httpReponseHeader.statusCode;
        
        if (statusCode == 200 || statusCode == 206) {
            httpRequest.response.receiveData.appendData(data);
        }
    }
    
    // MARK: - NSURLSessionTaskDelegate
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        
//        GasLogger.log();
        let httpRequest: HTTPRequest! = HTTPRequest.findRequest(dataTask: task);
        if (nil == httpRequest) {
            return;
        }
        
        if (nil != error) {
            // 网络存在错误
            httpRequest.response.error = error?.localizedDescription;
            if (nil != (httpRequest.delegate?.respondsToSelector(Selector("onRequestFailed:")))) {
                httpRequest.delegate?.onRequestFailed!(httpRequest.response);
            }
            return;
        }
        
        // 根据http头的回应情况处理, 下载任务没有NSHTTPURLResponse
        if (nil == httpRequest.response.receiveHeader) {
            return;
        }
        let httpReponseHeader: NSHTTPURLResponse = httpRequest.response.receiveHeader as! NSHTTPURLResponse;
        let statusCode: Int = httpReponseHeader.statusCode;
        
        if (statusCode != 200) {
            // 请求资源不存在的情况
            httpRequest.response.error = httpRequest.response.receiveHeader.description;
            if (nil != (httpRequest.delegate?.respondsToSelector(Selector("onRequestFailed:")))) {
                httpRequest.delegate?.onRequestFailed!(httpRequest.response);
            }
        }
        else {
            if (nil != (httpRequest.delegate?.respondsToSelector(Selector("onRequestSuccess:")))) {
                // 把返回的json格式的字符串解析成指定格式
                if (self.jsonResolution) {
                    let jsonStr: String? = String(data: httpRequest.response.receiveData, encoding: NSUTF8StringEncoding);
                    if (nil != jsonStr) {
                        do {
                            let jsonObj: [String: AnyObject] = try NSJSONSerialization.JSONObjectWithData(httpRequest.response.receiveData, options: NSJSONReadingOptions.MutableContainers) as! [String: AnyObject];
                            httpRequest.response.errorCode = jsonObj[JsonKey.errorCodeKey] as! Int;
                            httpRequest.response.errorMessage = jsonObj[JsonKey.errorMessageKey] as! String;
                            httpRequest.response.result = jsonObj[JsonKey.resultKey] as? [Any];
                        }
                        catch {
                            //                            print(error);
                            GasLogger.log(error);
                        }
                    }
                }
                
                httpRequest.delegate?.onRequestSuccess!(httpRequest.response);
            }
        }
        httpRequest.stop();
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
//        GasLogger.log();
        let httpRequest: HTTPRequest! = HTTPRequest.findRequest(dataTask: task);
        if (nil == httpRequest) {
            return;
        }
        
        let process: Float = Float(totalBytesSent) / Float(totalBytesExpectedToSend);
        httpRequest.response.process = process;
        if (nil != (httpRequest.delegate?.respondsToSelector(Selector("onRequestProgress")))) {
            httpRequest.delegate?.onRequestProgress!(httpRequest.response);
        }
    }
    
    //MARK: - NSURLSessionDownloadDelegate
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        
//        GasLogger.log();
        let httpRequest: HTTPRequest! = HTTPRequest.findRequest(dataTask: task);
        if (nil == httpRequest) {
            return;
        }
        httpRequest.response.filePath = location;
        if (nil != (httpRequest.delegate?.respondsToSelector(Selector("onRequestSuccess:")))) {
            httpRequest.delegate?.onRequestSuccess!(httpRequest.response);
        }
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
//        GasLogger.log();
        let httpRequest: HTTPRequest! = HTTPRequest.findRequest(dataTask: task);
        if (nil == httpRequest) {
            return;
        }
        
        let process: Float = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite);
        httpRequest.response.process = process;
        if (nil != (httpRequest.delegate?.respondsToSelector(Selector("onRequestProgress")))) {
            httpRequest.delegate?.onRequestProgress!(httpRequest.response);
        }
    }
}
