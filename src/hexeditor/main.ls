# Не кидайтесь помидорами, пожалуйста, у меня было 6 часов на написание прототипа.
"use strict"


const DEFAULT_SCALE = 3 # Must be synced with the corresponding variable in CSS.
const DEFAULT_EDGE_THICKNESS = 0.25
const PALETTES =
  \palette-tile-placer
  \palette-object-registry
  \palette-tile-inspector
  \palette-edge-inspector


/**
 * @typedef {Object} Tile
 * @property {Vec} pos
 * @property {string} color
 * @property {?number} id
 * @property {!SVGElement} node
 * @property {!SVGElement} polygon
 * @property {!SVGElement} label
 * @property {!SVGElement} sublabel
 * @property {!SVGElement} pic
 */


/**
 * @typedef {Object} Edge
 * @property {Vec} pos0
 * @property {Vec} pos1
 * @property {number} thickness
 * @property {!SVGElement} line
 */


# Globals.
model =
  svgRoot: null
  tiles: { }
  edges: { }
  idCounter: -1
  auxTile: null
  activePal: ""
  placerAction: ""
  curInspected: null
  # For edge inspecting.
  curInspected1: null
  curInspected2: null
  curInspectedEdge: null


customEventListeners = { }


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
   * @param {GUIp.common.islandsMap.Vec} arrow
   * @param {GUIp.common.islandsMap.Vec} pos
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


$id = -> document.getElementById it


moveTileRaw = (tile, x, y) !->
  tile.transform.baseVal.0.matrix
    ..e = x
    ..f = y


# SVG creation function.
newSVG = (tagName, attrs, children) ->
  node = document.createElementNS \http://www.w3.org/2000/svg, tagName
  for key in Object.keys attrs
    node.setAttribute key, attrs[key]
  if children
    [node.appendChild .. for children]
  node


newTileNode = (pos, id, color) ->
  children =
    newSVG \polygon, do
      points: "9.5,-5.5 9.5,5.5 0,11 -9.5,5.5 -9.5,-5.5 0,-11"
      fill: color
    newSVG \text, {class: \tile-label}
    newSVG \text, {class: \tile-sublabel, y: 6}
    # newSVG \image, { }
  if id?
    children.push newSVG \text, {class: \tile-id, y: -6}
  newSVG \g, {class: \hex-tile, transform: "translate(0,0)"}, children
    xy = Vec.toCartesian pos, 11 # A magic number, yeah.
    moveTileRaw .., xy.0, xy.1
    ..lastChild.textContent = \# + id if id?


placeTile = (pos, id, color) ->
  console.assert pos !of model.tiles, "A tile is placed above another one"
  node = newTileNode pos, id, color
  model.svgRoot.appendChild node
  polygon = node.firstChild
  label = polygon.nextSibling
  model.tiles[pos] = {pos, color, id, node, polygon, label, sublabel: label.nextSibling, pic: null}


unplaceTile = (pos) !->
  tile = model.tiles[pos]
  unless tile
    console.assert false, "Cannot unplace non-existent tile"
    return
  model.svgRoot.removeChild tile.node
  delete model.tiles[pos]


getEdgeKey = (pos0, pos1) ->
  console.assert pos0 <= pos1, "Invalid parameter order in getEdgeKey"
  pos0 .<<. 16 .|. pos1


getEdge = (pos0, pos1) ->
  if pos0 > pos1
    t = pos0
    pos0 = pos1
    pos1 = t

  model.edges[getEdgeKey pos0, pos1]


placeEdge = (pos0, pos1, thickness) ->
  if pos0 > pos1
    t = pos0; pos0 = pos1; pos1 = t

  key = getEdgeKey pos0, pos1
  console.assert key !of model.edges, "An edge is placed above another one"

  a = model.tiles[pos0]
  b = model.tiles[pos1]
  if a.id < b.id
    o = a; a = b; b = o
  switch Vec.sub b.pos, a.pos
    case 0x0001 /*E*/   => x1 =  9.5; y1 = -5.5; x2 =  9.5; y2 = 5.5
    case 0x00FF /*W*/   => x1 = -9.5; y1 = -5.5; x2 = -9.5; y2 = 5.5
    case 0x0100 /*SSE*/ => x1 =  9.5; y1 =  5.5; x2 = 0;    y2 =  11
    case 0xFF00 /*NNW*/ => x1 = -9.5; y1 = -5.5; x2 = 0;    y2 = -11
    case 0xFF01 /*NNE*/ => x1 =  9.5; y1 = -5.5; x2 = 0;    y2 = -11
    case 0x01FF /*SSW*/ => x1 = -9.5; y1 =  5.5; x2 = 0;    y2 =  11

  line = newSVG \line, {x1, y1, x2, y2, style: "stroke-width:#{thickness}"}
  a.node.appendChild line
  model.edges[key] = {pos0, pos1, thickness, line}


main = !->
  removeEventListener \DOMContentLoaded, main

  # Move #svg-root to the center of its <svg>.
  model.svgRoot = $id \svg-root
  svg = model.svgRoot.parentNode
  coeff = 0.5 / DEFAULT_SCALE
  rootX = svg.clientWidth * coeff
  rootY = svg.clientHeight * coeff
  moveTileRaw model.svgRoot, rootX, rootY

  # Palette initialization.
  for palId in PALETTES
    pal = $id palId
    let palId, contents = pal.getElementsByClassName(\contents).0
      contents.classList.add \hidden
      pal.getElementsByClassName \header .0.addEventListener \click, !->
        if model.activePal
          $id that .getElementsByClassName \contents .0.classList.add \hidden
          fireCustomListener that, \close
          if palId == that
            model.activePal = ""
            return

        fireCustomListener palId, \open
        contents.classList.toggle \hidden
        model.activePal = palId

  # Placer palette initialization.
  placeButton = $id \place-tile
  unplaceButton = $id \unplace-tile

  placeButton.addEventListener \click, !->
    unplaceButton.classList.remove \pressed-button
    placeButton.classList.toggle \pressed-button
    model.placerAction = if model.placerAction != \place then \place else ""
  unplaceButton.addEventListener \click, !->
    placeButton.classList.remove \pressed-button
    unplaceButton.classList.toggle \pressed-button
    model.placerAction = if model.placerAction != \unplace then \unplace else ""

  addCustomListener \palette-tile-placer, \close, !->
    placeButton.classList.remove \pressed-button
    unplaceButton.classList.remove \pressed-button
    model.placerAction = ""

  # Mouse move inside the SVG.
  svg.addEventListener \mousemove, (ev) !->
    return unless model.placerAction == \place
    # FIXME: This formula is not accurate, but it's good enough for now.
    pos = Vec.fromCartesian ev.offsetX - rootX, ev.offsetY - rootY, 11 # A magic number.
    unless pos of model.tiles
      if model.auxTile
        unplaceTile that.pos
      model.auxTile = placeTile pos, null, \#F2F2F2
        ..node.classList.add \ghost

  # Click on the SVG.
  svg.addEventListener \mousedown, (ev) !->
    return if ev.button
    if model.placerAction == \place
      if model.auxTile
        unplaceTile model.auxTile.pos
        placeTile model.auxTile.pos, ++model.idCounter, \#EEEEEE
        model.auxTile = null
    else if model.placerAction == \unplace
      pos = Vec.fromCartesian ev.offsetX - rootX, ev.offsetY - rootY, 11 # A magic number.
      if pos of model.tiles
        unplaceTile pos
    else if model.activePal == \palette-tile-inspector
      pos = Vec.fromCartesian ev.offsetX - rootX, ev.offsetY - rootY, 11 # A magic number.
      if (tile = model.tiles[pos]) && tile != model.curInspected
        if model.curInspected
          model.curInspected.node.classList.remove \inspected
        model.curInspected = tile
        tile.node.classList.add \inspected
        $id \inspected-id .textContent = \# + tile.id
        $id \inspected-color .value = tile.color
        $id \inspected-label .value = tile.label.textContent
        $id \inspected-sublabel .value = tile.sublabel.textContent
        # $id \inspected-pic .value = tile.pic.getAttributeNS \xlink, \href
    else if model.activePal == \palette-edge-inspector
      pos = Vec.fromCartesian ev.offsetX - rootX, ev.offsetY - rootY, 11 # A magic number.
      if (tile = model.tiles[pos])
        if model.curInspected1 && !model.curInspected2 && Vec.dist(model.curInspected1.pos, tile.pos) <= 1
          model.curInspected2 = tile if tile != model.curInspected1
        else
          model.curInspected1 = tile
          model.curInspected2 = null
        $id \inspected-edge .textContent =
          "#{if model.curInspected1?id? then \# + that else '?'} — #{if model.curInspected2?id? then \# + that else '?'}"
        input = $id \inspected-edge-thickness
        unless (input.disabled = !model.curInspected2)
          edge = getEdge model.curInspected1.pos, model.curInspected2.pos
          if edge
            model.curInspectedEdge = edge
          else
            edge = model.curInspectedEdge =
              placeEdge model.curInspected1.pos, model.curInspected2.pos, DEFAULT_EDGE_THICKNESS
          input.value = edge.thickness
        else
          input.value = ""

  # Mouse leave from the SVG.
  svg.addEventListener \mouseleave, !->
    return unless model.placerAction == \place
    if model.auxTile
      unplaceTile that.pos
      model.auxTile = null

  $id \inspected-color .addEventListener \input, !->
    that.color = that.polygon.style.fill = @value if model.curInspected

  $id \inspected-label .addEventListener \input, !->
    that.label.textContent = @value if model.curInspected

  $id \inspected-sublabel .addEventListener \input, !->
    that.sublabel.textContent = @value if model.curInspected

  # $id \inspected-pic .addEventListener \input, !->
  #   model.curInspected.pic.setAttributeNS \xlink, \href, @value

  addCustomListener \palette-tile-inspector, \close, !->
    if model.curInspected
      model.curInspected.node.classList.remove \inspected
      model.curInspected = null
    $id \inspected-id .textContent = "<Не выбрано>"
    $id \inspected-color .textContent =
      $id \inspected-label .textContent =
        $id \inspected-sublabel .textContent = ""
    # $id \inspected-pic .textContent = ""

  $id \inspected-edge-thickness .addEventListener \input, !->
    model.curInspectedEdge.thickness = model.curInspectedEdge.line.style.strokeWidth = @value

  addCustomListener \palette-edge-inspector, \close, !->
    model.curInspected1 = model.curInspected2 = null
    $id \inspected-edge .textContent = "? — ?"
    $id \inspected-edge-thickness .value = ""


addEventListener \DOMContentLoaded, main
