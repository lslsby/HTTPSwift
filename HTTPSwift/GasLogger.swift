//
//  GasLogger.swift
//  Gas
//
//  Created by Adden on 10/26/15.
//  Copyright © 2015 adden. All rights reserved.
//

import UIKit

class GasLogger : NSObject
{
    static func log(data: Any? = nil, functionName: String = __FUNCTION__, fileName: String = __FILE__, lineNumber: Int = __LINE__)
    {
        let info: String = "[FileName]: \(fileName), [Function]: \(functionName), [Line]: \(lineNumber) ";
        print(info);
        if (nil != data) {
            print(data!);
        }
        
        print("\n\n");
    }
}
