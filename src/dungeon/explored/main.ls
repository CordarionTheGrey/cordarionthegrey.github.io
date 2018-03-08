readFile = (file, callback) !->
  new FileReader
    ..onload = !-> callback it.target.result
    ..readAsText file


extractMap = (html, callback) !->
  # Extract the map to avoid building a DOM for the whole page.
  callback that.0 if //
    <div \s [^<>]*? \bid \s* = \s* .? \s* \bd?map\b
    [\s\S]*?
    </div> \s* </div> \s* </div>
  //i.exec html


parseMap = (html) ->
  doc = document.createElement \div
  doc.innerHTML = html # Logs an error if gets 404 while attempting to load a resource.
  for row in doc.getElementsByClassName \dml
    line = [..textContent for row.getElementsByClassName \dmc]
    line.join ""


appPorts = Elm.Main.embed document.getElementById \main-wrapper .ports

appPorts.readFile.subscribe ([inputSelector, outputSelector]) !->
  input = document.querySelector inputSelector
  file = input.files.0
  return unless file?
  do
    # Communication JS -> Elm is broken in v0.18.0, so process the file on our side.
    html <-! readFile file
    map <-! extractMap html
    document.querySelector outputSelector
      ..value = parseMap map .join '\n'
      ..dispatchEvent new Event \input

  input.value = "" # Reset to allow selecting the (possibly modified) file again.
