//
//  ViewController.swift
//  HTTPSwift
//
//  Created by Adden on 12/19/15.
//  Copyright © 2015 adden. All rights reserved.
//

import UIKit

class ViewController: UIViewController, HTTPRequestDelegete {
    
    var url: String! = nil;

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
//        let file: String = "file:///Users/Adden/Desktop/iOS.zip";
//        let file: String = "file:///Users/Adden/Desktop/nginx.conf";

//        let filePath: NSURL = NSURL(string: file)!;
//        print(filePath);
//        let parameter: [String: String] = ["Adden": "zhangyong"];
//        HTTPRequest.upload("http://localhost/index.php", headerField: nil, parameter: parameter, delegate:self, fromFile: filePath);
        
//        HTTPRequest.post("http://localhost/index.php", headerField: nil, parameter: parameter, delegate: self);
        
        self.url = "http://localhost/iGas.key";
        HTTPRequest.download(self.url, delegate: self);
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: HTTPRequestDelegete
    
    func onRequestSuccess(response: HTTPResponse) -> Void {

        if (response.filePath != nil) {
//            GasLogger.log(response.filePath.description);
//            let data: NSData = NSData(contentsOfURL: response.filePath)!;
//            let content: String = String(data: data, encoding: NSUTF8StringEncoding)!;
//            GasLogger.log(content);
//            let content: String =
            
            let toURL: NSURL = NSURL(string: "file:///Users/Adden/Desktop/iGas.key")!;
            let fileManager: NSFileManager = NSFileManager.defaultManager();
            try! fileManager.moveItemAtURL(response.filePath, toURL: toURL);
            return;
        }
        let str: String = String(data: response.receiveData, encoding: NSUTF8StringEncoding)!;
        GasLogger.log(str);
    }
    
    func onRequestProgress(response: HTTPResponse) -> Void {
        GasLogger.log(response.process);
    }
    
    func onRequestFailed(response: HTTPResponse) -> Void {
        GasLogger.log(response.error);
    }

}

