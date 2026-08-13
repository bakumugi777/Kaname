import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property string candidatesPath: ""
    property string promptPath: ""
    property string candidateText: ""
    property string promptText: ""

    function load(candidatePath, labelPath) {
        candidatesPath = candidatePath
        promptPath = labelPath
        candidateText = candidates.text()
        promptText = prompt.text()
    }

    property FileView candidates: FileView { path: root.candidatesPath; blockLoading: true }
    property FileView prompt: FileView { path: root.promptPath; blockLoading: true }
}
