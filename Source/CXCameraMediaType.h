//
//  CXCameraMediaType.h
//  OpenCV-iOS-demo
//
//  Created by 刘伟 on 2/16/17.
//  Copyright © 2017 上海凌晋信息技术有限公司. All rights reserved.
//

#ifndef CXCameraMediaType_h
#define CXCameraMediaType_h

typedef enum :NSInteger {
    kCameraMediaTypeVideo, // 视频模式
    kCameraMediaTypePhoto, // 拍照模式
    kCameraMediaTypeDocument // 拍文档模式
} CXCameraMediaType;

typedef void (^CXCameraResult)(CXCameraMediaType type, NSString* filePath);

#endif /* CameraMediaType_h */
