package main

TUI_Command :: struct
{
  type: TUI_CommandType,
  args: [3]string,
}

TUI_CommandType :: enum
{
  NONE,

  QUIT,
  HELP,
  CONTINUE,
  STEP,
  BREAKPOINT,
  VIEW,
}

TUI_RegisterViewType :: enum
{
  TEMPORARIES,
  SAVED,
  ARGUMENTS,
  EXTRAS,
}

TUI_RegisterViewSet :: bit_set[TUI_RegisterViewType]

@(private="file")
command_table: map[string]TUI_CommandType = {
  "q"     = .QUIT,
  "quit"  = .QUIT,
  "h"     = .HELP,
  "help"  = .HELP,
  "r"     = .CONTINUE,
  "run"   = .CONTINUE,
  ""      = .STEP,
  "s"     = .STEP,
  "step"  = .STEP,
  "b"     = .BREAKPOINT,
  "break" = .BREAKPOINT,
  "v"     = .VIEW,
  "view"  = .VIEW,
}

register_names: [RegisterID]string = {
  .X0  = "",
  .X1  = "ra",
  .X2  = "sp",
  .X3  = "gp",
  .X4  = "tp",
  .X5  = "t0",
  .X6  = "t1",
  .X7  = "t2",
  .X8  = "fp",
  .X9  = "s1",
  .X10 = "a0",
  .X11 = "a1",
  .X12 = "a2",
  .X13 = "a3",
  .X14 = "a4",
  .X15 = "a5",
  .X16 = "a6",
  .X17 = "a7",
  .X18 = "s2",
  .X19 = "s3",
  .X20 = "s4",
  .X21 = "s5",
  .X22 = "s6",
  .X23 = "s7",
  .X24 = "s8",
  .X25 = "s9",
  .X26 = "s10",
  .X27 = "s11",
  .X28 = "t3",
  .X29 = "t4",
  .X30 = "t5",
  .X31 = "t6",
}

tui_prompt_command :: proc() -> bool
{
  done: bool

  buf: [64]byte
  term.color(.GRAY)
  fmt.print("\n|> ")
  term.color(.WHITE)
  input_len, _ := os.read(os.stdin, buf[:])
  
  cmd_str := str_strip_crlf(string(buf[:input_len]))
  command, err := tui_command_from_string(cmd_str)

  if tui_resolve_error(err)
  {
    done = false
    return done
  }

  if command.type != .QUIT
  {
    fmt.print("\n")
  }

  switch command.type
  {
    case .QUIT:
    {
      sim.should_quit = true
      done = true
    }
    case .HELP:
    {
      tui_print_commands_list()
      done = false
    }
    case .STEP:
    {
      sim.step_to_next = true
      done = true
    }
    case .CONTINUE:
    {
      sim.step_to_next = false
      done = true
    }
    case .BREAKPOINT:
    {
      modifier: string
      line_idx: int

      if str_is_numeric(command.args[0])
      {
        line_idx = str_to_int(command.args[0]) - 1
        
        if sim.instructions[line_idx].has_breakpoint
        {
          term.color(.GRAY)
          fmt.printf("Breakpoint at line %i.\n", line_idx + 1)
          term.color(.WHITE)
        }
      }
      else
      {
        modifier = command.args[0]
        if command.args[1] != ""
        {
          line_idx = str_to_int(command.args[1]) - 1
        }

        switch modifier
        {
          case "set":
          {
            if sim.instructions[line_idx].has_breakpoint == false
            {
              sim.instructions[line_idx].has_breakpoint = true

              term.color(.GREEN)
              fmt.printf("Breakpoint set at line %i.\n", line_idx + 1)
              term.color(.WHITE)
            }
          }
          case "rem":
          {
            if sim.instructions[line_idx].has_breakpoint == true
            {
              sim.instructions[line_idx].has_breakpoint = false

              term.color(.ORANGE)
              fmt.printf("Breakpoint removed at line %i.\n", line_idx + 1)
              term.color(.WHITE)
            }
          }
          case "clear":
          {
            for i in 0..<MAX_LINES
            {
              sim.instructions[i].has_breakpoint = false
            }

            term.color(.ORANGE)
            fmt.print("Breakpoints cleared.\n")
            term.color(.WHITE)
          }
          case "list":
          {
            term.color(.GRAY)
            fmt.print("Breakpoints:\n")
            term.color(.WHITE)

            for i in 0..<MAX_LINES
            {
              if sim.instructions[i].has_breakpoint == true
              {
                fmt.printf(" %i\n", i)
              }
            }
          }
        }
      }
      
      done = false
    }
    case .VIEW:
    {
      if command.args[0] == "r" || command.args[0] == "reg"
      {
        set: TUI_RegisterViewSet
        switch command.args[1]
        {
          case "":                     set = {.TEMPORARIES, .SAVED, .ARGUMENTS}
          case "all":                  set = {.TEMPORARIES, .SAVED, .ARGUMENTS, .EXTRAS}
          case "temps", "temp", "t":   set = {.TEMPORARIES}
          case "saved", "s":           set = {.SAVED}
          case "args", "arg", "a":     set = {.ARGUMENTS}
          case "extras", "extra", "x": set = {.EXTRAS}
        }

        tui_print_register_view(set)
      }
    }
    case .NONE:
    {
      term.color(.RED)
      fmt.print("Please enter a valid command.\n")
      term.color(.WHITE)

      done = false
    }
  }
  
  return done
}

// NOTE(dg): Expects a string without leading whitespace
tui_command_from_string :: proc(str: string) -> (TUI_Command, TUI_Error)
{
  result: TUI_Command
  error: TUI_Error
  length := len(str)

  if length == 0
  {
    return TUI_Command{type=.STEP}, nil
  }

  start, end: int
  for i := 0; i <= 3 && end < length; i += 1
  {
    end = str_find_char(str, ' ', start)
    if end == -1 do end = length

    substr := str[start:end]
    
    if i == 0
    {
      result.type = command_table[substr]
    }
    else
    {
      result.args[i-1] = substr
    }

    start = end + 1
  }

  return result, error
}

tui_print_welcome :: proc()
{
  term.color(.GRAY)
  fmt.print("======= ARCH SIM =======\n")
  fmt.print("Type [r] to run program or [s] to step next instruction.\n")
  fmt.print("Type [h] for a list of commands.\n")
  term.color(.WHITE)
}

tui_print_sim_result :: proc(instruction: Instruction, idx: int)
{
  term.color(.GRAY)
  fmt.print("Instruction: ")
  term.color(.WHITE)
  for tok in instruction.tokens
  {
    if tok.data != ""
    {
      fmt.print(tok.data, "")
    }
  }
  fmt.printf(" (line %i)\n", idx+1)

  term.color(.GRAY)
  fmt.print("Address: ")
  term.color(.WHITE)
  fmt.printf("%#X\n", address_from_line_index(idx))

  term.color(.GRAY)
  fmt.print("Next address: ")
  term.color(.WHITE)
  fmt.printf("%#X\n", address_from_line_index(sim.branch_to_idx))

  print_register_title := true
  for reg in RegisterID
  {
    if sim.registers[reg] != sim.registers_prev[reg]
    {
      if print_register_title
      {
        term.color(.GRAY)
        fmt.print("Register: ")
        term.color(.WHITE)

        print_register_title = false
      }

      fmt.printf("%s=%i\n", register_names[reg], sim.registers[reg])
      sim.registers_prev[reg] = sim.registers[reg]
    }
  }
}

// @TODO(dg): THIS.
tui_print_register_view :: proc(which: TUI_RegisterViewSet)
{
  // Print temporaries
  if .TEMPORARIES in which
  {
    fmt.print("[temporaries]\n")

    for reg in RegisterID
    {
      if (reg >= .X5 && reg <= .X7) || (reg >= .X28 && reg <= .X31)
      {
        fmt.printf(" %s=%i\n", register_names[reg], sim.registers[reg])
      }
    }
  }

  // Print saved
  if .SAVED in which
  {
    fmt.print("[saved]\n")

    for reg in RegisterID
    {
      if reg == .X8 || reg == .X9 || (reg >= .X18 && reg <= .X27)
      {
        fmt.printf(" %s=%i\n", register_names[reg], sim.registers[reg])
      }
    }
  }

  // Print arguments
  if .ARGUMENTS in which
  {
    fmt.print("[arguments]\n")

    for reg in RegisterID
    {
      if reg >= .X10 && reg <= .X17
      {
        fmt.printf(" %s=%i\n", register_names[reg], sim.registers[reg])
      }
    }
  }

  // Print extras
  if .EXTRAS in which
  {
    fmt.print("[extras]\n")

    for reg in RegisterID
    {
      if reg >= .X1 && reg <= .X4
      {
        fmt.printf(" %s=%i\n", register_names[reg], sim.registers[reg])
      }
    }
  }
}

tui_print_commands_list :: proc()
{
  fmt.print(" q, quit       |   quit simulator\n")
  fmt.print(" s, step       |   step to next instruction\n")
  fmt.print(" r, run        |   continue to next breakpoint\n")
  fmt.print(" b, break      |   breakpoints\n")
  fmt.print("  'X'          |   peak breakpoint at 'X'\n")
  fmt.print("  set 'X'      |   set breakpoint at 'X'\n")
  fmt.print("  rem 'X'      |   remove breakpoint at 'X'\n")
  fmt.print("  clear        |   clear breakpoints\n")
  fmt.print("  list         |   list breakpoints\n")
  fmt.print(" v, view       |   view simulator contents\n")
  fmt.print("  r, reg 'G'   |   view registers of group 'G'\n")
  fmt.print("  m, mem       |   view memory (NOT IMPLEMENTED)\n")
}

// @Error /////////////////////////////////////////////////////////////////////////////

TUI_Error :: union
{
  TUI_InputError,
}

TUI_InputError :: struct
{
  type: TUI_InputErrorType,
}

TUI_InputErrorType :: enum
{
  EXPECTED_NUMERIC
}

tui_resolve_error :: proc(error: TUI_Error) -> bool
{
  if error == nil do return false

  term.color(.RED)
  fmt.print("[COMMAND ERROR]: ")
  
  switch v in error
  {
    case TUI_InputError:
    {
      fmt.printf("Invalid command.")
    }
  }

  term.color(.WHITE)

  return true
}

import "core:fmt"
import "core:os"

import "term"
