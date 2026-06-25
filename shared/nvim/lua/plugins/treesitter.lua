local function select_textobject(query)
  return function()
    require("nvim-treesitter-textobjects.select").select_textobject(query, "textobjects")
  end
end

local function move_textobject(method, query)
  return function()
    require("nvim-treesitter-textobjects.move")[method](query, "textobjects")
  end
end

local function swap_textobject(method, query)
  return function()
    require("nvim-treesitter-textobjects.swap")[method](query, "textobjects")
  end
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    commit = "f795520371e6563dac17a0d556f41d70ca86a789",
    lazy = true,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    opts = {
      select = {
        lookahead = true,
        selection_modes = {
          ["@function.outer"] = "V",
          ["@class.outer"] = "V",
          ["@loop.outer"] = "V",
        },
      },
      move = {
        set_jumps = true,
      },
    },
    keys = {
      {
        "am",
        select_textobject("@function.outer"),
        mode = { "x", "o" },
        desc = "Around method/function",
      },
      {
        "im",
        select_textobject("@function.inner"),
        mode = { "x", "o" },
        desc = "Inside method/function",
      },
      {
        "ac",
        select_textobject("@class.outer"),
        mode = { "x", "o" },
        desc = "Around class",
      },
      {
        "ic",
        select_textobject("@class.inner"),
        mode = { "x", "o" },
        desc = "Inside class",
      },
      {
        "al",
        select_textobject("@loop.outer"),
        mode = { "x", "o" },
        desc = "Around loop",
      },
      {
        "il",
        select_textobject("@loop.inner"),
        mode = { "x", "o" },
        desc = "Inside loop",
      },
      {
        "]m",
        move_textobject("goto_next_start", "@function.outer"),
        mode = { "n", "x", "o" },
        desc = "Next method/function start",
      },
      {
        "[m",
        move_textobject("goto_previous_start", "@function.outer"),
        mode = { "n", "x", "o" },
        desc = "Previous method/function start",
      },
      {
        "]M",
        move_textobject("goto_next_end", "@function.outer"),
        mode = { "n", "x", "o" },
        desc = "Next method/function end",
      },
      {
        "[M",
        move_textobject("goto_previous_end", "@function.outer"),
        mode = { "n", "x", "o" },
        desc = "Previous method/function end",
      },
      {
        "]]",
        move_textobject("goto_next_start", "@class.outer"),
        mode = { "n", "x", "o" },
        desc = "Next class start",
      },
      {
        "[[",
        move_textobject("goto_previous_start", "@class.outer"),
        mode = { "n", "x", "o" },
        desc = "Previous class start",
      },
      {
        "][",
        move_textobject("goto_next_end", "@class.outer"),
        mode = { "n", "x", "o" },
        desc = "Next class end",
      },
      {
        "[]",
        move_textobject("goto_previous_end", "@class.outer"),
        mode = { "n", "x", "o" },
        desc = "Previous class end",
      },
      {
        "<leader>ap",
        swap_textobject("swap_next", "@parameter.inner"),
        desc = "Swap with next parameter",
      },
      {
        "<leader>aP",
        swap_textobject("swap_previous", "@parameter.outer"),
        desc = "Swap with previous parameter",
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    opts = {
      mode = "topline",
      max_lines = 5,
      trim_scope = "inner",
    },
  },
}
