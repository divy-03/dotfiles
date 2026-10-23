import QtQuick

// The WLED strip over its JSON API (http://<host>/json/...). Colors, effects
// and brightness go to every segment, like `theme wled` does.
QtObject {
    id: w

    property string host: ""
    property bool online: false
    property bool on: false
    property int bri: 128
    property int fx: 0
    property int sx: 128
    property int ix: 128
    property color color: "#ffffff"
    property bool live: false
    property bool audioOn: false
    property string mic: ""
    property var segIds: [0]
    property var effects: []   // [{ id, name, audio }]

    signal polled

    property var pendingColor: null
    property var pendingBri: null

    function request(method, path, body, done) {
        if (!host)
            return
        var x = new XMLHttpRequest()
        x.timeout = 2500
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return
            if (x.status >= 200 && x.status < 300) {
                w.online = true
                if (done)
                    done(x.responseText)
            } else {
                w.online = false
            }
        }
        x.open(method, "http://" + host + path)
        if (body !== undefined) {
            x.setRequestHeader("Content-Type", "application/json")
            x.send(JSON.stringify(body))
        } else {
            x.send()
        }
    }

    function post(state) {
        state.v = false
        request("POST", "/json/state", state)
    }

    function segments(props) {
        return segIds.map(function (id) {
            var s = { id: id }
            for (var k in props)
                s[k] = props[k]
            return s
        })
    }

    function poll() {
        request("GET", "/json/si", undefined, function (text) {
            var d
            try { d = JSON.parse(text) } catch (e) { return }
            var st = d.state, info = d.info
            w.on = st.on
            w.bri = st.bri
            var seg = st.seg[st.mainseg] || st.seg[0]
            w.segIds = st.seg.map(function (s) { return s.id })
            w.fx = seg.fx
            w.sx = seg.sx
            w.ix = seg.ix
            if (!pendingColor)
                w.color = Qt.rgba(seg.col[0][0] / 255, seg.col[0][1] / 255, seg.col[0][2] / 255, 1)
            w.live = info.live === true
            w.audioOn = st.AudioReactive ? st.AudioReactive.on === true : false
            var src = info.u && info.u["Audio Source"]
            w.mic = src ? src.join("").trim() : ""
            w.polled()
        })
    }

    function loadEffects() {
        request("GET", "/json/effects", undefined, function (names) {
            request("GET", "/json/fxdata", undefined, function (data) {
                var n = JSON.parse(names), d = JSON.parse(data), list = []
                for (var i = 0; i < n.length; i++) {
                    if (n[i] === "RSVD" || n[i].indexOf("-") === 0)
                        continue
                    // slider;colors;palette;flags;defaults, where the flags
                    // hold v (volume) or f (frequency) for sound effects
                    var flags = (d[i] || "").split(";")[3] || ""
                    list.push({ id: i, name: n[i], audio: /[vf]/.test(flags) })
                }
                w.effects = list
            })
        })
    }

    function setPower(value) {
        w.on = value
        post({ on: value })
    }

    function setBrightness(value, released) {
        w.bri = value
        pendingBri = value
        if (released)
            flush()
        else
            throttle.start()
    }

    function setColor(c, released) {
        w.color = c
        pendingColor = c
        if (released)
            flush()
        else
            throttle.start()
    }

    function setEffect(id) {
        w.fx = id
        post({ on: true, seg: segments({ fx: id }) })
    }

    function setSpeed(value) {
        w.sx = value
        post({ seg: segments({ sx: value }) })
    }

    function setIntensity(value) {
        w.ix = value
        post({ seg: segments({ ix: value }) })
    }

    function setAudio(value) {
        w.audioOn = value
        post({ AudioReactive: { on: value } })
    }

    function flush() {
        throttle.stop()
        var s = {}
        if (pendingBri !== null) {
            s.bri = Math.max(1, pendingBri)
            pendingBri = null
        }
        if (pendingColor !== null) {
            var c = pendingColor
            s.on = true
            s.seg = segments({ fx: 0, col: [[Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)]] })
            pendingColor = null
        }
        if (s.bri !== undefined || s.seg !== undefined)
            post(s)
    }

    // at most ~8 writes a second while dragging, the ESP is not fast
    property Timer throttle: Timer {
        interval: 120
        onTriggered: w.flush()
    }
}
