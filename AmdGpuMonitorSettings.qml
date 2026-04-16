import QtQuick
import Quickshell

import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "amdGpuMonitorRevive"

    Rectangle {
        width: parent.width
        height: layoutGroup.childrenRect.height + Theme.spacingM * 2
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Theme.outline
        border.width: 1
        opacity: 0.8

        function loadValue() {
            function recursiveLoad(item) {
                if (item.loadValue) item.loadValue();
                if (item.children) {
                    for (var i = 0; i < item.children.length; i++) {
                        recursiveLoad(item.children[i]);
                    }
                }
            }
            recursiveLoad(layoutGroup);
        }

        Column {
            id: layoutGroup
            width: parent.width - Theme.spacingM * 2
            anchors.centerIn: parent
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "dashboard"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                SelectionSetting {
                    width: parent.width - 22 - Theme.spacingM
                    settingKey: "popoutStyle"
                    label: "Popout Style"
                    description: "Visual style for the popout panel."
                    options: [
                        { label: "Legacy", value: "legacy" },
                        { label: "Alternative", value: "alt" },
                        { label: "DMS", value: "dms" },
                        { label: "DMS Extended", value: "dmsExtended" }
                    ]
                    defaultValue: "dmsExtended"
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "aspect_ratio"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                ToggleSetting {
                    width: parent.width - 22 - Theme.spacingM
                    settingKey: "minimumWidth"
                    label: "Force Padding"
                    description: "Prevent widget width from changing as values update."
                    defaultValue: false
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "visibility"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                SelectionSetting {
                    width: parent.width - 22 - Theme.spacingM
                    settingKey: "persistEmptyStates"
                    label: "Persist Empty States"
                    description: "Keeps charts, lists, and bars visible in the layout even when they contain no data."
                    options: [
                        { label: "Enabled", value: "enabled" },
                        { label: "Disabled", value: "disabled" }
                    ]
                    defaultValue: "enabled"
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: heroIconGroup.childrenRect.height + Theme.spacingM * 2
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Theme.outline
        border.width: 1
        opacity: 0.8

        function loadValue() {
            function recursiveLoad(item) {
                if (item.loadValue) item.loadValue();
                if (item.children) {
                    for (var i = 0; i < item.children.length; i++) {
                        recursiveLoad(item.children[i]);
                    }
                }
            }
            recursiveLoad(heroIconGroup);
        }

        Column {
            id: heroIconGroup
            width: parent.width - Theme.spacingM * 2
            anchors.centerIn: parent
            spacing: Theme.spacingL

            // Custom Hero Icon Path
            Column {
                width: parent.width
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    DankIcon { name: "image"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    Column {
                        width: parent.width - 22 - Theme.spacingM
                        spacing: 2
                        StyledText {
                            text: "Custom Hero Icon Path"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: "Absolute path or URL to replace the default logo."
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                StringSetting {
                    width: parent.width
                    settingKey: "customHeroIcon"
                    label: ""
                    description: ""
                    placeholder: "/path/to/icon.png"
                    defaultValue: ""
                }
            }

            // Custom Hero Icon Size
            Column {
                width: parent.width
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingM
                    DankIcon { name: "photo_size_select_large"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    Column {
                        width: parent.width - 22 - Theme.spacingM
                        spacing: 2
                        StyledText {
                            text: "Custom Icon Size (px)"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                        StyledText {
                            text: "Width and height of the custom icon (max 70). Default is 46."
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                StringSetting {
                    width: parent.width
                    settingKey: "customHeroIconSize"
                    label: ""
                    description: ""
                    placeholder: "46"
                    defaultValue: "46"
                }
            }
        }
    }
}
