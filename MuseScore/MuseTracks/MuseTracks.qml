import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Window 2.3
import Qt.labs.platform
import MuseScore 3.0

MuseScore {
    id: mainWindow
    title: "MuseTracks"
    description: "Creates Learning Tracks"
    version: "1.0"
    requiresScore: true
    pluginType: "dialog"

    Component.onCompleted: {
        // Specific MS4 features
        if (mscoreMajorVersion >= 4 && mscoreMinorVersion >= 4) {
            mainWindow.title = qsTr("MuseTracks");
        }
    }

    onRun: {
        // check MuseScore version
        if (mscoreMajorVersion < 4 && mscoreMinorVersion < 4) {
            mainWindow.visible = false;
            versionError.open();
        }
    }

    //plugin vars
    property string exportDir: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0] //musescore 4.5 removes curScore.path for some reason...
    property string selectedExportType: "None"
    property string currentFile: ""
    property int totalFileCount: 0
    property int currentFileCount: 0

    // Compute dimension based on content
    width: mainRow.implicitWidth + extraLeft + extraRight
    height: mainRow.implicitHeight + extraTop + extraBottom

    property int extraMargin: mainRow.anchors.margins ? mainRow.anchors.margins : 0
    property int extraTop: mainRow.anchors.topMargin ? mainRow.anchors.topMargin : extraMargin
    property int extraBottom: mainRow.anchors.bottomMargin ? mainRow.anchors.bottomMargin : extraMargin
    property int extraLeft: mainRow.anchors.leftMargin ? mainRow.anchors.leftMargin : extraMargin
    property int extraRight: mainRow.anchors.rightMargin ? mainRow.anchors.rightMargin : extraMargin

    // Signal onClosing on the main Window. This code is executed when the window closed
    // Rem: this generates some warnings in the plugin editor log, but this is ok
    Connections {
        target: mainWindow.parent.Window.window
        onClosing:
        // do whatever is required to do when the plugin window is closing such as managing the settings
        {}
    }

    // UI
    ColumnLayout {
        id: mainRow // needed for reference in size computing
        spacing: 2
        anchors.margins: 0

        RowLayout {
            Layout.margins: 20
            Layout.minimumWidth: 500
            Layout.minimumHeight: 50

            Text {
                id: helpText
                text: "If exporting with more than one voice per stave, name the parts '[Voice1]/[Voice2]' (e.g. 'Tenor/Lead')"
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                maximumLineCount: 1
                color: sysActivePalette.text
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.margins: 20
            Layout.minimumWidth: 500
            Layout.minimumHeight: 50
            spacing: 5
            Text {
                id: exportDirTextFieldTitle
                text: "Export Path:"
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                maximumLineCount: 1
                color: sysActivePalette.text
            }

            TextField {
                text: exportDirDialog.folder
                echoMode: TextInput.Normal
                readOnly: true
                Layout.fillWidth: true
            }
            //musescore 4.4 uses Qt 6.2.4. This will break once updated to Qt 6.9
            //becuse FolderDialog is in Qt.labs until Qt 6.9
            FolderDialog {
                id: exportDirDialog
                currentFolder: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
                folder: exportDir
            }

            Button {
                text: qsTr("Open")
                onClicked: exportDirDialog.open()
            }
        }

        // Plugin controls
        GridLayout {
            Layout.margins: 20
            Layout.minimumWidth: 250
            Layout.minimumHeight: 50
            columnSpacing: 5
            rowSpacing: 5

            ButtonGroup {
                buttons: exportTypeRadioButtons.children
                onClicked: button => {
                    console.log("clicked:", button.text);
                    selectedExportType = button.text;
                }
            }

            RowLayout {
                id: exportTypeRadioButtons
                Text {
                    id: exportTypeTitle
                    text: "Export Type:"
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: sysActivePalette.text
                }

                RadioButton {
                    text: qsTr("Part Left")
                }
                RadioButton {
                    text: qsTr("Part Predominant")
                }
                RadioButton {
                    text: qsTr("Part Missing")
                }
                RadioButton {
                    text: qsTr("All")
                }
            }
        } // GridLayout

        // Buttons
        DialogButtonBox {
            Layout.fillWidth: true
            spacing: 5
            alignment: Qt.AlignRight
            background.opacity: 0 // hide default white background
            padding: 10

            standardButtons: DialogButtonBox.Cancel

            Button {
                id: special
                enabled: true // add real enabling test
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                text: qsTr("Export")
            }

            onAccepted: {
                if (exportTracks(exportDir, selectedExportType))
                    mainWindow.parent.Window.window.close();
            }

            onClicked: {
                if (button === special)
                {}
            }
            onRejected: mainWindow.parent.Window.window.close()
        } // DialogButtonBox

        // Status bar (delete if not needed)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: exportStatus.height
            Layout.margins: 5
            spacing: 5

            Text {
                id: exportStatus
                text: currentFile
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                maximumLineCount: 1
                Layout.fillWidth: true
                color: sysActivePalette.text
            }
        } // status bar

    } // ColumnLayout

    // Palette for nice color management
    SystemPalette {
        id: sysActivePalette
        colorGroup: SystemPalette.Active
    }
    SystemPalette {
        id: sysDisabledPalette
        colorGroup: SystemPalette.Disabled
    }

    // Version mismatch dialog
    MessageDialog {
        id: versionError
        visible: false
        title: qsTr("Unsupported MuseScore Version")
        text: qsTr("This plugin requires MuseScore 4.4 or later.")
        onAccepted: {
            mainWindow.parent.Window.window.close();
        }
    }
    //Export Type Validation dialog
    MessageDialog {
        id: inputValidationError
        visible: false
        title: qsTr("Input Validation Error")
        text: qsTr("Something went wrong with your inputs...")
        onAccepted: {
            inputValidationError.visible = false;
        }
    }

    function exportTracks(exportDir, exportType) {
        if (exportDir.length === 0 || selectedExportType === "None") {
            inputValidationError.visible = true;
            return false;
        }
        var originalConfiguration = getOriginalConfig(curScore.parts);
        switch (exportType) {
        case "Part Left":
            exportPartLeftTracks(curScore.parts, exportDir);
            break;
        case "Part Predominant":
            exportPartPredominantTracks(curScore.parts, exportDir);
            break;
        case "Part Missing":
            exportPartMissingTracks(curScore.parts, exportDir);
            break;
        case "All":
            exportPartLeftTracks(curScore.parts, exportDir);
            exportPartPredominantTracks(curScore.parts, exportDir);
            exportPartMissingTracks(curScore.parts, exportDir);
            break;
        }
        resetToOriginalConfig(curScore.parts, originalConfiguration);
        return true;
    }

    function exportPartLeftTracks(parts, exportDir) {
        setAllToRight(parts);
        for (var i = 0; i < parts.length; ++i) {
            var part = parts[i];
            var partNameSplit = part.partName.split('/');
            var instrs = part.instruments;
            for (var j = 0; j < instrs.length; ++j) {
                var instr = instrs[j];
                var channels = instr.channels;
                for (var k = 0; k < channels.length; ++k) {
                    var channel = channels[k];
                    var currentPan = channel.pan;
                    channel.pan = 0;
                    writeScore(curScore, exportDir + `/${curScore.scoreName} - ${partNameSplit[k]} Left`, 'mp3');
                    channel.pan = currentPan;
                }
            }
        }
    }

    function setAllToRight(parts) {
        for (var i = 0; i < parts.length; ++i) {
            var part = parts[i];
            var partNameSplit = part.partName.split('/');
            var instrs = part.instruments;
            for (var j = 0; j < instrs.length; ++j) {
                var instr = instrs[j];
                var channels = instr.channels;
                for (var k = 0; k < channels.length; ++k) {
                    var channel = channels[k];
                    var currentPan = channel.pan;
                    channel.pan = 127;
                }
            }
        }
    }

    function setAllVol(parts, vol) {
        for (var i = 0; i < parts.length; ++i) {
            var part = parts[i];
            var partNameSplit = part.partName.split('/');
            var instrs = part.instruments;
            for (var j = 0; j < instrs.length; ++j) {
                var instr = instrs[j];
                var channels = instr.channels;
                for (var k = 0; k < channels.length; ++k) {
                    var channel = channels[k];
                    var currentPan = channel.pan;
                    channel.volume = vol;
                }
            }
        }
    }

    function exportPartPredominantTracks(parts, exportDir) {
        setAllVol(parts, 50);
        for (var i = 0; i < parts.length; ++i) {
            var part = parts[i];
            var partNameSplit = part.partName.split('/');
            var instrs = part.instruments;
            for (var j = 0; j < instrs.length; ++j) {
                var instr = instrs[j];
                var channels = instr.channels;
                for (var k = 0; k < channels.length; ++k) {
                    var channel = channels[k];
                    var currentVolume = channel.volume;
                    channel.volume = 100;
                    writeScore(curScore, exportDir + `/${curScore.scoreName} - ${partNameSplit[k]} Predominant`, 'mp3');
                    channel.volume = currentVolume;
                }
            }
        }
    }
    function exportPartMissingTracks(parts, exportDir) {
        setAllVol(parts, 100);
        for (var i = 0; i < parts.length; ++i) {
            var part = parts[i];
            var partNameSplit = part.partName.split('/');
            var instrs = part.instruments;
            for (var j = 0; j < instrs.length; ++j) {
                var instr = instrs[j];
                var channels = instr.channels;
                for (var k = 0; k < channels.length; ++k) {
                    var channel = channels[k];
                    var currentVolume = channel.volume;
                    channel.volume = 0;
                    writeScore(curScore, exportDir + `/${curScore.scoreName} - ${partNameSplit[k]} Missing`, 'mp3');
                    channel.volume = currentVolume;
                }
            }
        }
    }
    function getOriginalConfig(parts) {
        var result = [];
        for (var i = 0; i < parts.length; ++i) {
            var part = parts[i];
            var instrs = part.instruments;
            for (var j = 0; j < instrs.length; ++j) {
                var instr = instrs[j];
                var channels = instr.channels;
                for (var k = 0; k < channels.length; ++k)
                    var channel = channels[k];
                result.push({
                    id: `${i} ${j} ${k}`,
                    volume: channel.volume,
                    pan: channel.pan
                });
            }
        }
        return result;
    }
    function resetToOriginalConfig(parts, originalConfig) {
        for (var i = 0; i < parts.length; ++i) {
            var part = parts[i];
            var instrs = part.instruments;
            for (var j = 0; j < instrs.length; ++j) {
                var instr = instrs[j];
                var channels = instr.channels;
                for (var k = 0; k < channels.length; ++k)
                    var channel = channels[k];
                var oc = originalConfig.find(c => c.id === `${i} ${j} ${k}`);
                channel.volume = oc.volume;
                channel.pan = oc.pan;
            }
        }
    }
}
