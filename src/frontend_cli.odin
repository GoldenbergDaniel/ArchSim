package main

CLI_Command :: struct
{
  type: CLI_CommandType,
  args: [3]string,
}

CLI_CommandType :: enum
{
  NONE,

  QUIT,
  HELP,
  CONTINUE,
  STEP,
  BREAKPOINT,
}

@(private="file")
command_table: map[string]CLI_CommandType = {
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
}

cli_prompt_command :: proc() -> bool
{
  done: bool

  buf: [64]byte
  term.color(.GRAY)
  fmt.print("\n|> ")
  term.color(.WHITE)
  input_len, _ := os.read(os.stdin, buf[:])
  
  cmd_str := str_strip_crlf(string(buf[:input_len]))
  command, err := cli_command_from_string(cmd_str)

  if resolve_command_error(err)
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
      cli_print_commands_list()
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
        line_idx = str_to_int(command.args[0])
        
        if sim.instructions[line_idx].has_breakpoint
        {
          term.color(.GRAY)
          fmt.printf("Breakpoint at line %i.\n", line_idx)
          term.color(.WHITE)
        }
      }
      else
      {
        modifier = command.args[0]
        if command.args[1] != ""
        {
          line_idx = str_to_int(command.args[1])
        }

        switch modifier
        {
          case "set":
          {
            if sim.instructions[line_idx].has_breakpoint == false
            {
              sim.instructions[line_idx].has_breakpoint = true

              term.color(.GREEN)
              fmt.printf("Breakpoint set at line %i.\n", line_idx)
              term.color(.WHITE)
            }
          }
          case "rem":
          {
            if sim.instructions[line_idx].has_breakpoint == true
            {
              sim.instructions[line_idx].has_breakpoint = false

              term.color(.ORANGE)
              fmt.printf("Breakpoint removed at line %i.\n", line_idx)
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
cli_command_from_string :: proc(str: string) -> (CLI_Command, CLI_Error)
{
  result: CLI_Command
  error: CLI_Error
  length := len(str)

  if length == 0
  {
    return CLI_Command{type=.STEP}, nil
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

cli_print_welcome :: proc()
{
  term.color(.GRAY)
  fmt.print("======= ARCH SIM =======\n")
  fmt.print("Type [r] to run program or [s] to step next instruction.\n")
  fmt.print("Type [h] for a list of commands.\n")
  term.color(.WHITE)
}

cli_print_sim_result :: proc(instruction: Instruction, idx: int)
{
  term.color(.GRAY)
  fmt.print("Address: ")
  term.color(.WHITE)
  fmt.printf("%#X\n", address_from_line_number(idx))

  term.color(.GRAY)
  fmt.print("Next address: ")
  term.color(.WHITE)
  fmt.printf("%#X\n", address_from_line_number(sim.branch_to_idx))

  term.color(.GRAY)
  fmt.print("Instruction: ")
  term.color(.WHITE)
  for tok in instruction.tokens do fmt.print(tok.data, "")
  fmt.print("\n")

  term.color(.GRAY)
  fmt.print("Registers:\n")
  term.color(.WHITE)
  for reg in RegisterID
  {
    if reg == .NIL || reg == .LR do continue

    fmt.printf(" %s=%i\n", reg, sim.registers[reg])
  }
}

cli_print_commands_list :: proc()
{
  fmt.print(" q, quit    |   quit simulator\n")
  fmt.print("            |\n")
  fmt.print(" b, break   |   breakpoints\n")
  fmt.print("  'X'       |   peak breakpoint at 'X'\n")
  fmt.print("  set 'X'   |   set breakpoint at 'X'\n")
  fmt.print("  rem 'X'   |   remove breakpoint at 'X'\n")
  fmt.print("  clear     |   clear breakpoints\n")
  fmt.print("  list      |   list breakpoints\n")
  fmt.print("            |\n")
  fmt.print(" s, step    |   step to next instruction\n")
  fmt.print("            |\n")
  fmt.print(" r, run     |   continue to next breakpoint\n")
}

// @Error ///////////////////////////////////////////////////////////////////////////////

CLI_Error :: union
{
  CLI_InputError
}

CLI_InputError :: struct
{
  type: CLI_InputErrorType,
}

CLI_InputErrorType :: enum
{
  EXPECTED_NUMERIC
}

resolve_command_error :: proc(error: CLI_Error) -> bool
{
  if error == nil do return false

  term.color(.RED)
  fmt.print("[COMMAND ERROR]: ")
  
  switch v in error
  {
    case CLI_InputError:
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
