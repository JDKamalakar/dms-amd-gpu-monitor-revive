import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Qt5Compat.GraphicalEffects

import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    pluginId: "amdGpuMonitorRevive"

    property var contextMenuRef: null
    property real gpuUsage: 0.0
    property real vramUsed: 0.0
    property real vramTotal: 0.0
    property real vramPercent: 0.0
    property int temperature: 0
    property int powerUsage: 0
    property string gpuName: "AMD GPU"
    property var processes: [] 

    property real gfxUsage: 0.0
    property real memUsage: 0.0
    property real mediaUsage: 0.0
    
    property int updateInterval: 4000
    property var toggleProcessList

    property bool minimumWidth: pluginData.minimumWidth !== undefined ? pluginData.minimumWidth : false
    property string popoutStyle: pluginData.popoutStyle || "dmsExtended"
    property string customHeroIcon: pluginData.customHeroIcon || ""
    property string customHeroIconSize: pluginData.customHeroIconSize || "46"

    Connections {
        target: root
        function onPluginDataChanged() {
            root.popoutStyle = pluginData.popoutStyle || "dmsExtended"
            root.customHeroIcon = pluginData.customHeroIcon || ""
            root.customHeroIconSize = pluginData.customHeroIconSize || "46"
        }
    }

    // 1. ADD THIS LINE: Tells the DMS window manager exactly how wide to make the surface
    popoutWidth: root.popoutStyle === "dmsExtended" ? 640 : 360

    Timer {
        id: updateTimer
        interval: root.updateInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updateGpuStatsProcess.running = true
    }

    Process {
        id: updateGpuStatsProcess
        command: ["amdgpu_top", "-J", "-n", "1"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                const data = JSON.parse(output);
                const amd_gpu = data.devices[0];

                root.gpuName = amd_gpu["Info"]["DeviceName"] || "AMD GPU";

                root.gfxUsage = parseFloat(amd_gpu.gpu_activity["GFX"].value) || 0.0;
                root.memUsage = parseFloat(amd_gpu.gpu_activity["Memory"].value) || 0.0;
                root.mediaUsage = parseFloat(amd_gpu.gpu_activity["MediaEngine"].value) || 0.0;
                root.gpuUsage = Math.max(root.gfxUsage, root.memUsage, root.mediaUsage);
                
                root.vramUsed = parseFloat(amd_gpu["VRAM"]["Total VRAM Usage"].value) || 0.0;
                root.vramTotal = parseFloat(amd_gpu["VRAM"]["Total VRAM"].value) || 0.0;
                root.vramPercent = root.vramTotal > 0 
                    ? (root.vramUsed / root.vramTotal * 100) : 0.0;
                root.temperature = parseInt(amd_gpu.gpu_metrics.temperature_edge) || 0;
                root.powerUsage = parseInt(amd_gpu.Sensors["Average Power"].value) || 0;

                if (amd_gpu.fdinfo) {
                    const processList = [];
                    
                    // Iterate through PIDs
                    Object.keys(amd_gpu.fdinfo).forEach(pid => {
                        const procInfo = amd_gpu.fdinfo[pid];
                        
                        // Access the nested usage.usage structure
                        const usage = procInfo.usage?.usage;
                        if (!usage) return;
                        
                        const vram = usage.VRAM?.value || 0;
                        const gfx = usage.GFX?.value || 0;
                        const cpu = usage.CPU?.value || 0;
                        
                        // Only include processes using VRAM or GPU
                        if (vram > 0 || gfx > 0) {
                            processList.push({
                                name: procInfo.name || "Unknown",
                                pid: parseInt(pid),
                                vram: vram,
                                vramUnit: usage.VRAM?.unit || "MiB",
                                gfx: gfx,
                                cpu: cpu,
                                gtt: usage.GTT?.value || 0,
                                compute: usage.Compute?.value || 0
                            });
                        }
                    });
                    
                    // Sort by VRAM usage (highest first)
                    processList.sort((a, b) => b.vram - a.vram);
                    
                    root.processes = processList;
                }
            }
        }
    }
    
    function formatVram() {
        if (root.vramTotal < 1024) {
            return `${root.vramUsed.toFixed(0)}/${root.vramTotal.toFixed(0)} MiB`;
        } else {
            const usedGiB = (root.vramUsed / 1024).toFixed(1);
            const totalGiB = (root.vramTotal / 1024).toFixed(1);
            return `${usedGiB}/${totalGiB} GiB`;
        }
    }
    
    function getUsageColor(percent) {
        if (percent > 90) return Theme.tempDanger;
        if (percent > 70) return Theme.tempWarning;
        return Theme.primary;
    }

    // Helper to extract fields from /proc/[pid]/status
    function extractProcField(text, fieldName) {
        if (!text) return "";
        const lines = text.split("\n");
        for (let line of lines) {
            if (line.startsWith(fieldName + ":")) {
                return line.split(":")[1].trim();
            }
        }
        return "";
    }

    // Helper to format /proc/[pid]/cmdline (replaces null terminators with spaces)
    function formatCmdline(text) {
        if (!text) return "";
        return text.replace(/\0/g, " ").trim();
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            DankIcon { 
                name: "dashboard"
                size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: Theme.widgetIconColor
                anchors.verticalCenter: parent.verticalCenter 
            }
            Item {
                id: textBox
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: root.minimumWidth ? Math.max(textBaseline.width, gpuTextMeasure.width) : gpuTextMeasure.width
                implicitHeight: gpuText.implicitHeight
                width: implicitWidth; height: implicitHeight
                
                StyledTextMetrics { 
                    id: textBaseline
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    text: "88% | 8.8GiB" 
                }
                
                StyledTextMetrics {
                    id: gpuTextMeasure
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    text: gpuText.text
                }
                
                StyledText {
                    id: gpuText; anchors.fill: parent
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    text: `${root.gpuUsage.toFixed(0)}% | ${(root.vramUsed / 1024).toFixed(1)}GiB`
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 1

            DankIcon {
                name: "dashboard"
                size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                color: Theme.widgetIconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: `${root.gpuUsage.toFixed(0)}`
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                color: Theme.widgetTextColor
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }
    }

    // Popout content
    popoutContent: Component {
        PopoutComponent {
            id: popout
            
            Item {
                id: popoutContainer
                width: parent.width
                implicitHeight: popoutLoader.item ? popoutLoader.item.implicitHeight : 0

                Loader {
                    id: popoutLoader
                    width: parent.width
                    
                    sourceComponent: {
                        switch (root.popoutStyle) {
                            case "alt": return altStyleContent
                            case "dms": return dmsStyleContent
                            case "legacy": return legacyStyleContent
                            case "dmsExtended": return dmsExtendedStyleContent
                        }
                    }
                }

                DankContextMenu {
                    id: contextMenu
                    Component.onCompleted: root.contextMenuRef = contextMenu
                }

                // Global mouse area to close menu when clicking outside
                MouseArea {
                    anchors.fill: parent
                    enabled: contextMenu.visible
                    onPressed: contextMenu.hide()
                    z: 9998 
                }
            }
        }
    }

    // legacy style component
    Component {
        id: legacyStyleContent

        Column {
            width: parent.width
            spacing: Theme.spacingL

            Row {
                width: parent.width; spacing: 8; height: 24
                DankIcon { name: "memory"; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: root.gpuName; font.pixelSize: Theme.fontSizeLarge; font.bold: true; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
            }

            // GPU Usage
            Column {
                width: parent.width
                spacing: Theme.spacingS

                Row {
                    width: parent.width

                    StyledText {
                        width: parent.width - 50
                        text: "GPU Usage"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    StyledText {
                        text: `${root.gpuUsage.toFixed(1)}%`
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                    }
                }

                ProgressBar {
                    width: parent.width
                    barHeight: 12
                    barRadius: Theme.cornerRadius
                    value: root.gpuUsage
                    barColor: root.getUsageColor(root.gpuUsage)
                }
            }

            // VRAM Usage
            Column {
                width: parent.width
                spacing: Theme.spacingS

                Row {
                    width: parent.width

                    StyledText {
                        width: parent.width - 100
                        text: "VRAM Usage"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                    }

                    StyledText {
                        text: root.formatVram()
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                    }
                }

                ProgressBar {
                    width: parent.width
                    barHeight: 12
                    barRadius: Theme.cornerRadius
                    value: root.vramPercent
                    barColor: root.getUsageColor(root.vramPercent)
                }
            }

            Column {
                visible: root.gfxUsage > 0
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    text: "Engine Usage"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingL

                    StyledText {
                        text: `GFX: ${root.gfxUsage.toFixed(0)}%`
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    StyledText {
                        text: `MEM: ${root.memUsage.toFixed(0)}%`
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    StyledText {
                        text: `Media: ${root.mediaUsage.toFixed(0)}%`
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // Temperature & Power
            Row {
                width: parent.width
                spacing: Theme.spacingXL

                Column {
                    visible: root.temperature > 0
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "Temperature"
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    StyledText {
                        text: `${root.temperature}°C`
                        color: root.temperature > 80 ? Theme.error : Theme.surfaceText
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                    }
                }

                Column {
                    visible: root.powerUsage > 0
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "Power"
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    StyledText {
                        text: `${root.powerUsage}W`
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                    }
                }
            }

            // Process List
            Column {
                visible: root.processes.length > 0
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    text: `GPU Processes (${root.processes.length})`
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                }

                DankListView {
                    width: parent.width
                    height: Math.min(contentHeight, 250)
                    model: root.processes
                    spacing: 1
                    clip: true

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 50
                        color: Theme.surfaceContainer
                        radius: Theme.cornerRadius

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: {
                                if (mouse.button === Qt.RightButton && root.contextMenuRef) {
                                    let globalPos = mapToItem(root.contextMenuRef.parent, mouse.x, mouse.y);
                                    root.contextMenuRef.show(globalPos.x, globalPos.y, {
                                        pid: modelData.pid,
                                        name: modelData.name,
                                        cmdline: modelData.name
                                    }, false); // HIDDEN PID
                                }
                            }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: Theme.spacingM

                            Column {
                                width: 140
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    width: parent.width
                                    text: modelData.name
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: `PID: ${modelData.pid}`
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                }
                            }

                            Column {
                                width: 70
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: "VRAM"
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                }

                                StyledText {
                                    text: `${modelData.vram} ${modelData.vramUnit}`
                                    color: Theme.primary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                }
                            }

                            Column {
                                visible: modelData.gfx > 0
                                width: 50
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: "GPU"
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                }

                                StyledText {
                                    text: `${modelData.gfx}%`
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }

                            Column {
                                visible: modelData.cpu > 0
                                width: 50
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: "CPU"
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                }

                                StyledText {
                                    text: `${modelData.cpu}%`
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                        }
                    }
                }
            }
        }
    }

 // Alternative style
    Component {
        id: altStyleContent

        Column {
            width: parent.width
            spacing: Theme.spacingM

            // GPU Name Div
            Rectangle {
                width: parent.width
                height: 48
                radius: 16
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    spacing: 12
                    
                    DankIcon { 
                        name: "memory"
                        size: 20
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter 
                    }
                    
                    StyledText { 
                        text: root.gpuName
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter 
                    }
                }
            }

            // Main stats
            Row {
                width: parent.width
                spacing: Theme.spacingM

                StatCard {
                    width: (parent.width - Theme.spacingM) / 2
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) // Transparency added
                    iconName: "speed"
                    iconColor: Theme.primary
                    label: "GPU"
                    valueText: `${root.gpuUsage.toFixed(0)}%`
                    progressValue: root.gpuUsage
                }

                StatCard {
                    width: (parent.width - Theme.spacingM) / 2
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) // Transparency added
                    iconName: "memory"
                    iconColor: Theme.secondary
                    label: "VRAM"
                    valueText: `${(root.vramUsed / 1024).toFixed(1)} GiB`
                    progressValue: root.vramPercent
                }
            }

            // Temperature & Power Row
            Row {
                width: parent.width
                spacing: Theme.spacingS

                // Temperature chip
                Rectangle {
                    visible: root.temperature > 0
                    width: (parent.width - Theme.spacingS) / 2
                    height: 48
                    radius: 12
                    color: root.temperature > 80 ? Theme.withAlpha(Theme.errorHover, Theme.popupTransparency) : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "thermostat"
                            size: 22
                            color: root.temperature > 80 ? Theme.error : Theme.secondary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: `${root.temperature}°C`
                            color: root.temperature > 80 ? Theme.error : Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Power chip
                Rectangle {
                    visible: root.powerUsage > 0
                    width: (parent.width - Theme.spacingS) / 2
                    height: 48
                    radius: 12
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "bolt"
                            size: 22
                            color: Theme.secondary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: `${root.powerUsage}W`
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Engine activity section
            Rectangle {
                visible: root.gfxUsage > 0 || root.memUsage > 0 || root.mediaUsage > 0
                width: parent.width
                height: engineContent.height + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                Column {
                    id: engineContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    Row {
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "speed"
                            size: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Engine Activity"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    EngineBar {
                        width: parent.width
                        label: "GFX"
                        value: root.gfxUsage
                        barColor: Theme.primary
                    }

                    EngineBar {
                        width: parent.width
                        label: "MEM"
                        value: root.memUsage
                        barColor: Theme.secondary
                    }

                    EngineBar {
                        width: parent.width
                        label: "Media"
                        value: root.mediaUsage
                        barColor: Theme.info
                    }
                }
            }            // Process list section (Synced with DMS)
            Rectangle {
                visible: root.gfxUsage > 0 || root.memUsage > 0 || root.mediaUsage > 0
                width: parent.width
                height: altProcessItems.height + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                Column {
                    id: altProcessItems
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    Row {
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "apps"
                            size: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: `GPU Processes (${root.processes.length})`
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: Theme.spacingS; height: 1 }

                        DankIcon {
                            visible: !!root.toggleProcessList
                            name: "open_in_new"
                            size: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            opacity: altProcHeaderMouse.containsMouse ? 1 : 0.6
                            anchors.verticalCenter: parent.verticalCenter
                            
                            MouseArea {
                                id: altProcHeaderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleProcessList()
                            }
                        }
                    }

                    DankListView {
                        width: parent.width
                        height: Math.min(contentHeight, 220)
                        model: root.processes
                        spacing: 2
                        clip: true

                        delegate: Rectangle {
                            id: altProcDelegate
                            clip: true
                            width: ListView.view.width
                            height: 44
                            radius: Theme.cornerRadius
                            Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
                            color: altProcMouseArea.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                                : "transparent"
                            border.color: altProcMouseArea.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                : "transparent"
                            border.width: 1

                            DankRipple { id: altRipple; cornerRadius: parent.radius }

                            MouseArea {
                                id: altProcMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onPressed: altRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    if (mouse.button === Qt.RightButton && root.contextMenuRef) {
                                        let globalPos = mapToItem(root.contextMenuRef.parent, mouse.x, mouse.y);
                                        root.contextMenuRef.show(globalPos.x, globalPos.y, {
                                            pid: modelData.pid,
                                            name: modelData.name,
                                            cmdline: modelData.name
                                        }, false); // HIDDEN PID
                                    }
                                }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS

                                // Process name column
                                Item {
                                    width: parent.width - altVramBadge.width - altGfxBadge.width - altCpuBadge.width - Theme.spacingS * 3
                                    height: parent.height

                                    Row {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingS

                                        DankIcon {
                                            name: "terminal"
                                            size: Theme.iconSize - 4
                                            color: Theme.surfaceText
                                            opacity: 0.8
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter

                                            StyledText {
                                                text: modelData.name
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.surfaceText
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, 120)
                                            }
                                        }
                                    }
                                }

                                // VRAM badge
                                Rectangle {
                                    id: altVramBadge
                                    width: 95
                                    height: 24
                                    radius: Theme.cornerRadius
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        DankIcon {
                                            name: "memory"
                                            size: 12
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: `${modelData.vram} ${modelData.vramUnit}`
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            font.weight: Font.Bold
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                // GFX badge
                                Rectangle {
                                    id: altGfxBadge
                                    width: 64
                                    height: 24
                                    radius: Theme.cornerRadius
                                    color: modelData.gfx > 50
                                        ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                                        : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        DankIcon {
                                            name: "speed"
                                            size: 12
                                            color: modelData.gfx > 50 ? Theme.warning : Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: modelData.gfx > 0 ? `${modelData.gfx}%` : "—"
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            font.weight: Font.Bold
                                            color: modelData.gfx > 50 ? Theme.warning : Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                // CPU badge
                                Rectangle {
                                    id: altCpuBadge
                                    width: 64
                                    height: 24
                                    radius: Theme.cornerRadius
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        DankIcon {
                                            name: "developer_board"
                                            size: 12
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: modelData.cpu > 0 ? `${modelData.cpu}%` : "—"
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            font.weight: Font.Bold
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // DMS style (matches ProcessListPopout aesthetic)
    Component {
        id: dmsStyleContent

        Column {
            width: parent.width
            spacing: Theme.spacingM

            // GPU Name Div
            Rectangle {
                width: parent.width
                height: 48
                radius: 16
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    spacing: 12
                    
                    DankIcon { 
                        name: "memory"
                        size: 20
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter 
                    }
                    
                    StyledText { 
                        text: root.gpuName
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter 
                    }
                }
            }

            // Gauges row
            Item {
                id: gaugeRowHost
                width: parent.width
                height: gaugesRow.height
                readonly property real gaugeSize: Theme.fontSizeMedium * 6.5
                readonly property real gaugePadding: Math.max(6, Math.round(gaugeSize * 0.08))

                Row {
                    id: gaugesRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    Item {
                        width: gaugeRowHost.gaugeSize + gaugeRowHost.gaugePadding * 2
                        height: gaugeRowHost.gaugeSize + gaugeRowHost.gaugePadding * 2

                        CircleGauge {
                            anchors.centerIn: parent
                            width: gaugeRowHost.gaugeSize
                            height: gaugeRowHost.gaugeSize
                            value: root.gpuUsage / 100
                            label: root.gpuUsage.toFixed(0) + "%"
                            sublabel: "GPU"
                            accentColor: root.getUsageColor(root.gpuUsage)
                        }
                    }

                    Item {
                        width: gaugeRowHost.gaugeSize + gaugeRowHost.gaugePadding * 2
                        height: gaugeRowHost.gaugeSize + gaugeRowHost.gaugePadding * 2

                        CircleGauge {
                            anchors.centerIn: parent
                            width: gaugeRowHost.gaugeSize
                            height: gaugeRowHost.gaugeSize
                            value: root.vramPercent / 100
                            label: (root.vramUsed / 1024).toFixed(1) + " GiB"
                            sublabel: "VRAM"
                            detail: root.vramPercent.toFixed(0) + "%"
                            accentColor: root.getUsageColor(root.vramPercent)
                        }
                    }

                    Item {
                        visible: root.temperature > 0
                        width: gaugeRowHost.gaugeSize + gaugeRowHost.gaugePadding * 2
                        height: gaugeRowHost.gaugeSize + gaugeRowHost.gaugePadding * 2

                        CircleGauge {
                            anchors.centerIn: parent
                            width: gaugeRowHost.gaugeSize
                            height: gaugeRowHost.gaugeSize
                            value: Math.min(1, root.temperature / 100)
                            label: root.temperature + "°C"
                            sublabel: "Temp"
                            detail: root.powerUsage > 0 ? (root.powerUsage + "W") : ""
                            accentColor: root.temperature > 85 ? Theme.tempDanger : (root.temperature > 70 ? Theme.tempWarning : Theme.info)
                            detailColor: Theme.surfaceVariantText
                        }
                    }
                }
            }

            // Engine activity section
            Rectangle {
                width: parent.width
                height: engineContent.height + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                Column {
                    id: engineContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    Row {
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "speed"
                            size: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Engine Activity"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    EngineBar {
                        width: parent.width
                        label: "GFX"
                        value: root.gfxUsage
                        barColor: Theme.primary
                    }

                    EngineBar {
                        width: parent.width
                        label: "MEM"
                        value: root.memUsage
                        barColor: Theme.secondary
                    }

                    EngineBar {
                        width: parent.width
                        label: "Media"
                        value: root.mediaUsage
                        barColor: Theme.info
                    }
                }
            }

            // Process list section
            Rectangle {
                width: parent.width
                height: processContent.height + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                Column {
                    id: processContent
                    anchors.left: parent.left

                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    Row {
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "apps"
                            size: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: `GPU Processes (${root.processes.length})`
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: Theme.spacingS; height: 1 }

                        DankIcon {
                            visible: !!root.toggleProcessList
                            name: "open_in_new"
                            size: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            opacity: procHeaderMouse.containsMouse ? 1 : 0.6
                            anchors.verticalCenter: parent.verticalCenter
                            
                            MouseArea {
                                id: procHeaderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleProcessList()
                            }
                        }
                    }

                    DankListView {
                        width: parent.width
                        height: Math.min(contentHeight, 220)
                        model: root.processes
                        spacing: 2
                        clip: true

                        delegate: Rectangle {
                            id: procStyleDelegate
                            clip: true
                            width: ListView.view.width
                            height: 44
                            radius: Theme.cornerRadius
                            Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
                            color: dmsProcMouseArea.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                                : "transparent"
                            border.color: dmsProcMouseArea.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                : "transparent"
                            border.width: 1

                            DankRipple { id: dmsRipple; cornerRadius: parent.radius }

                            MouseArea {
                                id: dmsProcMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onPressed: dmsRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    if (mouse.button === Qt.RightButton && root.contextMenuRef) {
                                        let globalPos = mapToItem(root.contextMenuRef.parent, mouse.x, mouse.y);
                                        root.contextMenuRef.show(globalPos.x, globalPos.y, {
                                            pid: modelData.pid,
                                            name: modelData.name,
                                            cmdline: modelData.name
                                        }, false); // HIDDEN PID
                                    }
                                }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS

                                // Process name column
                                Item {
                                    id: processNameCell
                                    width: parent.width - vramBadge.width - gfxBadge.width - cpuBadge.width - Theme.spacingS * 3
                                    height: parent.height
                                    clip: true

                                    Row {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingS

                                        DankIcon {
                                            id: processNameIcon
                                            name: "terminal"
                                            size: Theme.iconSize - 4
                                            color: Theme.surfaceText
                                            opacity: 0.8
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Column {
                                            width: Math.max(0, processNameCell.width - processNameIcon.width - Theme.spacingS)
                                            anchors.verticalCenter: parent.verticalCenter

                                            StyledText {
                                                text: modelData.name
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.surfaceText
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }
                                    }
                                }

                                // VRAM badge
                                Rectangle {
                                    id: vramBadge
                                    width: 95
                                    height: 24
                                    radius: Theme.cornerRadius
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        DankIcon {
                                            name: "memory"
                                            size: 12
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: `${modelData.vram} ${modelData.vramUnit}`
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            font.weight: Font.Bold
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                // GFX badge
                                Rectangle {
                                    id: gfxBadge
                                    width: 64
                                    height: 24
                                    radius: Theme.cornerRadius
                                    color: modelData.gfx > 50
                                        ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                                        : Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        DankIcon {
                                            name: "speed"
                                            size: 12
                                            color: modelData.gfx > 50 ? Theme.warning : Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: modelData.gfx > 0 ? `${modelData.gfx}%` : "—"
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            font.weight: Font.Bold
                                            color: modelData.gfx > 50 ? Theme.warning : Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                // CPU badge
                                Rectangle {
                                    id: cpuBadge
                                    width: 64
                                    height: 24
                                    radius: Theme.cornerRadius
                                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        DankIcon {
                                            name: "developer_board"
                                            size: 12
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: modelData.cpu > 0 ? `${modelData.cpu}%` : "—"
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            font.weight: Font.Bold
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                            }
                        }
                    }
                }
            }
        }
    }


    // ==========================================
    // DMS EXTENDED STYLE (Advanced Dashboard)
    // ==========================================
    Component {
        id: dmsExtendedStyleContent

        Column {
            id: rootColumn
            width: parent.width
            spacing: Theme.spacingL

            // Ensures search grabs focus whenever the dashboard becomes visible
            onVisibleChanged: {
                if (visible) searchInput.forceActiveFocus()
            }

            // 1. TOP HEADER: TITLE, FILTER PILLS, SEARCH BAR
            Item {
                width: parent.width
                height: 44 

                Row {
                    id: leftControls
                    height: parent.height
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingL

                    Row {
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        DankIcon { name: "dashboard"; size: 24; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Processes"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                        
                        Item { width: Theme.spacingS; height: 1 }

                        DankIcon {
                            visible: !!root.toggleProcessList
                            name: "open_in_new"
                            size: 20
                            color: Theme.primary
                            opacity: extendedProcHeaderMouse.containsMouse ? 1 : 0.6
                            anchors.verticalCenter: parent.verticalCenter
                            
                            MouseArea {
                                id: extendedProcHeaderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleProcessList()
                            }
                        }
                    }

                    // Native DankButtonGroup
                    DankButtonGroup {
                        id: processFilters
                        anchors.verticalCenter: parent.verticalCenter
                        width: 230 
                        buttonHeight: 36 
                        
                        scale: 0.85 
                        transformOrigin: Item.Left
                        
                        checkEnabled: false 
                        model: ["All", "User", "System"]
                        currentIndex: 0
                        onSelectionChanged: function(index, selected) {
                            if (selected) {
                                processFilters.currentIndex = index;
                                processSection.filterMode = index;
                            }
                        }
                    }
                }

                // SEARCH BAR WITH PERSISTENT FOCUS
                Item {
                    anchors.left: leftControls.right
                    anchors.leftMargin: Theme.spacingS 
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 40 

                    DankTextField {
                        id: searchInput
                        anchors.fill: parent
                        leftIconName: "search"
                        leftIconColor: Theme.primary
                        leftIconFocusedColor: Theme.primary
                        
                        placeholderText: "Search processes or PIDs..."
                        onTextChanged: processSection.searchText = text.trim()
                        
                        focus: true
                        Component.onCompleted: searchInput.forceActiveFocus()
                        
                        onActiveFocusChanged: {
                            if (!activeFocus && rootColumn.visible) {
                                searchInput.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // 2. HERO CARD & GAUGES
            Item {
                width: parent.width
                height: 90 
                
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingL
                    
                    Rectangle {
                        width: 70; height: 70; radius: 16 
                        color: Theme.withAlpha(Theme.primary, 0.15) 

                        Image {
                            id: customHeroImage
                            visible: root.customHeroIcon !== ""
                            anchors.fill: parent
                            anchors.margins: {
                                const size = parseInt(root.customHeroIconSize) || 46;
                                return Math.max(0, (70 - size) / 2);
                            }
                            sourceSize: Qt.size(140, 140) 
                            source: root.customHeroIcon ? (root.customHeroIcon.startsWith("http") || root.customHeroIcon.startsWith("file://") ? root.customHeroIcon : "file://" + root.customHeroIcon) : ""
                            fillMode: Image.PreserveAspectFit
                            mipmap: true
                            asynchronous: true
                            
                            layer.enabled: true
                            layer.effect: DropShadow {
                                transparentBorder: true
                                horizontalOffset: 1
                                verticalOffset: 2
                                radius: 4.0
                                samples: 12
                                color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.45)
                            }
                        }
                        
                        DankIcon { 
                            visible: root.customHeroIcon === ""
                            name: "developer_board"
                            size: 34
                            anchors.centerIn: parent
                            color: Theme.primary 
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        StyledText { text: "GPU"; font.pixelSize: Theme.fontSizeLarge * 1.2; font.weight: Font.Bold; color: Theme.surfaceText } 
                        StyledText { text: root.gpuName; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        Row {
                            spacing: Theme.spacingS
                            DankIcon { name: "memory"; size: 12; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: root.processes.length + " procs"; font.pixelSize: Theme.fontSizeSmall - 1; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingL 
                    
                    CircleGauge { 
                        width: 80; height: 80 
                        value: root.gpuUsage / 100
                        label: root.gpuUsage.toFixed(0) + "%"
                        sublabel: "GPU"
                        accentColor: root.getUsageColor(root.gpuUsage) 
                    }
                    
                    CircleGauge { 
                        width: 80; height: 80 
                        value: root.vramPercent / 100
                        label: (root.vramUsed / 1024).toFixed(1) + " GB"
                        sublabel: "Memory"
                        accentColor: root.getUsageColor(root.vramPercent) 
                    }

                    CircleGauge { 
                        visible: root.temperature > 0
                        width: 80; height: 80 
                        value: Math.min(1, root.temperature / 100)
                        label: root.temperature + "°C"
                        sublabel: "Temp"
                        detail: root.powerUsage > 0 ? (root.powerUsage + "W") : ""
                        accentColor: root.temperature > 85 ? Theme.tempDanger : (root.temperature > 70 ? Theme.tempWarning : Theme.info)
                    }
                }
            }

            // 3. ENGINE ACTIVITY SECTION
            Rectangle {
                visible: root.gfxUsage > 0 || root.memUsage > 0 || root.mediaUsage > 0
                width: parent.width
                height: engineContent.height + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                Column {
                    id: engineContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    Row {
                        spacing: Theme.spacingS
                        DankIcon { name: "speed"; size: Theme.fontSizeSmall; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Engine Activity"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceVariantText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    EngineBar { width: parent.width; label: "GFX"; value: root.gfxUsage; barColor: Theme.primary }
                    EngineBar { width: parent.width; label: "MEM"; value: root.memUsage; barColor: Theme.secondary }
                    EngineBar { width: parent.width; label: "Media"; value: root.mediaUsage; barColor: Theme.info }
                }
            }

            // 4. PROCESS LIST SECTION
            Rectangle {
                id: processSection
                width: parent.width
                height: 380 
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                
                FileView { id: cmdViewExt; path: "/proc/" + processSection.expandedPid + "/cmdline" }
                FileView { id: statViewExt; path: "/proc/" + processSection.expandedPid + "/status" }
                FileView { id: memInfoView; path: "/proc/meminfo" }

                property real usableW: width - (Theme.spacingM * 2)

                property real nameW: (usableW - 24) * 0.5   
                property real statW: (usableW - 24) * 0.5 / 3 

                property string sortCol: "name"
                property bool sortAsc: true 
                property string searchText: ""
                property int filterMode: 0 
                property int matchCount: 0
                property int expandedPid: -1

                signal triggerRecalc()

                onSortColChanged: triggerRecalc()
                onSortAscChanged: triggerRecalc()
                onFilterModeChanged: triggerRecalc()
                onSearchTextChanged: triggerRecalc()

                ListModel { id: stableModel }

                function syncData() {
                    let pList = root.processes || [];
                    for(let i=0; i<stableModel.count; i++) stableModel.setProperty(i, "visited", false);
                    
                    for(let i=0; i<pList.length; i++) {
                        let p = pList[i];
                        let found = false;
                        for(let j=0; j<stableModel.count; j++) {
                            if(stableModel.get(j).pid === p.pid) {
                                stableModel.setProperty(j, "gfx", p.gfx);
                                stableModel.setProperty(j, "vram", p.vram);
                                stableModel.setProperty(j, "visited", true);
                                found = true;
                                break;
                            }
                        }
                        if(!found) {
                            stableModel.append({
                                name: p.name,
                                pid: p.pid,
                                vram: p.vram,
                                vramUnit: p.vramUnit,
                                gfx: p.gfx,
                                visited: true
                            });
                        }
                    }
                    
                    for(let i=stableModel.count-1; i>=0; i--) {
                        if(stableModel.get(i).visited === false) stableModel.remove(i);
                    }
                    
                    let count = 0;
                    let systemProcs = ["xorg", "xwayland", "wayland", "kwin", "kwin_wayland", "kwin_x11", "niri", "hyprland", "plasmashell", "sddm", "gdm", "systemd"];
                    for(let i=0; i<stableModel.count; i++) {
                        let p = stableModel.get(i);
                        let isSys = systemProcs.some(sys => p.name.toLowerCase().includes(sys));
                        let mFilter = processSection.filterMode === 0 || (processSection.filterMode === 1 && !isSys) || (processSection.filterMode === 2 && isSys);
                        let mSearch = processSection.searchText === "" || p.name.toLowerCase().includes(processSection.searchText.toLowerCase()) || p.pid.toString().includes(processSection.searchText);
                        if (mFilter && mSearch) count++;
                    }
                    processSection.matchCount = count;
                    processSection.triggerRecalc();
                }

                Connections {
                    target: root
                    function onProcessesChanged() { processSection.syncData(); }
                }
                Component.onCompleted: processSection.syncData()

                Item {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM

                    // TABLE HEADER
                    Item {
                        id: tableHeader 
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 36
                        z: 10 

                        Rectangle {
                            id: highlightPill
                            height: 32
                            anchors.verticalCenter: parent.verticalCenter
                            radius: Theme.cornerRadius
                            color: Theme.withAlpha(Theme.primary, 0.15)
                            
                            x: {
                                if (processSection.sortCol === "name") return nameCol.x;
                                if (processSection.sortCol === "gpu") return rightCols.x + gpuCol.x;
                                if (processSection.sortCol === "vram") return rightCols.x + vramCol.x;
                                if (processSection.sortCol === "pid") return rightCols.x + pidCol.x;
                                return 0;
                            }
                            
                            width: {
                                if (processSection.sortCol === "name") return nameCol.width - 4;
                                if (processSection.sortCol === "gpu") return gpuCol.width - 4;
                                if (processSection.sortCol === "vram") return vramCol.width - 4;
                                if (processSection.sortCol === "pid") return pidCol.width - 4;
                                return 0;
                            }
                            
                            Behavior on x { NumberAnimation { duration: Theme.longDuration; easing.type: Theme.standardEasing } }
                            Behavior on width { NumberAnimation { duration: Theme.longDuration; easing.type: Theme.standardEasing } }
                        }

                        Row {
                            anchors.fill: parent
                            
                            Item {
                                id: nameCol
                                width: processSection.nameW
                                height: parent.height

                                property bool isSettled: false
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 2; radius: Theme.cornerRadius
                                    // FIX: Border opacity reduced to match the fill strength
                                    border.color: nameHeaderArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.25) : "transparent"
                                    border.width: 1
                                    color: nameHeaderArea.containsMouse && parent.isSettled ? Theme.withAlpha(Theme.primary, 0.12) : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                }
                                Timer { running: nameHeaderArea.containsMouse; interval: 150; onTriggered: nameCol.isSettled = true }

                                MouseArea {
                                    id: nameHeaderArea
                                    anchors.fill: parent; hoverEnabled: true
                                    onExited: nameCol.isSettled = false
                                    onClicked: {
                                        if (processSection.sortCol === "name") processSection.sortAsc = !processSection.sortAsc;
                                        else { processSection.sortCol = "name"; processSection.sortAsc = true; }
                                    }
                                }
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    StyledText { 
                                        text: "Name"
                                        font.pixelSize: Theme.fontSizeSmall 
                                        // FIX: Use Font.Black for heavy boldness
                                        font.weight: processSection.sortCol === "name" ? Font.Black : Font.Medium
                                        color: processSection.sortCol === "name" ? Theme.primary : Theme.surfaceVariantText 
                                    }
                                    Item {
                                        width: 16; height: 16 
                                        DankIcon { 
                                            anchors.centerIn: parent
                                            name: "arrow_downward"
                                            size: 16 
                                            color: Theme.primary 
                                            opacity: processSection.sortCol === "name" ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } } 
                                            rotation: processSection.sortAsc ? 180 : 0
                                            Behavior on rotation { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.standardEasing } }
                                        }
                                    }
                                }
                            }
                            
                            Row {
                                id: rightCols
                                width: parent.width * 0.5 - 24
                                height: parent.height

                                Item {
                                    id: gpuCol
                                    width: processSection.statW
                                    height: parent.height

                                    property bool isSettled: false
                                    Rectangle {
                                        anchors.fill: parent; anchors.margins: 2; radius: Theme.cornerRadius
                                        border.color: gpuHeaderArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.25) : "transparent"
                                        border.width: 1
                                        color: gpuHeaderArea.containsMouse && parent.isSettled ? Theme.withAlpha(Theme.primary, 0.12) : "transparent"
                                        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                    }
                                    Timer { running: gpuHeaderArea.containsMouse; interval: 150; onTriggered: gpuCol.isSettled = true }

                                    MouseArea {
                                        id: gpuHeaderArea
                                        anchors.fill: parent; hoverEnabled: true
                                        onExited: gpuCol.isSettled = false
                                        onClicked: {
                                            if (processSection.sortCol === "gpu") processSection.sortAsc = !processSection.sortAsc;
                                            else { processSection.sortCol = "gpu"; processSection.sortAsc = false; }
                                        }
                                    }
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        StyledText { 
                                            text: "GPU"
                                            font.pixelSize: Theme.fontSizeSmall 
                                            font.weight: processSection.sortCol === "gpu" ? Font.Black : Font.Medium
                                            color: processSection.sortCol === "gpu" ? Theme.primary : Theme.surfaceVariantText 
                                        }
                                        Item {
                                            width: 16; height: 16
                                            DankIcon { 
                                                anchors.centerIn: parent
                                                name: "arrow_downward"
                                                size: 16 
                                                color: Theme.primary 
                                                opacity: processSection.sortCol === "gpu" ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                                                rotation: processSection.sortAsc ? 180 : 0
                                                Behavior on rotation { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.standardEasing } }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    id: vramCol
                                    width: processSection.statW
                                    height: parent.height

                                    property bool isSettled: false
                                    Rectangle {
                                        anchors.fill: parent; anchors.margins: 2; radius: Theme.cornerRadius
                                        border.color: vramHeaderArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.25) : "transparent"
                                        border.width: 1
                                        color: vramHeaderArea.containsMouse && parent.isSettled ? Theme.withAlpha(Theme.primary, 0.12) : "transparent"
                                        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                    }
                                    Timer { running: vramHeaderArea.containsMouse; interval: 150; onTriggered: vramCol.isSettled = true }

                                    MouseArea {
                                        id: vramHeaderArea
                                        anchors.fill: parent; hoverEnabled: true
                                        onExited: vramCol.isSettled = false
                                        onClicked: {
                                            if (processSection.sortCol === "vram") processSection.sortAsc = !processSection.sortAsc;
                                            else { processSection.sortCol = "vram"; processSection.sortAsc = false; }
                                        }
                                    }
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        StyledText { 
                                            text: "Memory"
                                            font.pixelSize: Theme.fontSizeSmall 
                                            font.weight: processSection.sortCol === "vram" ? Font.Black : Font.Medium
                                            color: processSection.sortCol === "vram" ? Theme.primary : Theme.surfaceVariantText 
                                        }
                                        Item {
                                            width: 16; height: 16
                                            DankIcon { 
                                                anchors.centerIn: parent
                                                name: "arrow_downward"
                                                size: 16 
                                                color: Theme.primary 
                                                opacity: processSection.sortCol === "vram" ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                                                rotation: processSection.sortAsc ? 180 : 0
                                                Behavior on rotation { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.standardEasing } }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    id: pidCol
                                    width: processSection.statW
                                    height: parent.height

                                    property bool isSettled: false
                                    Rectangle {
                                        anchors.fill: parent; anchors.margins: 2; radius: Theme.cornerRadius
                                        border.color: pidHeaderArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.25) : "transparent"
                                        border.width: 1
                                        color: pidHeaderArea.containsMouse && parent.isSettled ? Theme.withAlpha(Theme.primary, 0.12) : "transparent"
                                        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                    }
                                    Timer { running: pidHeaderArea.containsMouse; interval: 150; onTriggered: pidCol.isSettled = true }

                                    MouseArea {
                                        id: pidHeaderArea
                                        anchors.fill: parent; hoverEnabled: true
                                        onExited: pidCol.isSettled = false
                                        onClicked: {
                                            if (processSection.sortCol === "pid") processSection.sortAsc = !processSection.sortAsc;
                                            else { processSection.sortCol = "pid"; processSection.sortAsc = true; }
                                        }
                                    }
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        StyledText { 
                                            text: "PID"
                                            font.pixelSize: Theme.fontSizeSmall 
                                            font.weight: processSection.sortCol === "pid" ? Font.Black : Font.Medium
                                            color: processSection.sortCol === "pid" ? Theme.primary : Theme.surfaceVariantText 
                                        }
                                        Item {
                                            width: 16; height: 16
                                            DankIcon { 
                                                anchors.centerIn: parent
                                                name: "arrow_downward"
                                                size: 16 
                                                color: Theme.primary 
                                                opacity: processSection.sortCol === "pid" ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }
                                                rotation: processSection.sortAsc ? 180 : 0
                                                Behavior on rotation { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.standardEasing } }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Item { width: 24; height: parent.height } 
                        }
                    }

                    // GLIDING LIST VIEW
                    ListView {
                        id: processListView
                        anchors.top: tableHeader.bottom
                        anchors.topMargin: Theme.spacingM
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        clip: true
                        model: stableModel
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: procDelegate
                            width: ListView.view.width
                            radius: Theme.cornerRadius
                            clip: true
                            readonly property bool isExpanded: processSection.expandedPid === model.pid
                            

                            // Match official DMS height logic
                            height: isMatch ? (isExpanded ? (48 + expandedRect.height + Theme.spacingXS) : 48) : 0
                            opacity: isMatch ? 1 : 0
                            visible: height > 0

                            Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
                            Behavior on opacity { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }

                            property bool isSettled: false
                            border.color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : (procMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.25) : "transparent")
                            border.width: 1
                            color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : (procMouseArea.containsMouse && isSettled ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent")
                            readonly property bool isSelected: processSection.expandedPid === model.pid // Official matches expanded to "selected" visual

                            Timer { running: procMouseArea.containsMouse; interval: 150; onTriggered: procDelegate.isSettled = true }
                            
                            Behavior on color { ColorAnimation { duration: 250 } }

                            DankRipple { id: extRipple; cornerRadius: parent.radius }

                            property int visualIndex: -1
                            property bool isMatch: false

                            function computeRank() {
                                let myP = stableModel.get(index);
                                if (!myP) return;

                                let systemProcs = ["xorg", "xwayland", "wayland", "kwin", "kwin_wayland", "kwin_x11", "niri", "hyprland", "plasmashell", "sddm", "gdm", "systemd"];
                                let myIsSys = systemProcs.some(sys => myP.name.toLowerCase().includes(sys));
                                let myMatchF = processSection.filterMode === 0 || (processSection.filterMode === 1 && !myIsSys) || (processSection.filterMode === 2 && myIsSys);
                                let myMatchS = processSection.searchText === "" || myP.name.toLowerCase().includes(processSection.searchText.toLowerCase()) || myP.pid.toString().includes(processSection.searchText);
                                
                                isMatch = myMatchF && myMatchS;
                                
                                if (!isMatch) {
                                    visualIndex = -1;
                                    return;
                                }

                                let rank = 0;
                                let myVal;
                                if (processSection.sortCol === "name") myVal = myP.name.toLowerCase();
                                else if (processSection.sortCol === "gpu") myVal = myP.gfx;
                                else if (processSection.sortCol === "vram") myVal = myP.vram * (myP.vramUnit === "GiB" ? 1024 : 1);
                                else if (processSection.sortCol === "pid") myVal = myP.pid;

                                for (let i = 0; i < stableModel.count; i++) {
                                    if (i === index) continue;
                                    let otherP = stableModel.get(i);
                                    
                                    let otherIsSys = systemProcs.some(sys => otherP.name.toLowerCase().includes(sys));
                                    let otherMatchF = processSection.filterMode === 0 || (processSection.filterMode === 1 && !otherIsSys) || (processSection.filterMode === 2 && otherIsSys);
                                    let otherMatchS = processSection.searchText === "" || otherP.name.toLowerCase().includes(processSection.searchText.toLowerCase()) || otherP.pid.toString().includes(processSection.searchText);
                                    
                                    if (otherMatchF && otherMatchS) {
                                        let otherVal;
                                        if (processSection.sortCol === "name") otherVal = otherP.name.toLowerCase();
                                        else if (processSection.sortCol === "gpu") otherVal = otherP.gfx;
                                        else if (processSection.sortCol === "vram") otherVal = otherP.vram * (otherP.vramUnit === "GiB" ? 1024 : 1);
                                        else if (processSection.sortCol === "pid") otherVal = otherP.pid;

                                        let isSmaller;
                                        if (processSection.sortCol === "name") isSmaller = myVal < otherVal;
                                        else isSmaller = myVal > otherVal;

                                        if (processSection.sortAsc) isSmaller = !isSmaller;

                                        if (isSmaller) rank++;
                                        else if (myVal === otherVal && index > i) rank++; 
                                    }
                                }
                                visualIndex = rank;
                            }

                            Connections {
                                target: processSection
                                function onTriggerRecalc() { computeRank(); }
                            }
                            Component.onCompleted: {
                                computeRank();
                            }

                            MouseArea {
                                id: procMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onExited: procDelegate.isSettled = false
                                onPressed: extRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    if (mouse.button === Qt.RightButton && root.contextMenuRef) {
                                        let globalPos = mapToItem(root.contextMenuRef.parent, mouse.x, mouse.y);
                                        root.contextMenuRef.show(globalPos.x, globalPos.y, {
                                            pid: model.pid,
                                            name: model.name,
                                            cmdline: root.formatCmdline(cmdViewExt.text()) || model.name
                                        });
                                    } else {
                                        processSection.expandedPid = isExpanded ? -1 : model.pid
                                    }
                                }
                            }
                            Row {
                                width: parent.width
                                height: 48

                                Item {
                                    width: processSection.nameW
                                    height: parent.height
                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 12
                                        
                                        DankIcon { 
                                            name: "developer_board" 
                                            size: 16 
                                            color: Theme.surfaceVariantText
                                            anchors.verticalCenter: parent.verticalCenter 
                                        }
                                        
                                        StyledText { 
                                            text: model.name
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            font.weight: Font.Medium
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: Math.min(implicitWidth, processSection.nameW - 40)
                                            anchors.verticalCenter: parent.verticalCenter 
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width * 0.5 - 24
                                    height: parent.height

                                    Item {
                                        width: processSection.statW
                                        height: parent.height
                                        Rectangle {
                                            width: 70; height: 24; radius: Theme.cornerRadius
                                            anchors.centerIn: parent
                                            color: Theme.withAlpha(root.getUsageColor(model.gfx), 0.15)
                                            StyledText {
                                                anchors.centerIn: parent
                                                text: model.gfx > 0 ? `${model.gfx.toFixed(0)}%` : "0%"
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                font.weight: Font.Bold
                                                color: root.getUsageColor(model.gfx)
                                            }
                                        }
                                    }

                                    Item {
                                        width: processSection.statW
                                        height: parent.height
                                        Rectangle {
                                            width: 70; height: 24; radius: Theme.cornerRadius
                                            anchors.centerIn: parent
                                            property real procVramPercent: root.vramTotal > 0 ? ((model.vramUnit === "GiB" ? model.vram * 1024 : model.vram) / root.vramTotal * 100) : 0
                                            color: Theme.withAlpha(root.getUsageColor(procVramPercent), 0.15)
                                            StyledText {
                                                anchors.centerIn: parent
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                font.weight: Font.Bold
                                                text: {
                                                    let v = model.vram;
                                                    let u = model.vramUnit;
                                                    if (u === "MiB" && v > 1000) return (v / 1024).toFixed(1) + " GB";
                                                    return v + " " + (u === "MiB" ? "MB" : "GB");
                                                }
                                                color: root.getUsageColor(parent.procVramPercent)
                                            }
                                        }
                                    }

                                    Item {
                                        width: processSection.statW
                                        height: parent.height
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: model.pid
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }

                                Item {
                                    width: 24
                                    height: parent.height
                                    DankIcon {
                                        name: "expand_more"
                                        size: 18
                                        color: procDelegate.isExpanded ? Theme.primary : Theme.surfaceVariantText
                                        anchors.centerIn: parent
                                        rotation: procDelegate.isExpanded ? 180 : 0
                                        Behavior on rotation { NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.standardEasing } }
                                        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                                    }
                                }
                            }

                            // Details Section - MATCHING OFFICIAL DMS STYLE
                            Rectangle {
                                id: expandedRect
                                width: parent.width - Theme.spacingM * 2
                                height: procDelegate.isExpanded ? (expandedContent.implicitHeight + Theme.spacingS * 2) : 0
                                anchors.top: parent.top
                                anchors.topMargin: 48
                                anchors.horizontalCenter: parent.horizontalCenter
                                radius: Theme.cornerRadius - 2
                                color: Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, 0.6)
                                clip: true
                                visible: procDelegate.isExpanded
                                
                                Behavior on height { NumberAnimation { duration: Theme.shortDuration; easing.type: Theme.standardEasing } }
                                opacity: procDelegate.isExpanded ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }

                                Column {
                                    id: expandedContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingXS

                                    // Full Command Row
                                    RowLayout {
                                        width: parent.width
                                        spacing: Theme.spacingS
                                        
                                        StyledText {
                                            text: "Full Command:"
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            font.weight: Font.Bold
                                            color: Theme.surfaceVariantText
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        StyledText {
                                            id: cmdText
                                            Layout.fillWidth: true
                                            text: root.formatCmdline(cmdViewExt.text()) || model.name
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            font.family: "Monospace"
                                            color: Theme.surfaceText
                                            elide: Text.ElideMiddle
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Rectangle {
                                            id: copyBtn
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            radius: Theme.cornerRadius - 2
                                            color: copyMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                                            Layout.alignment: Qt.AlignVCenter
                                            
                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: "content_copy"
                                                size: 14
                                                color: copyMouseArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                            }

                                            MouseArea {
                                                id: copyMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    try {
                                                        Quickshell.execDetached(["dms", "cl", "copy", cmdText.text]);
                                                    } catch(e) {
                                                        console.log("Clipboard copy failed:", e);
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // System Stats Row
                                    Row {
                                        spacing: Theme.spacingL
                                        height: childrenRect.height
                                        
                                        Row {
                                            spacing: Theme.spacingXS
                                            anchors.verticalCenter: parent.verticalCenter
                                            StyledText {
                                                text: "PPID:"
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                font.weight: Font.Bold
                                                color: Theme.surfaceVariantText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            StyledText {
                                                text: root.extractProcField(statViewExt.text(), "PPid") || "--"
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                font.family: "Monospace"
                                                color: Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        Row {
                                            spacing: Theme.spacingXS
                                            anchors.verticalCenter: parent.verticalCenter
                                            StyledText {
                                                text: "Mem:"
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                font.weight: Font.Bold
                                                color: Theme.surfaceVariantText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            StyledText {
                                                property string vmRss: root.extractProcField(statViewExt.text(), "VmRSS")
                                                text: {
                                                    if (!vmRss) return "--%";
                                                    let rssKb = parseInt(vmRss.replace(/[^0-9]/g, ""));
                                                    if (isNaN(rssKb)) return "--%";
                                                    let memTotalStr = root.extractProcField(memInfoView.text(), "MemTotal");
                                                    let memTotalKb = parseInt(memTotalStr.replace(/[^0-9]/g, ""));
                                                    if (isNaN(memTotalKb) || memTotalKb === 0) return "--%";
                                                    let pct = (rssKb / memTotalKb * 100).toFixed(1);
                                                    return pct + "%";
                                                }
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                font.family: "Monospace"
                                                color: Theme.surfaceText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // EMPTY STATE (FIXED TIMING)
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM
                        opacity: processSection.matchCount === 0 ? 1 : 0
                        
                        Behavior on opacity { 
                            NumberAnimation { 
                                duration: processSection.matchCount === 0 ? 150 : 0 
                                easing.type: Easing.InOutQuad 
                            } 
                        }

                        DankIcon { name: "search_off"; size: 36; color: Theme.surfaceVariantText; anchors.horizontalCenter: parent.horizontalCenter }
                        StyledText { text: "No matching processes"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }

        }
    }

    // -----------

    // CircleGauge component (matching ProcessListPopout style)
    component CircleGauge: Item {
        id: gaugeRoot

        property real value: 0
        property string label: ""
        property string sublabel: ""
        property string detail: ""
        property color accentColor: Theme.primary
        property color detailColor: Theme.surfaceVariantText

        readonly property real thickness: Math.max(4, Math.min(width, height) / 15)
        readonly property real glowExtra: thickness * 1.4
        readonly property real arcPadding: thickness / 1.3
        readonly property real glowStrokeWidth: thickness + glowExtra
        readonly property real ringRadius: Math.max(0, (Math.min(width, height) / 2) - arcPadding)
        readonly property real canvasOverflow: Math.max(0, (glowStrokeWidth / 2) - arcPadding + 1)

        readonly property real innerDiameter: width - (arcPadding + thickness + glowExtra) * 2
        readonly property real maxTextWidth: innerDiameter * 0.9
        readonly property real baseLabelSize: Math.round(width * 0.18)
        readonly property real labelSize: Math.round(Math.min(baseLabelSize, maxTextWidth / Math.max(1, label.length * 0.65)))
        readonly property real sublabelSize: Math.round(Math.min(width * 0.13, maxTextWidth / Math.max(1, sublabel.length * 0.7)))
        readonly property real detailSize: Math.round(Math.min(width * 0.12, maxTextWidth / Math.max(1, detail.length * 0.65)))

        property real animValue: 0

        onValueChanged: animValue = Math.min(1, Math.max(0, value))

        Behavior on animValue {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Easing.OutCubic
            }
        }

        Component.onCompleted: animValue = Math.min(1, Math.max(0, value))

        Canvas {
            id: glowCanvas
            anchors.centerIn: parent
            width: gaugeRoot.width + gaugeRoot.canvasOverflow * 2
            height: gaugeRoot.height + gaugeRoot.canvasOverflow * 2
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2;
                const cy = height / 2;
                const radius = gaugeRoot.ringRadius;
                const startAngle = -Math.PI * 0.5;
                const endAngle = Math.PI * 1.5;

                ctx.lineCap = "round";

                if (gaugeRoot.animValue > 0) {
                    const prog = startAngle + (endAngle - startAngle) * gaugeRoot.animValue;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, startAngle, prog);
                    ctx.strokeStyle = Qt.rgba(gaugeRoot.accentColor.r, gaugeRoot.accentColor.g, gaugeRoot.accentColor.b, 0.2);
                    ctx.lineWidth = gaugeRoot.glowStrokeWidth;
                    ctx.stroke();
                }
            }

            Connections {
                target: gaugeRoot
                function onAnimValueChanged() { glowCanvas.requestPaint(); }
                function onAccentColorChanged() { glowCanvas.requestPaint(); }
                function onWidthChanged() { glowCanvas.requestPaint(); }
                function onHeightChanged() { glowCanvas.requestPaint(); }
            }

            Component.onCompleted: requestPaint()
        }

        Canvas {
            id: arcCanvas
            anchors.centerIn: parent
            width: gaugeRoot.width + gaugeRoot.canvasOverflow * 2
            height: gaugeRoot.height + gaugeRoot.canvasOverflow * 2
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2;
                const cy = height / 2;
                const radius = gaugeRoot.ringRadius;
                const startAngle = -Math.PI * 0.5;
                const endAngle = Math.PI * 1.5;

                ctx.lineCap = "round";

                ctx.beginPath();
                ctx.arc(cx, cy, radius, startAngle, endAngle);
                ctx.strokeStyle = Qt.rgba(gaugeRoot.accentColor.r, gaugeRoot.accentColor.g, gaugeRoot.accentColor.b, 0.1);
                ctx.lineWidth = gaugeRoot.thickness;
                ctx.stroke();

                if (gaugeRoot.animValue > 0) {
                    const prog = startAngle + (endAngle - startAngle) * gaugeRoot.animValue;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, startAngle, prog);
                    ctx.strokeStyle = gaugeRoot.accentColor;
                    ctx.lineWidth = gaugeRoot.thickness;
                    ctx.stroke();
                }
            }

            Connections {
                target: gaugeRoot
                function onAnimValueChanged() { arcCanvas.requestPaint(); }
                function onAccentColorChanged() { arcCanvas.requestPaint(); }
                function onWidthChanged() { arcCanvas.requestPaint(); }
                function onHeightChanged() { arcCanvas.requestPaint(); }
            }

            Component.onCompleted: requestPaint()
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            StyledText {
                text: gaugeRoot.label
                font.pixelSize: gaugeRoot.labelSize
                font.weight: Font.Bold
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: gaugeRoot.sublabel
                font.pixelSize: gaugeRoot.sublabelSize
                font.weight: Font.Medium
                color: gaugeRoot.accentColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: gaugeRoot.detail
                font.pixelSize: gaugeRoot.detailSize
                color: gaugeRoot.detailColor
                anchors.horizontalCenter: parent.horizontalCenter
                visible: gaugeRoot.detail.length > 0
            }
        }
    }

    // Stat card component for alt style
    component StatCard: Rectangle {
        id: statCardRoot
        width: 100
        height: 100
        radius: 16
        color: Theme.surfaceContainerHigh

        property string iconName: ""
        property color iconColor: Theme.primary
        property string label: ""
        property string valueText: ""
        property real progressValue: 0  // 0-100

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingS

                DankIcon {
                    name: statCardRoot.iconName
                    size: 20
                    color: statCardRoot.iconColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: statCardRoot.label
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: statCardRoot.valueText
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeLarge * 1.5
                font.weight: Font.Bold
            }

            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: Theme.surfaceContainerHighest

                Rectangle {
                    width: parent.width * (statCardRoot.progressValue / 100)
                    height: parent.height
                    radius: 2
                    color: root.getUsageColor(statCardRoot.progressValue)

                    Behavior on width {
                        NumberAnimation { duration: Theme.mediumDuration; easing.type: Theme.standardEasing }
                    }
                }
            }
        }
    }

    component ProgressBar: Item {
        id: progressBarRoot
        height: barHeight

        property real value: 0  // 0-100
        property real barHeight: 12
        property real barRadius: barHeight / 2
        property color barColor: Theme.primary
        property color backgroundColor: Theme.surfaceText

        Rectangle {
            anchors.fill: parent
            color: progressBarRoot.backgroundColor
            radius: progressBarRoot.barRadius

            Rectangle {
                width: parent.width * Math.min(1, progressBarRoot.value / 100)
                height: parent.height
                color: progressBarRoot.barColor
                radius: progressBarRoot.barRadius

                Behavior on width {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // Engine bar component
    component EngineBar: Item {
        id: engineBarRoot
        height: 24

        property string label: ""
        property real value: 0
        property color barColor: Theme.primary

        Row {
            anchors.fill: parent
            spacing: Theme.spacingS

            StyledText {
                width: 50
                text: engineBarRoot.label
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: parent.width - 100
                height: 8
                radius: 4
                color: Theme.surfaceContainerHighest
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: parent.width * (engineBarRoot.value / 100)
                    height: parent.height
                    radius: 4
                    color: engineBarRoot.barColor

                    Behavior on width {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }

            StyledText {
                width: 40
                text: `${engineBarRoot.value.toFixed(0)}%`
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Context Menu Component (Matching Screenshot)
    component DankContextMenu: Rectangle {
        id: menuRoot
        visible: false
        width: 180
        height: column.implicitHeight + Theme.spacingS * 2
        color: Theme.surface
        radius: Theme.cornerRadius
        z: 9999
        border.color: Theme.withAlpha(Theme.surfaceVariantText, 0.12)
        border.width: 1

        property var targetProcess: null
        property bool showPid: true
        FileView { id: menuCmdView; path: targetProcess ? ("/proc/" + targetProcess.pid + "/cmdline") : "" }

        function show(px, py, proc, showPid = true) {
            // Keep menu within parent bounds
            let nx = px;
            let ny = py;
            if (nx + width > parent.width) nx = parent.width - width - 10;
            if (ny + height > parent.height) ny = parent.height - height - 10;
            
            x = nx;
            y = ny;
            targetProcess = proc;
            menuRoot.showPid = showPid;
            visible = true;
        }

        function hide() {
            visible = false;
        }

        Column {
            id: column
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            spacing: 2

            ContextMenuItem {
                visible: menuRoot.showPid
                height: menuRoot.showPid ? 32 : 0
                icon: "tag"; text: "Copy PID"
                onClicked: {
                    Quickshell.execDetached(["dms", "cl", "copy", menuRoot.targetProcess.pid.toString()]);
                    menuRoot.hide();
                }
            }

            Item { visible: menuRoot.showPid; width: parent.width; height: 2 }
            Rectangle { visible: menuRoot.showPid; width: parent.width - Theme.spacingM; height: 1; color: Theme.withAlpha(Theme.surfaceVariantText, 0.1); anchors.horizontalCenter: parent.horizontalCenter }
            Item { visible: menuRoot.showPid; width: parent.width; height: 2 }

            ContextMenuItem {
                icon: "content_copy"; text: "Copy Name"
                onClicked: {
                    Quickshell.execDetached(["dms", "cl", "copy", menuRoot.targetProcess.name]);
                    menuRoot.hide();
                }
            }
            ContextMenuItem {
                icon: "code"; text: "Copy Full Command"
                onClicked: {
                    let cmd = root.formatCmdline(menuCmdView.text()) || menuRoot.targetProcess.name;
                    Quickshell.execDetached(["dms", "cl", "copy", cmd]);
                    menuRoot.hide();
                }
            }

            Item { width: parent.width; height: 2 }
            Rectangle { width: parent.width - Theme.spacingM; height: 1; color: Theme.withAlpha(Theme.surfaceVariantText, 0.1); anchors.horizontalCenter: parent.horizontalCenter }
            Item { width: parent.width; height: 2 }

            ContextMenuItem {
                icon: "close"; text: "Kill Process"
                hoverColor: Theme.withAlpha(Theme.error, 0.1)
                hoverIconColor: Theme.error
                onClicked: {
                    Quickshell.execDetached(["kill", menuRoot.targetProcess.pid.toString()]);
                    menuRoot.hide();
                }
            }
            ContextMenuItem {
                icon: "cancel"; text: "Force Kill (SIGKILL)"
                hoverColor: Theme.withAlpha(Theme.error, 0.1)
                hoverIconColor: Theme.error
                onClicked: {
                    Quickshell.execDetached(["kill", "-9", menuRoot.targetProcess.pid.toString()]);
                    menuRoot.hide();
                }
            }
        }
    }

    component ContextMenuItem: Rectangle {
        id: itemRoot
        width: parent.width
        height: 32
        radius: 8
        color: itemMouseArea.containsMouse ? hoverColor : "transparent"

        property color hoverColor: Theme.withAlpha(Theme.primary, 0.08)
        property color hoverIconColor: Theme.primary

        property string icon: ""
        property string text: ""
        signal clicked()

        DankRipple { id: ripple; cornerRadius: itemRoot.radius }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingS
            spacing: Theme.spacingS

            DankIcon {
                name: itemRoot.icon
                size: 18
                color: itemMouseArea.containsMouse ? itemRoot.hoverIconColor : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
            }

            StyledText {
                text: itemRoot.text
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: itemMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onPressed: ripple.trigger(mouse.x, mouse.y)
            onClicked: itemRoot.clicked()
        }
    }
}
