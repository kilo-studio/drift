//
//  DriftWidgetBundle.swift
//  DriftWidget
//
//  Created by Griffin Mullins on 4/29/26.
//

import WidgetKit
import SwiftUI

@main
struct DriftWidgetBundle: WidgetBundle {
    var body: some Widget {
        DriftWidget()
        DriftWidgetControl()
        DriftWidgetLiveActivity()
    }
}
