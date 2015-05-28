{Range} = require 'atom'

# erb supported blocks
ERB_BLOCKS = [['<%=', '%>'], ['<%', '%>'], ['<%-', '-%>'], ['<%=', '-%>'], ['<%#', '%>'], ['<%', '-%>']]
ERB_REGEX = '<%(=?|-?|#?)\s{2}(-?)%>'
# matches opening bracket that is not followed by the closing one
ERB_OPENER_REGEX = '<%[\\=\\-\\#]?' #'(?!.*%>)' <-- commented out for the moment...
# matches the closing bracket.
ERB_CLOSER_REGEX = "-?%>"

module.exports =
  activate: ->
    atom.commands.add "atom-workspace", "erb-snippets:erb_tags": => @erb_tags()

  erb_tags: ->
    # This assumes the active pane item is an editor
    editor = atom.workspace.getActivePaneItem()

    # looping through each selection
    for selection in editor.getSelections() by 1
      # flag if original selection was empty
      selection_was_empty = selection.isEmpty()
      # store the selection text
      selection_text = selection.getText()
      # remove the selection text from buffer
      selection.deleteSelectedText()
      # get the current cursor
      current_cursor = selection.cursor

      # searching for opening and closing brackets
      [opener, closer] = @find_surrounding_blocks editor, current_cursor
      if opener? and closer?
        # if brackets found - replacing them with the next ones.
        @replace_erb_block(editor, opener, closer, current_cursor)
      else
         # if the brackets were't found - inserting new ones.
        @insert_erb_block(editor, current_cursor)

      # restore selection text if needed
      if !selection_was_empty
        restore_text_range = editor.getBuffer().insert current_cursor.getBufferPosition(), selection_text
        selection.setBufferRange restore_text_range

  find_surrounding_blocks: (editor, current_cursor) ->
    opener = closer = null

    # grabbing the whole line
    current_line = current_cursor.getCurrentLineBufferRange()

    # one region to the left of the cursor and one to the right
    left_range  = new Range current_line.start, current_cursor.getBufferPosition()
    right_range = new Range current_cursor.getBufferPosition(), current_line.end

    # searching in the left range for an opening bracket
    found_openers = []
    editor.getBuffer().scanInRange new RegExp(ERB_OPENER_REGEX, 'g'), left_range, (result) ->
      found_openers.push result.range
    # if found, setting a range for it, using the last match - the rightmost bracket found
    opener = found_openers[found_openers.length-1] if found_openers

    # searching in the right range for an opening bracket
    found_closers = []
    editor.getBuffer().scanInRange new RegExp(ERB_CLOSER_REGEX, 'g'), right_range, (result) ->
      found_closers.push result.range
    # if found, setting a new range, using the first match - the leftmost bracket found
    closer = found_closers[0] if found_closers

    return [opener, closer]

  insert_erb_block: (editor, current_cursor) ->
    # inserting the first block in the list
    default_block = ERB_BLOCKS[0]

    # inserting opening bracket
    opening_tag = editor.getBuffer().insert current_cursor.getBufferPosition(), default_block[0]+' '
    # storing position between brackets
    desired_position = current_cursor.getBufferPosition()
    # inserting closing bracket
    closing_tag = editor.getBuffer().insert current_cursor.getBufferPosition(), ' '+default_block[1]
    # setting desired cursor position
    current_cursor.setBufferPosition( desired_position )


  replace_erb_block: (editor, opener, closer, current_cursor) ->
    # getting the next block in the list
    opening_bracket = editor.getBuffer().getTextInRange(opener)
    closing_bracket = editor.getBuffer().getTextInRange(closer)
    next_block = @get_next_erb_block editor, opening_bracket, closing_bracket

    # replacing in reverse order because line length might change
    editor.getBuffer().setTextInRange(closer, next_block[1])
    editor.getBuffer().setTextInRange(opener, next_block[0])

  get_next_erb_block: (editor, opening_bracket, closing_bracket) ->
    for block, i in ERB_BLOCKS
      if JSON.stringify([opening_bracket, closing_bracket]) == JSON.stringify(block)
        # if outside of scope - returning the first block
        return if i+1 >= ERB_BLOCKS.length then ERB_BLOCKS[0] else ERB_BLOCKS[i+1]

    # in case we haven't found the block in the list, returning the first one
    return ERB_BLOCKS[0]
