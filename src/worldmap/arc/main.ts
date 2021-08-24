(() => {

function calculateAngles(n: number, scale: number): number[ ] {
    const radToDeg = 180 / Math.PI
    const wtf = scale * (2 * 4.9 * Math.PI) / 160
    let a = wtf + 1
    const result = [a * radToDeg]
    for (let i = 1; i < n; i++) {
        a += wtf / a
        a += wtf / a
        result[i] = a * radToDeg
    }
    return result
}

const msToAngle: readonly number[ ] = (() => {
    const result = calculateAngles(256, 4.75)
    const tmp = calculateAngles(1280, .96)
    for (let i = 256; i < 1500; i++)
        result[i] = tmp[i - 220] + 1440
    return result
})()

function formatArc(a: number, b: number): string {
    return (msToAngle[b] - msToAngle[a]).toFixed(1).replace("-", "−")
}

function getNumber($input: HTMLInputElement): number {
    return $input.checkValidity() ? $input.valueAsNumber : NaN
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
