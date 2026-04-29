//
//  DriftWidgetLiveActivity.swift
//  DriftWidget
//
//  Created by Griffin Mullins on 4/29/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct DriftWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct DriftWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriftWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension DriftWidgetAttributes {
    fileprivate static var preview: DriftWidgetAttributes {
        DriftWidgetAttributes(name: "World")
    }
}

extension DriftWidgetAttributes.ContentState {
    fileprivate static var smiley: DriftWidgetAttributes.ContentState {
        DriftWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: DriftWidgetAttributes.ContentState {
         DriftWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: DriftWidgetAttributes.preview) {
   DriftWidgetLiveActivity()
} contentStates: {
    DriftWidgetAttributes.ContentState.smiley
    DriftWidgetAttributes.ContentState.starEyes
}
