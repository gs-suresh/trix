#= require_self
#= require trix/utilities/dom
#= require trix/controllers/editor_controller
#= require trix/controllers/degraded_editor_controller

@Trix =
  isSupported: (config = {}) ->
    trixSupport = new BrowserSupport().getTrixSupport()

    switch config.mode ? "full"
      when "full"
        trixSupport.fullEditor
      when "degraded"
        trixSupport.degradedEditor
      else
        false

  install: (config) ->
    if @isSupported(config)
      installer = new Installer config
      installer.run()
      installer.editor

  attributes:
    bold:
      tagName: "strong"
      inheritable: true
      parser: ({style}) ->
        style["fontWeight"] is "bold" or style["fontWeight"] >= 700
    italic:
      tagName: "em"
      inheritable: true
      parser: ({style}) ->
        style["fontStyle"] is "italic"
    href:
      tagName: "a"
      parent: true
      parser: ({element}) ->
        if link = Trix.DOM.closest(element, "a")
          link.getAttribute("href")
    underline:
      style: { "text-decoration": "underline" }
      inheritable: true
    frozen:
      style: { "background-color": "highlight" }

  config:
    editorCSS: """
      .trix-editor[contenteditable=true]:empty:before {
        content: attr(data-placeholder);
        color: graytext;
      }

      .trix-editor .image-editor,
      .trix-editor .pending-attachment {
        position: relative;
        display: inline-block;
      }

      .trix-editor .image-editor img {
        outline: 1px dashed #333;
      }

      .trix-editor .image-editor .resize-handle {
        position: absolute;
        width: 8px;
        height: 8px;
        border: 1px solid #333;
        background: white;
      }

      .trix-editor .image-editor .resize-handle.se {
        bottom: -4px;
        right: -4px;
        cursor: nwse-resize;
      }
    """


class BrowserSupport
  required:
    "addEventListener" of document and
    "createTreeWalker" of document and
    "getComputedStyle" of window and
    "getSelection"     of window

  caretPosition:
    "caretPositionFromPoint" of document or
    "caretRangeFromPoint"    of document or
    "createTextRange"        of document.createElement("body")

  getTrixSupport: ->
    degradedEditor: @required
    fullEditor: @required and @caretPosition


class Installer
  constructor: (@config = {}) ->
    @setConfigElements()
    @config.autofocus ?= @config.textareaElement.hasAttribute("autofocus")

  run: ->
    @config.textElement = @createTextElement()
    @createStyleSheet()
    @editor = @createEditor()

  createEditor: ->
    switch @config.mode ? "full"
      when "full"
        new Trix.EditorController @config
      when "degraded"
        new Trix.DegradedEditorController @config

  setConfigElements: ->
    for key in "textarea toolbar input".split(" ")
      @config["#{key}Element"] = getElement(@config[key])
      delete @config[key]

  styleSheetId = "trix-styles"

  createStyleSheet: ->
    if !document.getElementById(styleSheetId) and css = Trix.config.editorCSS
      element = document.createElement("style")
      element.setAttribute("type", "text/css")
      element.setAttribute("id", styleSheetId)
      element.appendChild(document.createTextNode(css))
      document.querySelector("head").appendChild(element)

  textElementAttributes =
    contenteditable: "true"
    autocorrect: "off"

  createTextElement: ->
    textarea = @config.textareaElement

    element = document.createElement("div")
    element.innerHTML = textarea.value
    element.setAttribute(key, value) for key, value of textElementAttributes

    if placeholder = textarea.getAttribute("placeholder")
      element.setAttribute("data-placeholder", placeholder)

    classNames = (@config.className?.split(" ") ? []).concat("trix-editor")
    element.classList.add(name) for name in classNames

    visiblyReplaceTextAreaWithElement(textarea, element)
    disableObjectResizing(element)
    element

  visiblyReplaceTextAreaWithElement = (textarea, element) ->
    copyTextAreaStylesToElement(textarea, element)
    textarea.style["display"] = "none"
    textarea.parentElement.insertBefore(element, textarea)

  textareaStylesToCopy = "width position top left right bottom zIndex color".split(" ")
  textareaStylePatternToCopy = /(border|outline|padding|margin|background)[A-Z]+/

  copyTextAreaStylesToElement = (textarea, element) ->
    textareaStyle = window.getComputedStyle(textarea)

    for style in textareaStylesToCopy
      element.style[style] = textareaStyle[style]

    for key, value of textareaStyle when value and textareaStylePatternToCopy.test(key)
      element.style[key] = value

    element.style["minHeight"] = textareaStyle["height"]

  getElement = (elementOrId) ->
    if typeof(elementOrId) is "string"
      document.getElementById(elementOrId)
    else
      elementOrId

  disableObjectResizing = (element) ->
    if element instanceof FocusEvent
      event = element
      document.execCommand("enableObjectResizing", false, false)
      event.target.removeEventListener("focus", disableObjectResizing)
    else
      if document.queryCommandSupported?("enableObjectResizing")
        element.addEventListener("focus", disableObjectResizing, true)
      element.addEventListener("mscontrolselect", cancelEvent, true)

  cancelEvent = (event) ->
    event.preventDefault()
