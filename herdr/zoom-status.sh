#!/bin/sh

# Render the active tab's pane layout as a compact block thumbnail. Full and
# half blocks belong to the zoomed pane; shaded cells belong to hidden panes.
set -eu

herdr_bin=${HERDR_BIN_PATH:-herdr}
pane_id=${HERDR_ACTIVE_PANE_ID:-}

[ -n "$pane_id" ] || exit 0

layout=$("$herdr_bin" pane layout --pane "$pane_id" 2>/dev/null) || exit 0

printf '%s\n' "$layout" | jq -r '
  def cell_state($layout; $x; $y):
    ($layout.panes
      | map(select(
          .rect.x <= $x
          and $x < (.rect.x + .rect.width)
          and .rect.y <= $y
          and $y < (.rect.y + .rect.height)
        ))
      | .[0].pane_id // null) as $pane_id
    | if $pane_id == null then 0
      elif $pane_id == $layout.focused_pane_id then 2
      else 1
      end;

  def full_block($state):
    if $state == 2 then "█"
    elif $state == 1 then "░"
    else " "
    end;

  def half_block($top; $bottom):
    if $top == 2 and $bottom == 2 then "█"
    elif $top == 2 then "▀"
    elif $bottom == 2 then "▄"
    elif $top == 1 or $bottom == 1 then "░"
    else " "
    end;

  def render($layout; $xs; $ys):
    (($ys | length) - 1) as $rows
    | if $rows == 1 then
        [range(0; (($xs | length) - 1)) as $column
          | (($xs[$column] + $xs[$column + 1]) / 2) as $x
          | (($ys[0] + $ys[1]) / 2) as $y
          | full_block(cell_state($layout; $x; $y))
        ]
        | join("")
      else
        [range(0; (($ys | length) / 2 | floor)) as $band
          | ($band * 2) as $top_row
          | ($top_row + 1) as $bottom_row
          | [range(0; (($xs | length) - 1)) as $column
              | (($xs[$column] + $xs[$column + 1]) / 2) as $x
              | (($ys[$top_row] + $ys[$top_row + 1]) / 2) as $top_y
              | cell_state($layout; $x; $top_y) as $top
              | (if $bottom_row < $rows then
                   (($ys[$bottom_row] + $ys[$bottom_row + 1]) / 2) as $bottom_y
                   | cell_state($layout; $x; $bottom_y)
                 else 0
                 end) as $bottom
              | half_block($top; $bottom)
            ]
          | join("")
        ]
        | join(" ")
      end;

  .result.layout as $layout
  | select($layout.zoomed == true)
  | ([
      $layout.panes[]
      | .rect.x,
        (.rect.x + .rect.width)
    ] | unique | sort) as $xs
  | ([
      $layout.panes[]
      | .rect.y,
        (.rect.y + .rect.height)
    ] | unique | sort) as $ys
  | (($xs | length) - 1) as $columns
  | (($ys | length) - 1) as $rows
  | if ($columns * $rows) <= 16 and $columns <= 8 and $rows <= 4 then
      render($layout; $xs; $ys)
    else
      ([range(0; 7)
        | $layout.area.x + (($layout.area.width * .) / 6)]) as $sample_xs
      | ([range(0; 3)
          | $layout.area.y + (($layout.area.height * .) / 2)]) as $sample_ys
      | render($layout; $sample_xs; $sample_ys)
    end
'
