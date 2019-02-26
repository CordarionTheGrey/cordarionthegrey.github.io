"use strict"


const DEFAULT_SCALE = 3 # Must be synced with the corresponding variable in CSS.
const DEFAULT_EDGE_THICKNESS = 0.25
const PALETTES =
  \palette-tile-placer
  \palette-object-registry
  \palette-tile-inspector
  \palette-edge-inspector


unless Object.values
  Object.values = (o) ->
    [o[..] for Object.keys o]


/**
 * @typedef {Object} Tile
 * @property {Vec} pos
 * @property {?number} id
 * @property {string} color
 * @property {string} textColor
 * @property {string} label
 * @property {string} sublabel
 */


/**
 * @typedef {Object} Edge
 * @property {Vec} pos0
 * @property {Vec} pos1
 * @property {string} color
 * @property {number} thickness
 */


$id = -> document.getElementById it


getEdgeKey = (pos0, pos1) ->
  pos0 .<<. 16 .|. pos1


createModel = ->
  tiles: { }
  edges: { }
  idCounter: -1


serializeModel = (model) ->
  JSON.stringify {
    tiles: Object.values model.tiles
    edges: Object.values model.edges
    model.idCounter
  }


deserializeModel = (s) ->
  o = JSON.parse s
  tiles = {[..pos, ..] for o.tiles}
  edges = {[getEdgeKey(..pos0, ..pos1), ..] for o.edges}
  {tiles, edges, o.idCounter}


createView = ->
  svgRoot: $id \svg-root # <g>

  tiles:     { } # <g>
  polygons:  { } # <polygon>
  labels:    { } # <text>
  sublabels: { } # <text>

  edges: { } # <line>


# Globals.
const customEventListeners = { }


addCustomListener = (target, type, action) !->
  customEventListeners[type] || (customEventListeners[type] = { })
    if ..[target]
      that.push action
    else
      ..[target] = [action]


fireCustomListener = (target, type) !->
  if customEventListeners[type]
    if that[target]
      for that
        try ..!
        catch => console.error e


# Hex vector library.
# https://bitbucket.org/Erinome/erinome-godville-ui-plus/src/master/source/common/imap/vec.js
``
/**
 * A vector on a hexagonal grid, packed into a 16-bit integral number: 0x0000RRQQ.
 *
 * @typedef {number} Vec
 */

// look, I have a picture for you!
/*
   |
  -0------>  X
   |------->  Q
   | \
   |  \
   |   \
   |    ┘
   v     R

   Y
*/

/** @namespace */
var Vec = {
  /**
   * @param {number} q
   * @param {number} r
   * @returns {Vec}
   */
  make: function(q, r) {
    return (q & 0xFF) | (r & 0xFF) << 8;
  },

  /**
   * @param {number} x
   * @param {number} y
   * @param {number} scale
   * @returns {Vec}
   */
  fromCartesian: function(x, y, scale) {
    var t = y / 3 / scale;
    return this.make(Math.round(x / Math.sqrt(3) / scale - t), Math.round(t * 2));
  },

  /**
   * @param {Vec} vec
   * @param {number} scale
   * @returns {!Array<number>} A 2-element array, namely, [x, y].
   */
  toCartesian: function(vec, scale) {
    // make use of sign-propagating right shift
    var q = vec << 24 >> 24,
      r = vec << 16 >> 24;
    return [(q + r * .5) * Math.sqrt(3) * scale, r * 1.5 * scale];
  },

  /**
   * @param {Vec} a
   * @param {Vec} b
   * @returns {Vec}
   */
  add: function(a, b) {
    return ((a + b) & 0xFF) | ((a + (b & 0xFF00)) & 0xFF00);
  },

  /**
   * @param {Vec} a
   * @param {Vec} b
   * @returns {Vec}
   */
  sub: function(a, b) {
    return ((a - b) & 0xFF) | ((a - (b & 0xFF00)) & 0xFF00);
  },

  /**
   * @param {Vec} vec
   * @param {number} n
   * @returns {Vec}
   */
  mul: function(vec, n) {
    return (vec << 24) * n >>> 24 | ((vec & 0xFF00) << 16) * n >>> 16;
  },

  /**
   * Compare two vectors as (r, q) pairs.
   *
   * @param {Vec} a
   * @param {Vec} b
   * @returns {number}
   */
  cmp: function(a, b) {
    return (
      ((a + 0x80) & 0xFF) | ((a + 0x8000) & 0xFF00)
    ) - (
      ((b + 0x80) & 0xFF) | ((b + 0x8000) & 0xFF00)
    );
  },

  /**
   * @param {Vec} vec
   * @returns {number}
   */
  len: function(vec) {
    var q = vec << 24 >> 24,
      r = vec << 16 >> 24,
      result = Math.abs(q + r);
    if ((q ^ r) < 0) { // if their signs are opposite
      return result + Math.min(Math.abs(q), Math.abs(r));
    }
    return result;
  },

  /**
   * @param {Vec} a
   * @param {Vec} b
   * @returns {number}
   */
  dist: function(a, b) {
    return this.len(this.sub(a, b));
  },

  /**
   * @param {Vec} arrow
   * @param {Vec} pos
   * @returns {boolean}
   */
  inArrowSector: function(arrow, pos) {
    if (!pos) return false;
    var q = pos << 24 >> 24,
      r = pos << 16 >> 24;
    switch (arrow) {
      case 0x0001: /*E*/   return r <= q && r << 1 >= -q;
      case 0x00FF: /*W*/   return r >= q && r << 1 <= -q;
      case 0x0100: /*SSE*/ return r >= q && r >= -q << 1;
      case 0xFF00: /*NNW*/ return r <= q && r <= -q << 1;
      case 0xFF01: /*NNE*/ return r >= -q << 1 && r << 1 <= -q;
      case 0x01FF: /*SSW*/ return r <= -q << 1 && r << 1 >= -q;
      case 0xFE01: /*N*/   return r < 0 && r === -q << 1;
      case 0x02FF: /*S*/   return r > 0 && r === -q << 1;
      default:             return false;
    }
  },

  /**
   * @private
   * @type {!Array<?Array<Vec>>}
   */
  _cache: [[0x0]],

  /**
   * Generate an array of all vectors whose length is exactly n. The array is sorted according to cmp.
   * These arrays are cached, so do not mutate them.
   *
   * @param {number} n
   * @returns {!Array<Vec>}
   */
  ofLen: function(n) {
    var result = this._cache[n], i;
    if (result) return result;
    for (i = this._cache.length; i < n; i++) {
      this._cache[i] = null;
    }
    result = [this.make(0, -n), this.make(0, n)];
    for (i = 1; i < n; i++) {
      result.push(
        this.make(-i, i - n),
        this.make(-i, n),
        this.make(i, -n),
        this.make(i, n - i)
      );
    }
    for (i = 0; i <= n; i++) {
      result.push(this.make(-n, i), this.make(n, -i));
    }
    return (this._cache[n] = result.sort(this.cmp));
  }
};
``


moveTileRaw = (tile, x, y) !->
  tile.transform.baseVal.0.matrix
    ..e = x
    ..f = y


# SVG creation function.
createNode = (tagName, attrs, children) ->
  node = document.createElementNS \http://www.w3.org/2000/svg, tagName
  [node.setAttribute .., attrs[..] for Object.keys attrs]
  if children
    [node.appendChild .. for children]
  node


createTile = (pos, id, color, textColor) ->
  {pos, id, color, textColor, label: "", sublabel: ""}


addTileToView = (view, {pos, id, color, textColor, label, sublabel}) !->
  console.assert pos !of view.tiles, "A tile is placed above another one"

  vPoly = createNode \polygon, do
    points: "9.5,-5.5 9.5,5.5 0,11 -9.5,5.5 -9.5,-5.5 0,-11"
    style:  "fill:#{color}"
  vLabel    = createNode \text, {class: \tile-label}
  vSublabel = createNode \text, {class: \tile-sublabel, y: 5.5}

  vLabel.textContent = label
  vSublabel.textContent = sublabel

  children = [vPoly, vLabel, vSublabel]
  if id?
    (children.3 = createNode \text, {class: \tile-id, y: -5.5})
    .textContent = \# + id

  view.polygons[pos] = vPoly
  view.labels[pos] = vLabel
  view.sublabels[pos] = vSublabel
  view.tiles[pos] = (createNode do
    \g
    class: \hex-tile
    style: "stroke:#{textColor}"
    transform: "translate(0,0)"
    children
  )
    xy = Vec.toCartesian pos, 11 # A magic number, yeah.
    moveTileRaw .., xy.0, xy.1
    view.svgRoot.appendChild ..


updateTileInView = (view, {
  pos,
  # Assuming `id` is immutable.
  color:     view.polygons[pos].style.fill,
  textColor: view.tiles[pos].style.stroke,
  label:     view.labels[pos].textContent,
  sublabel:  view.sublabels[pos].textContent,
}) !->


removeTileFromView = (view, {pos}) !->
  view.svgRoot.removeChild delete view.tiles[pos]
  delete view.polygons[pos]
  delete view.labels[pos]
  delete view.sublabels[pos]


getEdge = (model, pos0, pos1) ->
  model.edges[getEdgeKey pos0, pos1] || model.edges[getEdgeKey pos1, pos0]


createEdge = (model, pos0, pos1, thickness) ->
  if model.tiles[pos0].id >= model.tiles[pos1].id
    {pos0, pos1, color: \#444444, thickness}
  else
    {pos0: pos1, pos1: pos0, color: \#444444, thickness}


addEdgeToView = (view, {pos0, pos1, color, thickness}) !->
  # console.assert id0 >= id1, "Invalid edge direction"
  switch Vec.sub pos1, pos0 # There must be a place for magic in our world, so here it is.
    case 0x0001 /*E*/   => x1 =  9.5; y1 = -5.5; x2 =  9.5; y2 = 5.5
    case 0x00FF /*W*/   => x1 = -9.5; y1 = -5.5; x2 = -9.5; y2 = 5.5
    case 0x0100 /*SSE*/ => x1 =  9.5; y1 =  5.5; x2 =    0; y2 =  11
    case 0xFF00 /*NNW*/ => x1 = -9.5; y1 = -5.5; x2 =    0; y2 = -11
    case 0xFF01 /*NNE*/ => x1 =  9.5; y1 = -5.5; x2 =    0; y2 = -11
    case 0x01FF /*SSW*/ => x1 = -9.5; y1 =  5.5; x2 =    0; y2 =  11

  line = createNode \line, {x1, y1, x2, y2, style: "stroke:#{color};stroke-width:#{thickness}"}
  view.edges[getEdgeKey pos0, pos1] = line
  view.tiles[pos0].appendChild line


updateEdgeInView = (view, edge) !->
  view.edges[getEdgeKey edge.pos0, edge.pos1].style
    ..stroke = edge.color
    ..strokeWidth = edge.thickness


removeEdgeFromView = (view, edge) !->
  delete view.edges[getEdgeKey edge.pos0, edge.pos1]
    ..parentNode.removeChild ..


formatTileId = (model, pos) ->
  if pos?
    \# + model.tiles[pos].id
  else
    \?


loadModel = ->
  update = (key, action) !->
    try
      obj = JSON.parse localStorage.getItem key
      localStorage.setItem key, JSON.stringify action(obj) ? obj
    catch
      console.warn e
      console.info localStorage.getItem key

  m = m0 = localStorage.currentMigration || ""

  if m < \2019-02-26
    m  = \2019-02-26
    localStorage.map = '{"tiles":[],"edges":[],"idCounter":-1}'

  if m < \2019-02-26-1
    m  = \2019-02-26-1
    update \map, !-> [..textColor = \#444444 for it.tiles]

  if m < \2019-02-26-2
    m  = \2019-02-26-2
    update \map, !-> [..color = \#444444 for it.edges]

  localStorage.currentMigration = m if m != m0
  try
    deserializeModel localStorage.map
  catch
    console.error e
    console.info localStorage.map
    createModel!


saveModel = (model) !->
  localStorage.map = serializeModel model


main = !->
  removeEventListener \DOMContentLoaded, main

  model = loadModel!
  view = createView!
  [addTileToView view, .. for Object.values model.tiles .sort (a, b) -> a.id - b.id]
  [addEdgeToView view, .. for Object.values model.edges]

  uiModel =
    auxTile: null
    activePal: ""
    placerAction: ""
    curInspected: null
    # For edge inspecting.
    curInspected1: null
    curInspected2: null
    curInspectedEdge: null

  # Move #svg-root to the center of its <svg>.
  svg = view.svgRoot.parentNode
  coeff = 0.5 / DEFAULT_SCALE
  rootX = svg.clientWidth * coeff
  rootY = svg.clientHeight * coeff
  moveTileRaw view.svgRoot, rootX, rootY

  # Palette initialization.
  for palId in PALETTES
    pal = $id palId
    let palId, contents = pal.getElementsByClassName(\contents).0
      contents.classList.add \hidden
      pal.getElementsByClassName \header .0.addEventListener \click, !->
        if uiModel.activePal
          $id that .getElementsByClassName \contents .0.classList.add \hidden
          fireCustomListener that, \close
          if palId == that
            uiModel.activePal = ""
            return

        fireCustomListener palId, \open
        contents.classList.toggle \hidden
        uiModel.activePal = palId

  # Placer palette initialization.
  placeButton = $id \place-tile
  unplaceButton = $id \unplace-tile

  placeButton.addEventListener \click, !->
    unplaceButton.classList.remove \pressed-button
    placeButton.classList.toggle \pressed-button
    uiModel.placerAction = if uiModel.placerAction != \place then \place else ""
  unplaceButton.addEventListener \click, !->
    placeButton.classList.remove \pressed-button
    unplaceButton.classList.toggle \pressed-button
    uiModel.placerAction = if uiModel.placerAction != \unplace then \unplace else ""

  resetMap = !->
    return unless confirm "Вы действительно хотите полностью очистить карту?"
    model := createModel!
    saveModel model
    view.svgRoot
      while ..firstChild
        ..removeChild that
    view := createView!

  $id \reset-map .addEventListener \click, !-> setTimeout resetMap, 0
  addCustomListener \palette-tile-placer, \close, !->
    placeButton.classList.remove \pressed-button
    unplaceButton.classList.remove \pressed-button
    uiModel.placerAction = ""

  # Mouse move inside the SVG.
  svg.addEventListener \mousemove, (ev) !->
    return unless uiModel.placerAction == \place
    # FIXME: This formula is not accurate, but it's good enough for now.
    pos = Vec.fromCartesian ev.offsetX - rootX, ev.offsetY - rootY, 11 # A magic number.
    if uiModel.auxTile
      return if pos == that.pos
      removeTileFromView view, that

    if pos of model.tiles
      uiModel.auxTile = null
    else
      addTileToView view,
        uiModel.auxTile = createTile pos, null, \#F2F2F2, \#999

  # Click on the SVG.
  svg.addEventListener \mousedown, (ev) !->
    return if ev.button
    if uiModel.placerAction == \place
      if uiModel.auxTile
        removeTileFromView view, that
        addTileToView view,
          model.tiles[that.pos] = createTile that.pos, ++model.idCounter, \#EEEEEE, \#444444
        uiModel.auxTile = null
    else if uiModel.placerAction == \unplace
      pos = Vec.fromCartesian ev.offsetX - rootX, ev.offsetY - rootY, 11 # A magic number.
      if model.tiles[pos]
        delete model.tiles[pos]
        removeTileFromView view, that
    else if uiModel.activePal == \palette-tile-inspector
      pos = Vec.fromCartesian ev.offsetX - rootX, ev.offsetY - rootY, 11 # A magic number.
      if pos != uiModel.curInspected && (tile = model.tiles[pos])
        view.tiles[that].classList.remove \inspected if uiModel.curInspected?
        uiModel.curInspected = pos
        view.tiles[pos].classList.add \inspected

        $id \inspected-id .textContent = \# + tile.id
        $id \inspected-color .value = tile.color
        $id \inspected-text-color .value = tile.textColor
        $id \inspected-label .value = tile.label
        $id \inspected-sublabel .value = tile.sublabel
    else if uiModel.activePal == \palette-edge-inspector
      pos = Vec.fromCartesian ev.offsetX - rootX, ev.offsetY - rootY, 11 # A magic number.
      if (tile = model.tiles[pos])
        if uiModel.curInspected1? && !uiModel.curInspected2? && Vec.dist(uiModel.curInspected1, pos) == 1
          uiModel.curInspected2 = pos
        else
          uiModel.curInspected1 = pos
          uiModel.curInspected2 = null

        $id \inspected-edge .textContent =
          "#{formatTileId model, uiModel.curInspected1} — #{formatTileId model, uiModel.curInspected2}"
        thicknessInput = $id \inspected-edge-thickness
        colorInput = $id \inspected-edge-color
        if (thicknessInput.disabled = colorInput.disabled = !uiModel.curInspected2?)
          thicknessInput.value = colorInput.value = ""
        else
          unless (edge = getEdge model, uiModel.curInspected1, uiModel.curInspected2)
            edge = createEdge do
              model
              uiModel.curInspected1
              uiModel.curInspected2
              DEFAULT_EDGE_THICKNESS
            model.edges[getEdgeKey edge.pos0, edge.pos1] = edge
            addEdgeToView view, edge
          uiModel.curInspectedEdge = edge
          colorInput.value = edge.color
          thicknessInput.value = edge.thickness

    saveModel model

  # Mouse leave from the SVG.
  svg.addEventListener \mouseleave, !->
    return unless uiModel.placerAction == \place
    if uiModel.auxTile?
      removeTileFromView view, that
      uiModel.auxTile = null

  $id \inspected-color .addEventListener \input, !->
    if uiModel.curInspected?
      model.tiles[that]
        ..color = @value
        updateTileInView view, ..
      saveModel model

  $id \inspected-text-color .addEventListener \input, !->
    if uiModel.curInspected?
      model.tiles[that]
        ..textColor = @value
        updateTileInView view, ..
      saveModel model

  $id \inspected-label .addEventListener \input, !->
    if uiModel.curInspected?
      model.tiles[that]
        ..label = @value
        updateTileInView view, ..
      saveModel model

  $id \inspected-sublabel .addEventListener \input, !->
    if uiModel.curInspected?
      model.tiles[that]
        ..sublabel = @value
        updateTileInView view, ..
      saveModel model

  addCustomListener \palette-tile-inspector, \close, !->
    if uiModel.curInspected?
      view.tiles[that].classList.remove \inspected
      uiModel.curInspected = null
    $id \inspected-id .textContent = "<Не выбрано>"
    $id \inspected-color .textContent =
      $id \inspected-text-color .textContent =
        $id \inspected-label .textContent =
          $id \inspected-sublabel .textContent = ""

  $id \inspected-edge-thickness .addEventListener \input, !->
    if uiModel.curInspectedEdge
      that.thickness = @value
      updateEdgeInView view, that
      saveModel model

  $id \inspected-edge-color .addEventListener \input, !->
    if uiModel.curInspectedEdge
      that.color = @value
      updateEdgeInView view, that
      saveModel model

  addCustomListener \palette-edge-inspector, \close, !->
    uiModel.curInspected1 = uiModel.curInspected2 = null
    $id \inspected-edge .textContent = "? — ?"
    $id \inspected-edge-thickness .value =
      $id \inspected-edge-color .value = ""


addEventListener \DOMContentLoaded, main
