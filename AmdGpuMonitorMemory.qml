import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// Required for OpacityMask/ColorOverlay
import Qt5Compat.GraphicalEffects

PluginComponent {
    id: root
    
    // --- Properties & Settings ---
    property string dankbarPill: pluginData.dankbarPill || "total_count"
    property bool isLoading: false
    property real iconSize: 18

    // Helper function for the text display
    function getDankbarText(isVertical) {
        if (root.isLoading) return isVertical ? "..." : "Fetching...";
        
        // Simplified return logic - replace with your data variables as needed
        if (isVertical) return "7"; 
        return "Anime (7)";
    }

    // --- Horizontal Bar Pill (The standard 'Pill' look) ---
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            
            Item {
                width: root.iconSize
                height: root.iconSize
                anchors.verticalCenter: parent.verticalCenter
                
                Image {
                    id: horizLiveChartLogo
                    source: "LiveChart.svg"
                    anchors.fill: parent
                    sourceSize: Qt.size(64, 64)
                    smooth: true
                    visible: false
                }
                
                ColorOverlay {
                    anchors.fill: horizLiveChartLogo
                    source: horizLiveChartLogo
                    color: Theme.widgetTextColor
                }
            }

            Rectangle {
                id: textContainer
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                clip: true
                width: Math.min(statusText.contentWidth, 180)
                height: 18
                
                Behavior on width {
                    NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing }
                }

                StyledText {
                    id: statusText
                    readonly property bool isLong: contentWidth > textContainer.width
                    property real scrollOffset: 0
                    
                    x: isLong ? -scrollOffset : 0
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.widgetTextColor
                    text: root.getDankbarText(false)
                    wrapMode: Text.NoWrap
                    
                    onTextChanged: {
                        scrollOffset = 0;
                        scrollAnimation.restart();
                    }

                    SequentialAnimation {
                        id: scrollAnimation
                        running: statusText.isLong && textContainer.visible
                        loops: Animation.Infinite
                        PauseAnimation { duration: 2000 }
                        NumberAnimation {
                            target: statusText
                            property: "scrollOffset"
                            from: 0
                            to: statusText.contentWidth - textContainer.width + 10
                            duration: Math.max(1000, (statusText.contentWidth - textContainer.width) * 40)
                            easing.type: Easing.Linear
                        }
                        PauseAnimation { duration: 2000 }
                        NumberAnimation {
                            target: statusText
                            property: "scrollOffset"
                            to: 0
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }
        }
    }

    // --- Vertical Bar Pill (For vertical sidebars) ---
    verticalBarPill: Component {
        Column {
            spacing: 4
            Item {
                width: root.iconSize
                height: root.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
                
                Image {
                    id: vertLiveChartLogo
                    source: "LiveChart.svg"
                    anchors.fill: parent
                    sourceSize: Qt.size(64, 64)
                    smooth: true
                    visible: false
                }
                
                ColorOverlay {
                    anchors.fill: vertLiveChartLogo
                    source: vertLiveChartLogo
                    color: Theme.widgetTextColor
                }
            }
            StyledText {
                text: root.getDankbarText(true)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.widgetTextColor
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }
    }
}