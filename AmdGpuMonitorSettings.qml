import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "amdGpuMonitorRevive"

    StyledText {
        width: parent.width
        text: "AMD GPU Monitor"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Monitor AMD GPU usage, VRAM, temperature and power consumption."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        settingKey: "minimumWidth"
        label: "Force Padding"
        description: "Prevent widget width from changing as values update"
        defaultValue: false
    }

    SelectionSetting {
        settingKey: "popoutStyle"
        label: "Popout Style"
        description: "Visual style for the popout panel"
        options: [
            { label: "Legacy", value: "legacy" },
            { label: "Alternative", value: "alt" },
            { label: "DMS", value: "dms" },
            { label: "DMS Extended", value: "dmsExtended" }
        ]
        defaultValue: "dmsExtended"
    }

    StringSetting {
        settingKey: "customHeroIcon"
        label: "Custom Hero Icon Path"
        description: "Absolute path or URL to replace the generic developer_board logo before the GPU name."
        defaultValue: ""
    }

    StringSetting {
        settingKey: "customHeroIconSize"
        label: "Custom Icon Size (px)"
        description: "The width and height of the custom icon (max 70). Default is 46."
        defaultValue: "46"
    }
}
