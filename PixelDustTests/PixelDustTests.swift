//
//  PixelDustTests.swift
//  PixelDustTests
//
//  Created by Kain Osterholt on 10/27/18.
//  Copyright © 2018 Kain Osterholt. All rights reserved.
//

import XCTest
@testable import PixelDust

class PixelDustTests: XCTestCase {

    func testConstruction() {
        let comparator = ImageComparator()
        XCTAssertFalse(comparator.compare())
    }

    func testSetImage() {
        guard let uiImage1 = UIImage(named: "image1"),
            let uiImage2 = UIImage(named: "image1-different") else {
                XCTFail()
                return
        }
        
        let comparator = ImageComparator()
        comparator.setImage(uiImage1, image2: uiImage2)

        XCTAssertFalse(comparator.compare())
        XCTAssertGreaterThan(comparator.getDiffFactor(), 0)
        add(XCTAttachment(image: comparator.getDiffImage(true)))
    }

    func testDifferentImagesDiff() {
        let comparator = ImageComparator(image: UIImage(named: "image1")!, image2: UIImage(named: "image1-different")!)
        XCTAssertFalse(comparator.compare());
        XCTAssertGreaterThan(comparator.getDiffFactor(), 0.0)
        add(XCTAttachment(image: comparator.getDiffImage()))
    }

    func testAmplifiedDiff() {
        let comparator = ImageComparator(image: UIImage(named: "image1")!, image2: UIImage(named: "image1-different")!)
        XCTAssertFalse(comparator.compare());
        XCTAssertGreaterThan(comparator.getDiffFactor(), 0.0)
        add(XCTAttachment(image: comparator.getDiffImage(true)))
    }

    func testImageSameSame() {
        let comparator = ImageComparator(image: UIImage(named: "image1")!, image2: UIImage(named: "image1-same")!)
        XCTAssertTrue(comparator.compare());
        XCTAssertEqual(0.0, comparator.getDiffFactor())
        add(XCTAttachment(image: comparator.getDiffImage()))
        add(XCTAttachment(image: comparator.getDiffImage(true)))
    }

    func testOnePixelDiff() {
        let comparator = ImageComparator(image: UIImage(named: "white-first-pixel-black")!, image2: UIImage(named: "white")!)
        XCTAssertFalse(comparator.compare())
        XCTAssertGreaterThan(comparator.getDiffFactor(), 0.0)
    }

    func testDifferentDimensions() {
        let comparator = ImageComparator(image: UIImage(named: "image1")!, image2: UIImage(named: "sideways")!)
        XCTAssertFalse(comparator.compare())
    }

    func testSetImageAgain() {
        let comparator = ImageComparator(image: UIImage(named: "image1")!, image2: UIImage(named: "image1-same")!)
        XCTAssertTrue(comparator.compare())
        
        comparator.setImage(UIImage(named: "image1")!, image2: UIImage(named: "sideways")!)
        XCTAssertFalse(comparator.compare())
    }
}
