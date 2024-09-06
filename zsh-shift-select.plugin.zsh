# vim: set ts=4:
# Copyright 2022-present Jakub Jirutka <jakub@jirutka.cz>.
# SPDX-License-Identifier: MIT
#
# Emacs shift-select mode for Zsh - select text in the command line using Shift
# as in many text editors, browsers and other GUI programs.
#
# Version: 0.1.1
# Homepage: <https://github.com/jirutka/zsh-shift-select>

# Move cursor to the end of the buffer.
# This is an alternative to builtin end-of-buffer-or-history.
function end-of-buffer() {
	CURSOR=${#BUFFER}
	zle end-of-line -w  # trigger syntax highlighting redraw
}
zle -N end-of-buffer

# Move cursor to the beginning of the buffer.
# This is an alternative to builtin beginning-of-buffer-or-history.
function beginning-of-buffer() {
	CURSOR=0
	zle beginning-of-line -w  # trigger syntax highlighting redraw
}
zle -N beginning-of-buffer

# Kill the selected region and switch back to the main keymap.
function shift-select::kill-region() {
	zle kill-region -w
	zle -K main
}
zle -N shift-select::kill-region

################################
# Start of My custom functions
################################

function shift-select::delete-and-input() {
	zle kill-region -w
	zle -K main
	zle -U "$KEYS"
}
zle -N shift-select::delete-and-input

function shift-select::set-cursor-to-beginning-of-region() {
	local cursor=$CURSOR
	if [[ $CURSOR -gt $MARK ]]; then
		cursor=$MARK
	fi

	zle deactivate-region -w
	zle -K main
	CURSOR=$cursor
}
zle -N shift-select::set-cursor-to-beginning-of-region

function shift-select::set-cursor-to-end-of-region() {
	local cursor=$MARK
	if [[ $CURSOR -gt $MARK ]]; then
		cursor=$CURSOR
	fi

	zle deactivate-region -w
	zle -K main
	CURSOR=$cursor
}
zle -N shift-select::set-cursor-to-end-of-region

function shift-select::copy-to-clipboard() {
	# Copy region to clipboard (and killring)
	zle copy-region-as-kill -w
	zle copy-region-as-kill -w
	local text=$killring[1]
	echo -n "$text" | pbcopy
}
zle -N shift-select::copy-to-clipboard

function shift-select::cut-to-clipboard() {
	# Copy region to clipboard (and killring)
	zle copy-region-as-kill -w
	zle copy-region-as-kill -w
	local text=$killring[1]
	echo -n "$text" | pbcopy

	# Delete the selected region
	zle kill-region -w
	zle -K main
}
zle -N shift-select::cut-to-clipboard

function shift-select::delete-and-paste() {
	# Bring content of clipboard
	clipboard=$(pbpaste)
	
	# Replace selected region with clipboard content
	zle kill-region -w
	zle -K main
	zle -U "$clipboard"
}
zle -N shift-select::delete-and-paste

################################
# End of My custom functions
################################

# Deactivate the selection region, switch back to the main keymap and process
# the typed keys again.
function shift-select::deselect-and-input() {
	zle deactivate-region -w
	# Switch back to the main keymap (emacs).
	zle -K main
	# Push the typed keys back to the input stack, i.e. process them again,
	# but now with the main keymap.
	zle -U "$KEYS"
}
zle -N shift-select::deselect-and-input

# If the selection region is not active, set the mark at the cursor position,
# switch to the shift-select keymap, and call $WIDGET without 'shift-select::'
# prefix. This function must be used only for shift-select::<widget> widgets.
function shift-select::select-and-invoke() {
	if (( !REGION_ACTIVE )); then
		zle set-mark-command -w
		zle -K shift-select
	fi
	zle ${WIDGET#shift-select::} -w
}

function {
	emulate -L zsh

	# Create a new keymap for the shift-selection mode.
	bindkey -N shift-select

	# Bind all possible key sequences to deselect-and-input, i.e. it will be used
	# as a fallback for "unbound" key sequences.
	bindkey -M shift-select -R '^@'-'^?' shift-select::deselect-and-input

	local kcap seq seq_mac widget

	# Bind Shift keys in the emacs and shift-select keymaps.
	for	kcap   seq          seq_mac    widget (             # key name
		kLFT   '^[[1;2D'    x          backward-char        # Shift + LeftArrow
		kRIT   '^[[1;2C'    x          forward-char         # Shift + RightArrow
		kri    '^[[1;2A'    x          up-line              # Shift + UpArrow
		kind   '^[[1;2B'    x          down-line            # Shift + DownArrow
		kHOM   '^[[1;2H'    x          beginning-of-line    # Shift + Home
		x      '^[[97;6u'   '^[a'      beginning-of-line    # Ctrl/Option + A
		x      '^[[97;6u'   '^[A'      beginning-of-line    # Shift + Ctrl/Option + A
		kEND   '^[[1;2F'    x          end-of-line          # Shift + End
		x      '^[[101;6u'  '^[e'      end-of-line          # Ctrl/Option + E
		x      '^[[101;6u'  '^[E'      end-of-line          # Shift + Ctrl/Option + E
		x      '^[[1;6D'    '^[^[[D'   backward-word        # Shift + Ctrl/Option + LeftArrow
		x      '^[[1;6C'    '^[^[[C'   forward-word         # Shift + Ctrl/Option + RightArrow
		x      '^[[1;6H'    '^[^[[H'   beginning-of-buffer  # Shift + Ctrl/Option + Home
		x      '^[[1;6F'    '^[^[[F'   end-of-buffer        # Shift + Ctrl/Option + End
	); do
		# Use alternative sequence (Option instead of Ctrl) on macOS, if defined.
		[[ "$OSTYPE" = darwin* && "$seq_mac" != x ]] && seq=$seq_mac

		zle -N shift-select::$widget shift-select::select-and-invoke
		bindkey -M emacs ${terminfo[$kcap]:-$seq} shift-select::$widget
		bindkey -M shift-select ${terminfo[$kcap]:-$seq} shift-select::$widget
	done
	
	#################################
	# Start of My custom keybindings
	#################################

	# left arrow - set cursor to start of selected region
	bindkey -M shift-select '^[[D' shift-select::set-cursor-to-beginning-of-region
	# right arrow - set cursor to end of selected region
	bindkey -M shift-select '^[[C' shift-select::set-cursor-to-end-of-region
	# alphabet, numbers, space - replaces selected region with inputted key
	bindkey -M shift-select -R 'a'-'z' shift-select::delete-and-input
	bindkey -M shift-select -R '0'-'9' shift-select::delete-and-input
	bindkey -M shift-select ' ' shift-select::delete-and-input
	# Ctrl/Option + y - copy selected region to clipboard
	bindkey -M shift-select '^[y' shift-select::copy-to-clipboard
	# Ctrl/Option + d - cut selected region to clipboard
	bindkey -M shift-select '^[d' shift-select::cut-to-clipboard
	# Ctrl/Option + p - replace selected region with clipboard content (i.e., paste)
	bindkey -M shift-select '^[p' shift-select::delete-and-paste

	#################################
	# End of My custom keybindings
	#################################

	# Bind keys in the shift-select keymap.
	for	kcap   seq        widget (                          # key name
		kdch1  '^[[3~'    shift-select::kill-region         # Delete
		bs     '^?'       shift-select::kill-region         # Backspace
	); do
		bindkey -M shift-select ${terminfo[$kcap]:-$seq} $widget
	done
}
