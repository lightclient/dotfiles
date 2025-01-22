local M = {
  "leoluz/nvim-dap-go",
  commit = "a5cc8dcad43f0732585d4793deb02a25c4afb766",
  event = "VeryLazy",
  dependencies = {
    {
      "mfussenegger/nvim-dap",
      event = "VeryLazy",
    },
  },
}

-- copied from dap-go.lua
local function get_arguments()
  local co = coroutine.running()
  if co then
    return coroutine.create(function()
      local args = {}
      vim.ui.input({ prompt = "Args: " }, function(input)
        args = vim.split(input or "", " ")
      end)
      coroutine.resume(co, args)
    end)
  else
    local args = {}
    vim.ui.input({ prompt = "Args: " }, function(input)
      args = vim.split(input or "", " ")
    end)
    return args
  end
end

function M.config()
  require("dap-go").setup {
    dap_configurations = {
      {
        type = "go",
        name = "Debug Package (Arguments)",
        request = "launch",
        program = "${fileDirname}",
        args = get_arguments,
      },
    }
  }
end

return M
