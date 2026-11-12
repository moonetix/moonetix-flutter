import Flutter
import UIKit
import XCTest

@testable import moonetix_offerwall

class RunnerTests: XCTestCase {

  func testInitAccepted() {
    let plugin = MoonetixOfferwallPlugin()
    let call = FlutterMethodCall(methodName: "init", arguments: ["appId": "eeee35416ef2e85e9b4d8203"])
    let done = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertNil(result)
      done.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testOpenReportsUnsupported() {
    let plugin = MoonetixOfferwallPlugin()
    let call = FlutterMethodCall(methodName: "open", arguments: ["token": "sst_" + String(repeating: "a", count: 43)])
    let done = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      let error = result as? FlutterError
      XCTAssertEqual(error?.code, "UNSUPPORTED")
      XCTAssertEqual(error?.message, "iOS support is coming soon")
      done.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}
