//
//  LocalizationTests.swift
//  PinnestTests
//

import Foundation
import Testing

struct LocalizationTests {
    @Test func simplifiedChineseCatalogCompilesIntoTheAppBundle() throws {
        let path = try #require(Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))

        let translations = [
            "About %@": "关于%@",
            "About Pinnest": "关于Pinnest",
            "Check for Updates…": "检查更新…",
            "Close All Hidden Pins": "关闭所有隐藏的图像",
            "Close All Pins": "关闭所有钉住的图像",
            "Close All Visible Pins": "关闭所有未隐藏的图像",
            "Close Pins on Other Desktops": "关闭其他桌面上钉住的图像",
            "Close Pins on This Desktop": "关闭此桌面上钉住的图像",
            "Close Visible Pins on Other Desktops": "关闭其他桌面上未隐藏的图像",
            "Close Visible Pins on This Desktop": "关闭此桌面上未隐藏的图像",
            "Copy to clipboard": "复制到剪贴板",
            "Drag as image file": "拖拽图像为文件",
            "Keep images floating above your work for quick, unobtrusive reference.":
                "将图像悬浮在工作内容上方，方便快速、无干扰地进行参考。",
            "Launch at Login": "随macOS启动",
            "Opacity": "不透明度",
            "Piercing off": "穿透已关闭",
            "Piercing on": "穿透已开启",
            "Pin from Clipboard": "钉住剪贴板的图像",
            "Pin from File…": "从文件钉住图像…",
            "Pinned Image.png": "钉住的图像.png",
            "Quit Pinnest": "退出Pinnest",
            "Reset size, rotation & opacity": "重置大小、旋转和不透明度",
            "Rotate clockwise": "顺时针旋转",
            "Rotate counterclockwise": "逆时针旋转",
            "Scale": "缩放",
            "Stubborn off": "滞留已关闭",
            "Stubborn on": "滞留已开启",
            "Version %@ (%@)": "版本%@（%@）",
            "clicks pass through": "光标操作会穿透图像",
            "drag, or click to type": "拖动调整，或单击输入",
            "image takes clicks": "图像可以被光标控制",
            "image visible on every Desktop": "图像会在所有桌面显示",
            "image visible only on this Desktop": "图像仅在此桌面显示"
        ]

        for (key, expected) in translations {
            #expect(bundle.localizedString(forKey: key, value: nil, table: nil) == expected)
        }
    }
}
