//
//  PusulaFitWidgetBundle.swift
//  PusulaFitWidget
//

import WidgetKit
import SwiftUI

@main
struct PusulaFitWidgetBundle: WidgetBundle {
    var body: some Widget {
        PusulaFitWidget()
        PusulaFitProteinWidget()
        PusulaFitWaterWidget()
    }
}
