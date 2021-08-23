(() => {

function calculateAngles(max: number, scale: number): number[ ] {
    const result = [ ]
    const radToDeg = 180 / Math.PI
    const wtf = scale * (2 * 4.9 * Math.PI) / 160
    let a = wtf
    for (let i = 0; i <= max; i++) {
        a += wtf / a
        result[i] = a * radToDeg
        a += wtf / a
    }
    return result
}

const convertMsToAngle: (milestones: number) => number = (() => {
    const angles0: readonly number[ ] = calculateAngles(256, 4.75)
    const angles1: readonly number[ ] = calculateAngles(1499, .96)
    const offset = angles0[256] - angles0[220] + 1440
    return (ms: number) => ms < 256 ? angles0[ms] : angles1[ms - 220] + offset
})()

function formatArc(a: number, b: number): string {
    return (convertMsToAngle(b) - convertMsToAngle(a)).toFixed(1).replace("-", "−")
}

function getNumber(input: HTMLInputElement): number {
    return input.checkValidity() ? input.valueAsNumber : NaN
}

const $from = document.getElementById("from")! as HTMLInputElement
const $to = document.getElementById("to")! as HTMLInputElement
const $arc = document.getElementById("arc")! as HTMLInputElement

function recalc() {
    let a, b
    $arc.value = (a = getNumber($from)) === a && (b = getNumber($to)) === b ? formatArc(a, b) : ""
}

$from.addEventListener("input", recalc)
$to.addEventListener("input", recalc)

})()
