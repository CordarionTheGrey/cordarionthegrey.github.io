"use strict";
(function () {
    function calculateAngles(n, scale) {
        var radToDeg = 180 / Math.PI;
        var wtf = scale * (2 * 4.9 * Math.PI) / 160;
        var a = wtf + 1;
        var result = [a * radToDeg];
        for (var i = 1; i < n; i++) {
            a += wtf / a;
            a += wtf / a;
            result[i] = a * radToDeg;
        }
        return result;
    }
    var msToAngle = (function () {
        var result = calculateAngles(256, 4.75);
        var tmp = calculateAngles(1280, .96);
        for (var i = 256; i < 1500; i++)
            result[i] = tmp[i - 220] + 1440;
        return result;
    })();
    function formatArc(a, b) {
        return (msToAngle[b] - msToAngle[a]).toFixed(1).replace("-", "−");
    }
    function getNumber($input) {
        return $input.checkValidity() ? $input.valueAsNumber : NaN;
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
