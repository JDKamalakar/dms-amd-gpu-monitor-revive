import QtQuick
import Quickshell
import Quickshell.Io

import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    
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

    property bool minimumWidth: pluginData.minimumWidth !== undefined ? pluginData.minimumWidth : false
    property string popoutStyle: pluginData.popoutStyle || "dmsExtended"

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
        if (percent > 90) return Theme.error;
        if (percent > 70) return "#ffa500";
        return Theme.primary;
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon { name: "dashboard"; size: root.iconSize; color: Theme.widgetIconColor; anchors.verticalCenter: parent.verticalCenter }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: root.minimumWidth ? Math.max(textBaseline.width, gpuText.paintedWidth) : gpuText.paintedWidth
                implicitHeight: gpuText.implicitHeight
                width: implicitWidth; height: implicitHeight
                StyledTextMetrics { id: textBaseline; font.pixelSize: Theme.fontSizeSmall; text: "88% | 8.8GiB" }
                StyledText {
                    id: gpuText; anchors.fill: parent; font.pixelSize: Theme.fontSizeSmall; color: Theme.widgetTextColor
                    text: `${root.gpuUsage.toFixed(0)}% | ${(root.vramUsed / 1024).toFixed(1)}GiB`
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 1

            DankIcon {
                name: "dashboard"
                size: root.iconSize
                color: Theme.widgetIconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: `${root.gpuUsage.toFixed(0)}%`
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.widgetTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // Popout content
    popoutContent: Component {
        PopoutComponent {
            id: popout
            
            Loader {
                // 2. REVERT THIS LINE: Back to parent.width
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
                StyledText { text: root.gpuName; font.pixelSize: 18; font.bold: true; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
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
                        font.pixelSize: 16
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
            }

            // Process list section
            Rectangle {
                visible: root.gfxUsage > 0 || root.memUsage > 0 || root.mediaUsage > 0
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
                    }

                    DankListView {
                        width: parent.width
                        height: Math.min(contentHeight, 220)
                        model: root.processes
                        spacing: 2
                        clip: true

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 44
                            radius: Theme.cornerRadius
                            color: procMouseArea.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                                : "transparent"
                            border.color: procMouseArea.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                : "transparent"
                            border.width: 1

                            MouseArea {
                                id: procMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS

                                // Process name column
                                Item {
                                    width: parent.width - vramBadge.width - gfxBadge.width - cpuBadge.width - Theme.spacingS * 3
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
                                            spacing: 2

                                            StyledText {
                                                text: modelData.name
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.surfaceText
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, 120)
                                            }

                                            StyledText {
                                                text: `PID: ${modelData.pid}`
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                color: Theme.surfaceVariantText
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
                        font.pixelSize: 16
                        font.bold: true
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter 
                    }
                }
            }

            // Gauges row
            Item {
                width: parent.width
                height: gaugesRow.height

                readonly property real gaugeSize: Theme.fontSizeMedium * 6.5

                Row {
                    id: gaugesRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    CircleGauge {
                        width: parent.parent.gaugeSize
                        height: parent.parent.gaugeSize
                        value: root.gpuUsage / 100
                        label: root.gpuUsage.toFixed(0) + "%"
                        sublabel: "GPU"
                        accentColor: root.gpuUsage > 80 ? Theme.error : (root.gpuUsage > 50 ? Theme.warning : Theme.primary)
                    }

                    CircleGauge {
                        width: parent.parent.gaugeSize
                        height: parent.parent.gaugeSize
                        value: root.vramPercent / 100
                        label: (root.vramUsed / 1024).toFixed(1) + " GiB"
                        sublabel: "VRAM"
                        detail: root.vramPercent.toFixed(0) + "%"
                        accentColor: root.vramPercent > 90 ? Theme.error : (root.vramPercent > 70 ? Theme.warning : Theme.secondary)
                    }

                    CircleGauge {
                        visible: root.temperature > 0
                        width: parent.parent.gaugeSize
                        height: parent.parent.gaugeSize
                        value: Math.min(1, root.temperature / 100)
                        label: root.temperature + "°C"
                        sublabel: "Temp"
                        detail: root.powerUsage > 0 ? (root.powerUsage + "W") : ""
                        accentColor: root.temperature > 85 ? Theme.error : (root.temperature > 70 ? Theme.warning : Theme.info)
                        detailColor: Theme.surfaceVariantText
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
            }

            // Process list section
            Rectangle {
                visible: root.gfxUsage > 0 || root.memUsage > 0 || root.mediaUsage > 0
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
                    }

                    DankListView {
                        width: parent.width
                        height: Math.min(contentHeight, 220)
                        model: root.processes
                        spacing: 2
                        clip: true

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 44
                            radius: Theme.cornerRadius
                            color: procMouseArea.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                                : "transparent"
                            border.color: procMouseArea.containsMouse
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                : "transparent"
                            border.width: 1

                            MouseArea {
                                id: procMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS

                                // Process name column
                                Item {
                                    width: parent.width - vramBadge.width - gfxBadge.width - cpuBadge.width - Theme.spacingS * 3
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
                                            spacing: 2

                                            StyledText {
                                                text: modelData.name
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.surfaceText
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, 120)
                                            }

                                            StyledText {
                                                text: `PID: ${modelData.pid}`
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                color: Theme.surfaceVariantText
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
    // DMS EXTENDED STYLE (Full Width & Native)
    // ==========================================
    Component {
        id: dmsExtendedStyleContent

        Column {
            width: parent.width
            spacing: Theme.spacingM

            // 1. FIRST LINE: TITLE, FILTER CHIPS, SEARCH BAR
            Item {
                id: firstLine
                width: parent.width
                height: 36

                Row {
                    id: leftControls
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingL

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS
                        
                        DankIcon { name: "apps"; size: 20; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Processes"; font.pixelSize: 16; font.bold: true; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // Native Button Group
                    DankButtonGroup {
                        id: processFilters
                        anchors.verticalCenter: parent.verticalCenter
                        
                        // FIX 1: Width increased to 240 so it never wraps/stacks
                        width: 240 
                        buttonHeight: 28 
                        checkEnabled: false 
                        
                        model: ["All", "User", "System"]
                        currentIndex: 0
                        selectionMode: "single"
                        
                        onSelectionChanged: function(index, selected) {
                            if (selected) {
                                processFilters.currentIndex = index;
                                processListView.filterMode = index;
                            }
                        }
                    }
                }

                // Native Search Bar seamlessly filling the remaining space
                DankTextField {
                    anchors.left: leftControls.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 32
                    placeholderText: "Search processes or PIDs..."
                    
                    onTextChanged: processListView.searchText = text
                }
            }

            // 2. SECOND LINE: SQUARE GPU ICON, TEXT, CIRCULAR GAUGES
            Item {
                width: parent.width; height: 80
                
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                    
                    Rectangle {
                        width: 58; height: 58; radius: 12
                        color: Theme.withAlpha(Theme.primary, 0.2) 
                        DankIcon { name: "developer_board"; size: 38; anchors.centerIn: parent; color: Theme.primary }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: -2
                        StyledText { text: "GPU"; font.pixelSize: 24; font.bold: true; color: Theme.surfaceText; transform: Translate { y: 2 } }
                        StyledText { text: root.gpuName; font.pixelSize: 11; color: Theme.surfaceVariantText; font.weight: Font.Medium }
                    }
                }

                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    CircleGauge { width: 75; height: 75; value: root.gpuUsage/100; label: root.gpuUsage.toFixed(0) + "%"; sublabel: "GPU"; detail: root.temperature + "°"; accentColor: root.gpuUsage > 80 ? Theme.error : Theme.primary }
                    CircleGauge { width: 75; height: 75; value: root.vramPercent/100; label: (root.vramUsed/1024).toFixed(1) + "G"; sublabel: "VRAM"; detail: root.powerUsage + "W"; accentColor: Theme.secondary }
                    CircleGauge { width: 75; height: 75; value: root.temperature/100; label: root.temperature + "°"; sublabel: "TEMP"; detail: root.powerUsage + "W"; accentColor: root.temperature > 85 ? Theme.error : Theme.warning }
                }
            }

            // 3. Engine activity section
            Rectangle {
                width: parent.width
                height: engineContent.height + Theme.spacingM * 2
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                Column {
                    id: engineContent
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
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

            // 4. Process list section matching DankListView aesthetic
            Rectangle {
                width: parent.width
                height: 280 // Locked height so the widget never shrinks
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingS

                    // FIX 2: Table Header Row
                    Row {
                        width: parent.width
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        
                        StyledText { text: "Name"; font.pixelSize: 12; font.weight: Font.Medium; color: Theme.surfaceVariantText; width: parent.width - 200 }
                        StyledText { text: "GPU"; font.pixelSize: 12; font.weight: Font.Medium; color: Theme.surfaceVariantText; width: 60; horizontalAlignment: Text.AlignHCenter }
                        StyledText { text: "VRAM"; font.pixelSize: 12; font.weight: Font.Medium; color: Theme.surfaceVariantText; width: 80; horizontalAlignment: Text.AlignHCenter }
                        StyledText { text: "PID"; font.pixelSize: 12; font.weight: Font.Medium; color: Theme.surfaceVariantText; width: 60; horizontalAlignment: Text.AlignRight }
                    }

                    // Content Area (List + Empty State)
                    Item {
                        width: parent.width
                        height: parent.height - 24

                        DankListView {
                            id: processListView
                            anchors.fill: parent
                            spacing: 2
                            clip: true

                            property string searchText: ""
                            property int filterMode: 0 

                            model: {
                                let result = root.processes;
                                
                                if (filterMode !== 0) {
                                    const systemProcs = ["xorg", "xwayland", "wayland", "kwin", "kwin_wayland", "kwin_x11", "niri", "hyprland", "plasmashell", "sddm", "gdm", "systemd"];
                                    result = result.filter(p => {
                                        const isSystem = systemProcs.some(sys => p.name.toLowerCase().includes(sys));
                                        return filterMode === 1 ? !isSystem : isSystem;
                                    });
                                }

                                if (searchText !== "") {
                                    result = result.filter(p => 
                                        p.name.toLowerCase().includes(searchText.toLowerCase()) || 
                                        p.pid.toString().includes(searchText)
                                    );
                                }
                                
                                return result;
                            }

                            delegate: Rectangle {
                                width: ListView.view.width; height: 40; radius: Theme.cornerRadius
                                color: procMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.06) : "transparent"
                                border.color: procMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : "transparent"
                                border.width: 1

                                MouseArea { id: procMouseArea; anchors.fill: parent; hoverEnabled: true }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingS

                                    // Process Name 
                                    Item {
                                        width: parent.width - 200
                                        height: parent.height
                                        Row {
                                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingS
                                            DankIcon { name: "terminal"; size: 16; color: Theme.surfaceText; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                                            StyledText { text: modelData.name; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Medium; color: Theme.surfaceText; elide: Text.ElideRight; width: Math.min(implicitWidth, 160); anchors.verticalCenter: parent.verticalCenter }
                                        }
                                    }

                                    // GFX 
                                    StyledText {
                                        width: 60
                                        text: modelData.gfx > 0 ? `${modelData.gfx}%` : "—"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: modelData.gfx > 50 ? Theme.warning : Theme.surfaceText
                                        horizontalAlignment: Text.AlignHCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // VRAM Badge
                                    Item {
                                        width: 80
                                        height: parent.height
                                        Rectangle {
                                            width: 70; height: 22; radius: 6
                                            color: Theme.withAlpha(Theme.primary, 0.15)
                                            anchors.centerIn: parent
                                            StyledText {
                                                text: `${modelData.vram}${modelData.vramUnit === "MiB" ? "M" : "G"}`
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: Theme.primary
                                                anchors.centerIn: parent
                                            }
                                        }
                                    }

                                    // PID
                                    StyledText {
                                        width: 60
                                        text: modelData.pid
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        color: Theme.surfaceVariantText
                                        horizontalAlignment: Text.AlignRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // FIX 3: Empty State exactly matching the screenshot
                        Column {
                            visible: processListView.count === 0
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            DankIcon { 
                                name: "search_off" 
                                size: 36
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter 
                            }

                            StyledText { 
                                text: "No matching processes"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter 
                            }
                        }
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
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2;
                const cy = height / 2;
                const radius = (Math.min(width, height) / 2) - gaugeRoot.arcPadding;
                const startAngle = -Math.PI * 0.5;
                const endAngle = Math.PI * 1.5;

                ctx.lineCap = "round";

                if (gaugeRoot.animValue > 0) {
                    const prog = startAngle + (endAngle - startAngle) * gaugeRoot.animValue;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, startAngle, prog);
                    ctx.strokeStyle = Qt.rgba(gaugeRoot.accentColor.r, gaugeRoot.accentColor.g, gaugeRoot.accentColor.b, 0.2);
                    ctx.lineWidth = gaugeRoot.thickness + gaugeRoot.glowExtra;
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
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const cx = width / 2;
                const cy = height / 2;
                const radius = (Math.min(width, height) / 2) - gaugeRoot.arcPadding;
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
                font.pixelSize: 28
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
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
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
}
