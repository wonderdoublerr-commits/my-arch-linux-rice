import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Scope {
    id: root

    property bool calVisible: false


    // Живая палитра: rice-theme пишет palette.json — бар плавно анимируется.
    // ВАЖНО: Qt ждёт hex в формате #AARRGGBB (альфа ПЕРВАЯ), а rice-theme
    // пишет CSS-стилем #RRGGBBAA — loadPal() нормализует через fixColor().
    property var pal: {
        "barBg": "#9011111b",
        "onAccent": "#11111b",
        "surface": "#1e1e2e",
        "border": "#36364a",
        "accent": "#89b4fa",
        "text": "#cdd6f4",
        "text2": "#a6adc8",
        "red": "#f38ba8",
        "dim": "#45475a",
        "micBg": "#3a252b",
        "micBorder": "#6b454f",
        "micText": "#e6a0aa"
    }

    property var palFrom: pal
    property var palTo: pal
    property real palProgress: 1
    property bool palReady: false

    function mixColor(a, b, t) {
        const ca = Qt.color(a);
        const cb = Qt.color(b);
        return Qt.rgba(
            ca.r + (cb.r - ca.r) * t,
            ca.g + (cb.g - ca.g) * t,
            ca.b + (cb.b - ca.b) * t,
            ca.a + (cb.a - ca.a) * t
        );
    }

    function updateAnimatedPal() {
        const t = palProgress;
        const p = {};
        for (const k in palTo)
            p[k] = mixColor(palFrom[k] || palTo[k], palTo[k], t);
        pal = p;
    }

    NumberAnimation {
        id: palAnim
        target: root
        property: "palProgress"
        from: 0
        to: 1
        duration: 900
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.4, 0, 0.6, 1, 1, 1]
        onRunningChanged: {
            if (!running)
                root.updateAnimatedPal();
        }
    }

    onPalProgressChanged: updateAnimatedPal()

    FileView {
        id: paletteFile
        path: "/home/wonder/.config/rice/palette.json"
        watchChanges: true
        onFileChanged: paletteFile.reload()
        onLoaded: root.loadPal()
    }

    // CSS "#rrggbbaa" → Qt/QML "#aarrggbb" (Qt парсит 8-значный hex как
    // #AARRGGBB, поэтому без конвертации зелёный фон читался как синий)
    function fixColor(c) {
        if (typeof c !== "string") return c;
        const m = c.match(/^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})$/);
        return m ? "#" + m[2] + m[1] : c;
    }

    function loadPal() {
        try {
            const p = JSON.parse(paletteFile.text());
            if (p && p.barBg) {
                for (const k in p) p[k] = fixColor(p[k]);

                if (!root.palReady) {
                    root.pal = p;
                    root.palFrom = p;
                    root.palTo = p;
                    root.palProgress = 1;
                    root.palReady = true;
                } else {
                    root.palFrom = root.pal;
                    root.palTo = p;
                    root.palProgress = 0;
                    palAnim.restart();
                }
            }
        } catch (e) {
            // файла ещё нет — дефолтная палитра
        }
    }
    property string currentTime: Qt.formatDateTime(
        new Date(),
        "ddd, dd MMM • HH:mm"
    )

    property string layout: "EN"
    property string volume: "0"
    property real volumeControl: 0
    property bool volumeChanging: false
    property string micState: "MIC"
    property string downloadSpeed: "0"
    property string playerTitle: "Музыка"
    property string playerArtist: "Открой плеер для управления"
    property string playerStatus: "Stopped"
    property string playerArt: ""
    property real playerPosition: 0
    property real playerLength: 0

    // ─────────────────────────────────────────────
    // ОБНОВЛЕНИЕ
    // ─────────────────────────────────────────────

    Timer {
        interval: 100
        running: true
        repeat: true

        onTriggered: {
            currentTime = Qt.formatDateTime(
                new Date(),
                "ddd, dd MMM • HH:mm"
            )

            statusProcess.running = true
            networkProcess.running = true
            playerProcess.running = true
        }
    }

    // ─────────────────────────────────────────────
    // VOLUME / MIC / LAYOUT
    // ─────────────────────────────────────────────

    Process {
        id: volumeApplyProcess

        property real targetVolume: 0
        property bool busy: false

        command: [
            "wpctl",
            "set-volume",
            "@DEFAULT_AUDIO_SINK@",
            (targetVolume / 100).toFixed(2)
        ]

        onExited: {
            busy = false

            if (Math.abs(root.volumeControl - targetVolume) > 0.01) {
                targetVolume = root.volumeControl
                busy = true
                volumeApplyProcess.running = true
            } else {
                root.volumeChanging = false
                root.statusProcess.running = true
            }
        }
    }

    Process {
        id: statusProcess

command: [
    "bash",
    "-c",
    "vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%.0f\", $2*100}'); mic=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED && echo MUTE || echo MIC); lay=$(hyprctl devices | awk '/active keymap:/ {key=$0} /main: yes/ {if (key ~ /Russian|Ukrainian/) print \"RU\"; else print \"EN\"; exit}'); printf '%s|%s|%s' \"$lay\" \"$vol\" \"$mic\""
]

        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("|")

                if (parts.length >= 3) {
                    layout = parts[0]
                    volume = parts[1]

                    if (!volumeChanging) {
                        volumeControl = Math.min(
                            200,
                            Math.max(0, Number(parts[1]))
                        )
                    }

                    micState = parts[2]
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // DOWNLOAD SPEED
    // ─────────────────────────────────────────────

    Process {
        id: networkProcess

        command: [
            "bash",
            "-c",
            "iface=enp4s0; r1=$(cat /sys/class/net/$iface/statistics/rx_bytes); sleep 0.5; r2=$(cat /sys/class/net/$iface/statistics/rx_bytes); awk -v r1=$r1 -v r2=$r2 'BEGIN {printf \"%.1f\", (r2-r1)/500000}'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                downloadSpeed = this.text.trim()
            }
        }
    }

    // ─────────────────────────────────────────────
    // AURALIS / NOW PLAYING
    // ─────────────────────────────────────────────

    Process {
        id: playerProcess

        command: [
            "bash",
            "-c",
            "p=$(playerctl -l 2>/dev/null | while read pl; do [ \"$(playerctl -p \"$pl\" status 2>/dev/null)\" = \"Playing\" ] && { echo \"$pl\"; break; }; done | head -1); " +
            "[ -z \"$p\" ] && p=$(playerctl -l 2>/dev/null | head -1); " +
            "if [ -n \"$p\" ]; then " +
            "playerctl -p \"$p\" metadata --format '{{title}}|{{artist}}|{{status}}|{{mpris:artUrl}}|{{position}}|{{mpris:length}}' 2>/dev/null; " +
            "else printf 'Музыка|Плеер не запущен|Stopped'; fi"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("|")

                if (parts.length >= 6) {
                    playerTitle = parts[0] || "Музыка"
                    playerArtist = parts[1] || "Неизвестный исполнитель"
                    playerStatus = parts[2] || "Stopped"
                    playerArt = parts[3] || ""
                    playerPosition = parseFloat(parts[4]) || 0
                    playerLength = parseFloat(parts[5]) || 0
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // MIC TOGGLE ПО КЛИКУ
    // ─────────────────────────────────────────────

    Process {
        id: micToggleProcess

        command: ["bash", "-c", "/home/wonder/.local/bin/mic-osd"]
    }

    Process {
        id: wsSwitchProcess

        command: ["true"]
    }

    // Переключение темы — по бинду Super+F2 (binds.lua), кнопка в баре удалена

    // ─────────────────────────────────────────────
    // LENS TRANSITION — круглая «линза» при смене темы.
    // rice-theme пишет ~/.config/rice/transition.json с путём к новым
    // обоям; здесь поверх экрана рисуется растущий круг с мягким краем,
    // тонким ободком в цвет акцента и затемнением снаружи. Когда круг
    // накрывает экран — под ним подменяются обои (awww img -t none).
    // ─────────────────────────────────────────────

    property string lensPath: ""
    property string lensSeed: ""
    property string lensAccent: ""
    property int lensKick: 0

    function startLens(path, seed) {
        lensPath = path;
        lensSeed = seed || "";
        lensKick++;
    }

    FileView {
        id: transitionFile

        path: "/home/wonder/.config/rice/transition.json"

        watchChanges: true
        onFileChanged: transitionFile.reload()
        onLoaded: {
            try {
                const t = JSON.parse(transitionFile.text());
                if (!t || !t.image) return;
                root.lensAccent = t.accent || "";
                if (t.image !== root.lensPath) {
                    root.startLens(t.image, t.seed);
                } else if (t.seed && t.seed !== root.lensSeed) {
                    // зерно догнало в фазе зависания — подкладываем
                    // без рестарта анимации
                    root.lensSeed = t.seed;
                    if (lensWin.visible && popAnim.running)
                        seedProc.running = true;
                }
            } catch (e) {}
        }
    }

    // ─────────────────────────────────────────────
    // BAR
    // ─────────────────────────────────────────────

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            implicitHeight: 38

            // Только фон между карточками
            color: pal.barBg


            Behavior on color {
                ColorAnimation {
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }

            // ─────────────────────────────────────
            // ЛЕВАЯ ЧАСТЬ
            // ─────────────────────────────────────

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                spacing: 5

                // ARCH
                Rectangle {
                    width: 34
                    height: 30
                    radius: 9

                    color: pal.surface

                    border.width: 1
                    border.color: pal.border

                    Text {
                        anchors.centerIn: parent

                        text: ""

                        color: pal.accent

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }

                        font.pixelSize: 18
                    }
                }

                // WORKSPACES
                Repeater {
                    model: 6

                    Rectangle {
                        required property int index

                        width: 30
                        height: 30
                        radius: 9

                        property bool isFocused: {
                            let workspace =
                                Hyprland.workspaces.values.find(
                                    w => w.id === index + 1
                                )

                            return workspace
                                ? workspace.focused
                                : false
                        }

                        color: isFocused
                            ? pal.accent
                            : pal.surface

                        border.width: 1

                        border.color: isFocused
                            ? pal.accent
                            : pal.border

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 140
                            }
                        }

                        Text {
                            anchors.centerIn: parent

                            text: index + 1

                            color: isFocused
                                ? pal.onAccent
                                : pal.text2

                            font.pixelSize: 13
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {
                                wsSwitchProcess.command = ["bash", "-c", "hyprctl dispatch 'hl.dsp.focus({ workspace = " + (index + 1) + " })'"]
                                wsSwitchProcess.running = true
                            }

                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }

            // ─────────────────────────────────────
            // ЦЕНТР — ЧАСЫ
            // ─────────────────────────────────────

            Rectangle {
                anchors.centerIn: parent

                width: timeText.width + 24
                height: 30
                radius: 9

                color: pal.surface

                border.width: 1
                border.color: pal.border

                Text {
                    id: timeText

                    anchors.centerIn: parent

                    text: currentTime

                    color: pal.text

                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea {
                    z: 100
                    anchors.fill: parent

                    cursorShape: Qt.PointingHandCursor

                    onClicked: root.calVisible = !root.calVisible
                }
            }

            // ─────────────────────────────────────
            // ПРАВАЯ ЧАСТЬ
            // ─────────────────────────────────────

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                spacing: 5

                // РАСКЛАДКА
                Rectangle {
                    width: layoutText.width + 18
                    height: 30
                    radius: 9

                    color: pal.surface

                    border.width: 1
                    border.color: pal.border

                    Text {
                        id: layoutText

                        anchors.centerIn: parent

                        text: layout

                        color: pal.text2

                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                // ГРОМКОСТЬ
                Rectangle {
                    width: 72
                    height: 30
                    radius: 9

                    color: pal.surface

                    border.width: 1
                    border.color: pal.border

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: ""
                            color: pal.text2
                            font.pixelSize: 13
                        }

                        Text {
                            id: volumeText
                            text: volume + "%"
                            color: pal.text2
                            font.pixelSize: 13
                        }
                    }
                }


// МИКРОФОН
Rectangle {
    width: 34
    height: 30
    radius: 9

    color: micState === "MUTE"
        ? pal.micBg
        : pal.surface

    border.width: 1

    border.color: micState === "MUTE"
        ? pal.micBorder
        : pal.border

    Text {
        anchors.centerIn: parent

        text: micState === "MUTE"
            ? ""
            : ""

        color: micState === "MUTE"
            ? pal.micText
            : pal.text2

        font.pixelSize: 16
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: micToggleProcess.running = true
    }

    Behavior on color {
        ColorAnimation {
            duration: 180
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 180
        }
    }
}
 
               // СКОРОСТЬ СКАЧИВАНИЯ
                Rectangle {
                    width: speedText.width + 20
                    height: 30
                    radius: 9

                    color: pal.surface

                    border.width: 1
                    border.color: pal.border

                    Text {
                        id: speedText

                        anchors.centerIn: parent

                        text: "↓ " + downloadSpeed + " MB/s"

                        color: "#89dceb"

                        font.pixelSize: 13
                        font.bold: true
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: lensWin

            required property var modelData

            screen: modelData
            visible: false
            exclusiveZone: -1
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            // окно полностью прозрачно для мыши и клавиатуры
            mask: Region {}

            readonly property real maxR: Math.hypot(width, height) / 2 + 60
            property real hangR: 0
            property real bloomP: 0
            // ободок точно по краю круга обоев: во время зависания сидит
            // на «зёрне» (90), в фазе bloom повторяет кривую awww grow
            readonly property real ringR: Math.max(hangR, maxR * bloomP)
            property bool swapping: false
            property color lensAccent: root.lensAccent !== ""
                ? root.lensAccent
                : root.palTo.accent

            function begin() {
                lensWin.hangR = 0;
                lensWin.bloomP = 0;
                lensWin.swapping = false;
                lensWin.visible = true;
                lensContent.opacity = 1;
                dim.opacity = 0;
                ring.opacity = 0.9;
                halo1.opacity = 0.20;
                halo2.opacity = 0.10;
                if (root.lensSeed !== "")
                    seedProc.running = true;
                popAnim.restart();
            }

            Connections {
                target: root

                function onLensKickChanged() {
                    lensWin.begin();
                }
            }

            // фаза 1: появляется затемнение и ободок-«линза», дышит и висит
            SequentialAnimation {
                id: popAnim

                ParallelAnimation {
                    NumberAnimation {
                        target: dim
                        property: "opacity"
                        to: 0.32
                        duration: 260
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: lensWin
                        property: "hangR"
                        from: 0
                        to: 90
                        duration: 340
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.3
                    }
                }

                NumberAnimation {
                    target: lensWin
                    property: "hangR"
                    from: 90
                    to: 99
                    duration: 230
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: lensWin
                    property: "hangR"
                    from: 99
                    to: 90
                    duration: 240
                    easing.type: Easing.InOutQuad
                }

                onFinished: {
                    swapProc.running = true;
                    bloomAnim.restart();
                }
            }

            // весь визуал линзы (для плавного фейда в конце)
            Item {
                id: lensContent

                anchors.fill: parent

                // кинематографичное затемнение экрана
                Rectangle {
                    id: dim

                    anchors.fill: parent
                    color: "#000000"
                    opacity: 0
                }

                // внешний ореол вокруг края круга
                Rectangle {
                    id: halo2

                    anchors.centerIn: parent
                    width: lensWin.ringR * 2 + 56
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 22
                    border.color: lensWin.lensAccent
                    opacity: 0.10
                }

                // внутренний ореол
                Rectangle {
                    id: halo1

                    anchors.centerIn: parent
                    width: lensWin.ringR * 2 + 26
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 12
                    border.color: lensWin.lensAccent
                    opacity: 0.20
                }

                // тонкий яркий ободок-«линза» в цвет акцента темы
                Rectangle {
                    id: ring

                    anchors.centerIn: parent
                    width: lensWin.ringR * 2
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 3
                    border.color: lensWin.lensAccent
                    opacity: 0.9
                }
            }

            Process {
                id: swapProc

                // настоящий круг обоев: awww раскрывает новые обои из центра
                command: ["bash", "-c",
                    'awww img "$LENS_IMG" -t grow --transition-pos center '
                    + '--transition-duration 0.9 --transition-fps 60 '
                    + '--transition-bezier 0.4,0,0.6,1']
                environment: ({ LENS_IMG: root.lensPath })
            }

            Process {
                id: seedProc

                // мгновенно подкладываем «зерно»: кружок новых обоев в
                // центре, чтобы внутри ободка обои были уже при зависании
                command: ["bash", "-c", 'awww img "$LENS_SEED" -t none']
                environment: ({ LENS_SEED: root.lensSeed })
            }

            // фаза 2: круг обоев растёт, ободок и ореол бегут по краю
            // (bloomP повторяет кривую awww — ободок не убегает вперёд)
            ParallelAnimation {
                id: bloomAnim

                NumberAnimation {
                    target: lensWin
                    property: "bloomP"
                    from: 0
                    to: 1
                    duration: 900
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.4, 0, 0.6, 1, 1, 1]
                }
                NumberAnimation {
                    target: dim
                    property: "opacity"
                    to: 0.10
                    duration: 900
                }
                NumberAnimation {
                    target: halo1
                    property: "opacity"
                    to: 0.08
                    duration: 900
                }
                NumberAnimation {
                    target: halo2
                    property: "opacity"
                    to: 0.04
                    duration: 900
                }
                onFinished: fadeAnim.restart()
            }

            // фаза 3: экран накрыт — плавно гасим подсветку
            SequentialAnimation {
                id: fadeAnim

                ParallelAnimation {
                    NumberAnimation {
                        target: dim
                        property: "opacity"
                        to: 0
                        duration: 280
                    }
                    NumberAnimation {
                        target: ring
                        property: "opacity"
                        to: 0
                        duration: 280
                    }
                    NumberAnimation {
                        target: halo1
                        property: "opacity"
                        to: 0
                        duration: 280
                    }
                    NumberAnimation {
                        target: halo2
                        property: "opacity"
                        to: 0
                        duration: 280
                    }
                }
                ScriptAction {
                    script: {
                        lensWin.visible = false;
                        lensWin.swapping = false;
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // КАЛЕНДАРЬ (клик по часам)
    // ─────────────────────────────────────────────

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData

            visible: root.calVisible

            exclusiveZone: -1

            anchors {
                top: true
            }

            margins {
                top: 44
            }

            implicitWidth: 320
            implicitHeight: 372

            color: "transparent"

            Rectangle {
                id: calCard

                anchors.centerIn: parent

                width: 300
                height: 344

                radius: 14

                color: pal.surface

                border.width: 1
                border.color: pal.accent

                property date viewDate: new Date()

                property int viewYear: viewDate.getFullYear()
                property int viewMonth: viewDate.getMonth()
                property int firstWeekday: (new Date(viewYear, viewMonth, 1).getDay() + 6) % 7
                property int daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()

                readonly property var monthNames: ["ЯНВАРЬ", "ФЕВРАЛЬ", "МАРТ", "АПРЕЛЬ", "МАЙ", "ИЮНЬ", "ИЮЛЬ", "АВГУСТ", "СЕНТЯБРЬ", "ОКТЯБРЬ", "НОЯБРЬ", "ДЕКАБРЬ"]

                Column {
                    anchors.fill: parent
                    anchors.margins: 14

                    spacing: 8
                    Item {
                        width: parent.width
                        height: 30

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            width: 30
                            height: 30
                            radius: 8

                            color: pal.onAccent

                            Text {
                                anchors.centerIn: parent

                                text: "‹"

                                color: pal.accent

                                font.pixelSize: 18
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent

                                cursorShape: Qt.PointingHandCursor

                                onClicked: calCard.viewDate = new Date(calCard.viewYear, calCard.viewMonth - 1, 1)
                            }
                        }

                        Text {
                            anchors.centerIn: parent

                            text: calCard.monthNames[calCard.viewMonth] + " " + calCard.viewYear

                            color: pal.text

                            font.pixelSize: 13
                            font.bold: true
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            width: 30
                            height: 30
                            radius: 8

                            color: pal.onAccent

                            Text {
                                anchors.centerIn: parent

                                text: "›"

                                color: pal.accent

                                font.pixelSize: 18
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent

                                cursorShape: Qt.PointingHandCursor

                                onClicked: calCard.viewDate = new Date(calCard.viewYear, calCard.viewMonth + 1, 1)
                            }
                        }
                    }

                    Grid {
                        columns: 7

                        spacing: 4

                        Repeater {
                            model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

                            Text {
                                required property string modelData
                                required property int index

                                width: 34

                                horizontalAlignment: Text.AlignHCenter

                                text: modelData

                                color: index >= 5 ? pal.red : pal.text2

                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        Repeater {
                            model: 42

                            Rectangle {
                                required property int index

                                property int dayNum: index - calCard.firstWeekday + 1
                                property date cellDate: new Date(calCard.viewYear, calCard.viewMonth, dayNum)
                                property bool isCurrentMonth: dayNum >= 1 && dayNum <= calCard.daysInMonth
                                property bool isToday: cellDate.getFullYear() === new Date().getFullYear() && cellDate.getMonth() === new Date().getMonth() && cellDate.getDate() === new Date().getDate()

                                width: 34
                                height: 32

                                radius: 8

                                color: isToday ? pal.accent : "transparent"

                                border.width: isCurrentMonth && !isToday ? 1 : 0
                                border.color: pal.border

                                Text {
                                    anchors.centerIn: parent

                                    text: parent.dayNum

                                    color: {
                                        if (parent.isToday) return pal.onAccent
                                        if (!parent.isCurrentMonth) return pal.dim
                                        return parent.cellDate.getDay() >= 5 ? pal.red : pal.text
                                    }

                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    anchors.fill: parent

                                    onClicked: root.calVisible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════
    // CONTROL CENTER
    // ═════════════════════════════════════════════

    property bool controlCenterVisible: false

    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            root.controlCenterVisible = !root.controlCenterVisible
        }
    }

    PanelWindow {
        id: controlCenter

        screen: Quickshell.screens[0]

        visible: root.controlCenterVisible

        aboveWindows: true
        exclusiveZone: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        mask: Region {
            item: ccScrim
        }

        function alpha(col, a) {
            const c = Qt.color(col);
            return Qt.rgba(c.r, c.g, c.b, a);
        }

        // Затемнённая подложка: карточка читается контрастно,
        // клик мимо карточки закрывает центр
        Rectangle {
            id: ccScrim

            anchors.fill: parent

            color: Qt.rgba(0.02, 0.02, 0.06, 0.55)

            opacity: root.controlCenterVisible ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent

                onClicked: root.controlCenterVisible = false
            }
        }

        // Мягкое акцентное свечение за карточкой
        Rectangle {
            id: ccGlow

            anchors.centerIn: parent

            width: ccCard.width + 16
            height: ccCard.height + 16
            radius: 30

            color: controlCenter.alpha(pal.accent, 0.10)

            opacity: root.controlCenterVisible ? 1 : 0
            scale: ccCard.scale

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }
        Rectangle {
            id: ccCard

            anchors.centerIn: parent

            width: 920
            height: 726

            radius: 24

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.lighter(pal.surface, 1.14)
                }

                GradientStop {
                    position: 1
                    color: Qt.darker(pal.surface, 1.16)
                }
            }

            border.width: 1
            border.color: pal.border

            opacity: root.controlCenterVisible ? 1 : 0
            scale: root.controlCenterVisible ? 1 : 0.94

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.12
                }
            }

            // ловит клики по пустым местам карточки,
            // чтобы они не проваливались на подложку
            MouseArea {
                anchors.fill: parent
            }

            Column {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 16

                // HEADER
                Item {
                    id: ccHeader

                    width: parent.width
                    height: 54

                    Rectangle {
                        id: ccAccentBar

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        width: 4
                        height: 36
                        radius: 2

                        color: pal.accent
                    }

                    Column {
                        anchors.left: ccAccentBar.right
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: "Control Center"
                            color: pal.text
                            font.pixelSize: 24
                            font.bold: true
                        }

                        Text {
                            text: root.currentTime
                            color: pal.text2
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        id: ccClose

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        width: 42
                        height: 42
                        radius: 12

                        color: ccCloseMa.containsMouse
                            ? controlCenter.alpha(pal.red, 0.16)
                            : controlCenter.alpha(pal.text, 0.06)

                        border.width: 1
                        border.color: ccCloseMa.containsMouse
                            ? controlCenter.alpha(pal.red, 0.45)
                            : controlCenter.alpha(pal.border, 0.8)

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent

                            text: "✕"
                            color: ccCloseMa.containsMouse ? pal.red : pal.text2
                            font.pixelSize: 17

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: ccCloseMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.controlCenterVisible = false
                        }
                    }
                }
                // AUDIO
                Row {
                    width: parent.width
                    height: 140
                    spacing: 14

                    Rectangle {
                        id: volumeCard

                        width: (parent.width - 14) / 2
                        height: parent.height
                        radius: 18

                        color: pal.accent

                        function changeVolume(delta) {
                            root.volumeChanging = true

                            var value = Math.min(
                                200,
                                Math.max(0, root.volumeControl + delta)
                            )

                            root.volumeControl = value
                            root.volume = String(Math.round(value))

                            volumeApplyProcess.targetVolume = value

                            if (!volumeApplyProcess.busy) {
                                volumeApplyProcess.busy = true
                                volumeApplyProcess.running = true
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 18

                            width: 42
                            height: 42
                            radius: 12

                            color: controlCenter.alpha(pal.onAccent, 0.16)

                            Text {
                                anchors.centerIn: parent
                                text: "󰕾"
                                color: pal.onAccent
                                font.pixelSize: 20
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 18

                            text: root.volume + "%"
                            color: pal.onAccent
                            font.pixelSize: 22
                            font.bold: true
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 18
                            anchors.bottomMargin: 16

                            text: "Громкость"
                            color: pal.onAccent
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Item {
                            id: volumeSlider
                            z: 100

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            anchors.bottomMargin: 42

                            height: 24

                            Rectangle {
                                id: volumeTrack

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                height: 8
                                radius: 4
                                color: controlCenter.alpha(pal.onAccent, 0.22)

                                Rectangle {
                                    id: volumeFill

                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter

                                    height: parent.height
                                    radius: 4

                                    width: volumeSlider.width * Math.max(
                                        0,
                                        Math.min(1, root.volumeControl / 200)
                                    )

                                    color: pal.onAccent

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 70
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: volumeHandle

                                width: 18
                                height: 18
                                radius: 9

                                x: Math.max(
                                    0,
                                    Math.min(
                                        volumeTrack.width - width,
                                        volumeTrack.width *
                                        Math.max(
                                            0,
                                            Math.min(1, root.volumeControl / 200)
                                        ) - width / 2
                                    )
                                )

                                anchors.verticalCenter: parent.verticalCenter

                                color: pal.onAccent

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 70
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                function setVolumeFromMouse(mouseX) {
                                    var ratio = Math.max(
                                        0,
                                        Math.min(1, mouseX / volumeTrack.width)
                                    )

                                    var value = ratio * 200

                                    root.volumeChanging = true
                                    root.volumeControl = value
                                    root.volume = String(Math.round(value))

                                    volumeApplyProcess.targetVolume = value

                                    if (!volumeApplyProcess.busy) {
                                        volumeApplyProcess.busy = true
                                        volumeApplyProcess.running = true
                                    }
                                }

                                onPressed: function(mouse) {
                                    setVolumeFromMouse(mouse.x)
                                }

                                onPositionChanged: function(mouse) {
                                    if (pressed) {
                                        setVolumeFromMouse(mouse.x)
                                    }
                                }

                                onReleased: {
                                    root.volumeChanging = false
                                    root.statusProcess.running = true
                                }

                                onWheel: function(wheel) {
                                    volumeCard.changeVolume(
                                        wheel.angleDelta.y > 0 ? 5 : -5
                                    )
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onWheel: function(wheel) {
                                volumeCard.changeVolume(
                                    wheel.angleDelta.y > 0 ? 5 : -5
                                )
                            }

                            onReleased: {
                                root.volumeChanging = false
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 14) / 2
                        height: parent.height
                        radius: 18

                        color: root.micState === "MUTE" ? pal.micBg : pal.surface

                        border.width: 1
                        border.color: micMa.containsMouse
                            ? controlCenter.alpha(pal.accent, 0.55)
                            : (root.micState === "MUTE"
                                ? pal.micBorder
                                : pal.border)

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 18

                            width: 42
                            height: 42
                            radius: 12

                            color: controlCenter.alpha(
                                root.micState === "MUTE" ? pal.red : pal.accent,
                                0.14
                            )

                            Text {
                                anchors.centerIn: parent
                                text: root.micState === "MUTE" ? "󰍭" : "󰍬"
                                color: root.micState === "MUTE"
                                    ? pal.micText
                                    : pal.accent
                                font.pixelSize: 20
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 18
                            anchors.bottomMargin: 16

                            text: "Микрофон"
                            color: pal.text
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: 18
                            anchors.bottomMargin: 17

                            text: root.micState === "MUTE" ? "Выключен" : "Включен"
                            color: root.micState === "MUTE" ? pal.micText : pal.text2
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: micMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                Quickshell.execDetached([
                                    "bash",
                                    "-c",
                                    "/home/wonder/.local/bin/mic-osd"
                                ])
                                root.statusProcess.running = true
                            }
                        }
                    }
                }
                // SYSTEM
                Row {
                    width: parent.width
                    height: 96
                    spacing: 14

                    Rectangle {
                        width: (parent.width - 14) / 2
                        height: parent.height
                        radius: 18

                        color: pal.surface
                        border.width: 1
                        border.color: pal.border

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 18

                            width: 42
                            height: 42
                            radius: 12

                            color: controlCenter.alpha(pal.accent, 0.14)

                            Text {
                                anchors.centerIn: parent
                                text: "󰈀"
                                color: pal.accent
                                font.pixelSize: 19
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 76
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: "Сеть"
                                color: pal.text
                                font.pixelSize: 15
                                font.bold: true
                            }

                            Text {
                                text: "Загрузка данных"
                                color: pal.text2
                                font.pixelSize: 12
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 18

                            text: root.downloadSpeed + " MB/s"
                            color: pal.accent
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    Rectangle {
                        width: (parent.width - 14) / 2
                        height: parent.height
                        radius: 18

                        color: pal.surface
                        border.width: 1
                        border.color: pal.border

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 18

                            width: 42
                            height: 42
                            radius: 12

                            color: controlCenter.alpha(pal.accent, 0.14)

                            Text {
                                anchors.centerIn: parent
                                text: "󰓅"
                                color: pal.accent
                                font.pixelSize: 19
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 76
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: "Производительность"
                                color: pal.text
                                font.pixelSize: 15
                                font.bold: true
                            }

                            Text {
                                text: "CPU governor"
                                color: pal.text2
                                font.pixelSize: 12
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 18

                            width: perfLabel.implicitWidth + 24
                            height: 30
                            radius: 9

                            color: controlCenter.alpha(pal.accent, 0.14)
                            border.width: 1
                            border.color: controlCenter.alpha(pal.accent, 0.35)

                            Text {
                                id: perfLabel

                                anchors.centerIn: parent

                                text: "Performance"
                                color: pal.accent
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }
                }
                // QUICK ACTIONS
                Row {
                    width: parent.width
                    height: 82
                    spacing: 14

                    Rectangle {
                        id: notesQuickAction

                        width: (parent.width - 14) / 2
                        height: parent.height
                        radius: 18

                        color: notesQuickActionMa.containsMouse
                            ? Qt.lighter(pal.surface, 1.18)
                            : pal.surface

                        border.width: 1
                        border.color: notesQuickActionMa.containsMouse
                            ? controlCenter.alpha(pal.accent, 0.6)
                            : pal.border

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 18

                            width: 42
                            height: 42
                            radius: 12

                            color: controlCenter.alpha(pal.accent, 0.14)

                            Text {
                                anchors.centerIn: parent
                                text: "󰲂"
                                color: pal.accent
                                font.pixelSize: 21
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 76
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: "Ghostwriter"
                                color: pal.text
                                font.pixelSize: 15
                                font.bold: true
                            }

                            Text {
                                text: "Быстрые заметки"
                                color: pal.text2
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: notesQuickActionMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.controlCenterVisible = false
                                Quickshell.execDetached(["/home/wonder/.local/bin/ghostwriter-notes-clean"])
                            }
                        }
                    }

                    Rectangle {
                        id: calculatorQuickAction

                        width: (parent.width - 14) / 2
                        height: parent.height
                        radius: 18

                        color: calculatorQuickActionMa.containsMouse
                            ? Qt.lighter(pal.surface, 1.18)
                            : pal.surface

                        border.width: 1
                        border.color: calculatorQuickActionMa.containsMouse
                            ? controlCenter.alpha(pal.accent, 0.6)
                            : pal.border

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 18

                            width: 42
                            height: 42
                            radius: 12

                            color: controlCenter.alpha(pal.accent, 0.14)

                            Text {
                                anchors.centerIn: parent
                                text: "󰃬"
                                color: pal.accent
                                font.pixelSize: 21
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 76
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: "SwitchCalc"
                                color: pal.text
                                font.pixelSize: 15
                                font.bold: true
                            }

                            Text {
                                text: "Быстрые расчёты"
                                color: pal.text2
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: calculatorQuickActionMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.controlCenterVisible = false
                                Quickshell.execDetached(["switchcalc"])
                            }
                        }
                    }
                }
                // NOW PLAYING
                Rectangle {
                    width: parent.width
                    height: 160
                    radius: 18

                    color: pal.surface
                    border.width: 1
                    border.color: pal.border

                    Rectangle {
                        id: albumArt

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: 18
                        anchors.topMargin: 18

                        width: 56
                        height: 56
                        radius: 14

                        color: controlCenter.alpha(pal.accent, 0.12)
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.playerArt
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }

                        Text {
                            anchors.centerIn: parent

                            text: "♪"
                            color: pal.accent
                            font.pixelSize: 22

                            visible: root.playerArt === ""
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 90
                        anchors.top: parent.top
                        anchors.topMargin: 20
                        spacing: 4

                        Text {
                            text: "Сейчас играет"
                            color: pal.text2
                            font.pixelSize: 11
                        }

                        Text {
                            text: root.playerTitle
                            color: pal.text
                            font.pixelSize: 17
                            font.bold: true
                            elide: Text.ElideRight
                            width: 460
                        }

                        Text {
                            text: root.playerArtist
                            color: pal.text2
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            width: 460
                        }
                    }

                    // PROGRESS BAR
                    Text {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 18
                        anchors.bottomMargin: 74

                        text: {
                            let sec = Math.floor(root.playerPosition / 1000000)
                            return Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0")
                        }
                        color: pal.text2
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 18
                        anchors.bottomMargin: 74

                        text: {
                            let sec = Math.floor(root.playerLength / 1000000)
                            return Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0")
                        }
                        color: pal.text2
                        font.pixelSize: 10
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        anchors.bottomMargin: 68

                        height: 4
                        radius: 2

                        color: controlCenter.alpha(pal.text, 0.12)

                        Rectangle {
                            width: parent.width * (root.playerLength > 0
                                ? Math.min(1, root.playerPosition / root.playerLength)
                                : 0)
                            height: parent.height
                            radius: 2
                            color: pal.accent
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 14
                        spacing: 10

                        Rectangle {
                            width: 44
                            height: 40
                            radius: 12

                            color: prevMa.containsMouse
                                ? controlCenter.alpha(pal.text, 0.14)
                                : controlCenter.alpha(pal.text, 0.07)

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                color: pal.text
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: prevMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    Quickshell.execDetached([
                                        "bash",
                                        "-c",
                                        "p=$(playerctl -l 2>/dev/null | while read pl; do [ \"$(playerctl -p \"$pl\" status 2>/dev/null)\" = \"Playing\" ] && { echo \"$pl\"; break; }; done | head -1); [ -z \"$p\" ] && p=$(playerctl -l 2>/dev/null | head -1); [ -n \"$p\" ] && playerctl -p \"$p\" previous"
                                    ])
                                }
                            }
                        }

                        Rectangle {
                            width: 52
                            height: 40
                            radius: 12

                            color: playMa.containsMouse
                                ? Qt.lighter(pal.accent, 1.12)
                                : pal.accent

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: root.playerStatus === "Playing" ? "󰏤" : "󰐊"
                                color: pal.onAccent
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: playMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    Quickshell.execDetached([
                                        "bash",
                                        "-c",
                                        "p=$(playerctl -l 2>/dev/null | while read pl; do [ \"$(playerctl -p \"$pl\" status 2>/dev/null)\" = \"Playing\" ] && { echo \"$pl\"; break; }; done | head -1); [ -z \"$p\" ] && p=$(playerctl -l 2>/dev/null | head -1); [ -n \"$p\" ] && playerctl -p \"$p\" play-pause"
                                    ])
                                    playerProcess.running = true
                                }
                            }
                        }

                        Rectangle {
                            width: 44
                            height: 40
                            radius: 12

                            color: nextMa.containsMouse
                                ? controlCenter.alpha(pal.text, 0.14)
                                : controlCenter.alpha(pal.text, 0.07)

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                color: pal.text
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: nextMa

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    Quickshell.execDetached([
                                        "bash",
                                        "-c",
                                        "p=$(playerctl -l 2>/dev/null | while read pl; do [ \"$(playerctl -p \"$pl\" status 2>/dev/null)\" = \"Playing\" ] && { echo \"$pl\"; break; }; done | head -1); [ -z \"$p\" ] && p=$(playerctl -l 2>/dev/null | head -1); [ -n \"$p\" ] && playerctl -p \"$p\" next"
                                    ])
                                }
                            }
                        }
                    }
                }
                // POWER
                Row {
                    width: parent.width
                    height: 62
                    spacing: 10

                    Rectangle {
                        width: (parent.width - 30) / 4
                        height: parent.height
                        radius: 14

                        color: pwLockMa.containsMouse
                            ? Qt.lighter(pal.surface, 1.5)
                            : Qt.lighter(pal.surface, 1.28)

                        border.width: 1
                        border.color: pwLockMa.containsMouse
                            ? controlCenter.alpha(pal.accent, 0.5)
                            : pal.border

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰌾"
                                color: pal.text
                                font.pixelSize: 19
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Блокировка"
                                color: pal.text2
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: pwLockMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.controlCenterVisible = false
                                Quickshell.execDetached(["hyprlock"])
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 30) / 4
                        height: parent.height
                        radius: 14

                        color: pwExitMa.containsMouse
                            ? Qt.lighter(pal.surface, 1.5)
                            : Qt.lighter(pal.surface, 1.28)

                        border.width: 1
                        border.color: pwExitMa.containsMouse
                            ? controlCenter.alpha(pal.accent, 0.5)
                            : pal.border

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰍃"
                                color: pal.text
                                font.pixelSize: 19
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Выйти"
                                color: pal.text2
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: pwExitMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.controlCenterVisible = false
                                Quickshell.execDetached([
                                    "hyprctl",
                                    "dispatch",
                                    "exit"
                                ])
                            }
                        }
                    }
                    Rectangle {
                        width: (parent.width - 30) / 4
                        height: parent.height
                        radius: 14

                        color: pwRebootMa.containsMouse
                            ? Qt.lighter(pal.surface, 1.5)
                            : Qt.lighter(pal.surface, 1.28)

                        border.width: 1
                        border.color: pwRebootMa.containsMouse
                            ? controlCenter.alpha(pal.accent, 0.5)
                            : pal.border

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰜉"
                                color: pal.text
                                font.pixelSize: 19
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Перезагрузка"
                                color: pal.text2
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: pwRebootMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.controlCenterVisible = false
                                Quickshell.execDetached([
                                    "systemctl",
                                    "reboot"
                                ])
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 30) / 4
                        height: parent.height
                        radius: 14

                        color: pwOffMa.containsMouse
                            ? Qt.lighter(pal.red, 1.12)
                            : pal.red

                        border.width: 1
                        border.color: controlCenter.alpha(pal.red, 0.6)

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰐥"
                                color: pal.onAccent
                                font.pixelSize: 19
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Выключение"
                                color: controlCenter.alpha(pal.onAccent, 0.85)
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: pwOffMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                root.controlCenterVisible = false
                                Quickshell.execDetached([
                                    "systemctl",
                                    "poweroff"
                                ])
                            }
                        }
                    }
                }
            }
        }
    }

}
