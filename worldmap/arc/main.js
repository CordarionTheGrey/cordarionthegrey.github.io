"use strict";
(function () {
    function calculateAngles(max, scale) {
        var result = [];
        var radToDeg = 180 / Math.PI;
        var wtf = scale * (2 * 4.9 * Math.PI) / 160;
        var a = wtf;
        for (var i = 0; i <= max; i++) {
            a += wtf / a;
            result[i] = a * radToDeg;
            a += wtf / a;
        }
        return result;
    }
    var convertMsToAngle = (function () {
        var angles0 = calculateAngles(256, 4.75);
        var angles1 = calculateAngles(1499, .96);
        var offset = angles0[256] - angles0[220] + 1440;
        return function (ms) { return ms < 256 ? angles0[ms] : angles1[ms - 220] + offset; };
    })();
    function formatArc(a, b) {
        return (convertMsToAngle(b) - convertMsToAngle(a)).toFixed(1).replace("-", "−");
    }
    function getNumber(input) {
        return input.checkValidity() ? input.valueAsNumber : NaN;
    }
    var $from = document.getElementById("from");
    var $to = document.getElementById("to");
    var $arc = document.getElementById("arc");
    function recalc() {
        var a, b;
        $arc.value = (a = getNumber($from)) === a && (b = getNumber($to)) === b ? formatArc(a, b) : "";
    }
    $from.addEventListener("input", recalc);
    $to.addEventListener("input", recalc);
})();
