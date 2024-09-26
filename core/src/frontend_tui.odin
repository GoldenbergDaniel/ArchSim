package main

import "core:fmt"
import "core:os"

import "term"

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

TUI_Base :: enum
{
  BIN,
  DEC,
  HEX,
}

TUI_Config :: struct
{
  base: TUI_Base,
}

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

@(private="file")
global_config: TUI_Config = { base=.HEX }

tui_prompt_command :: proc() -> bool
{
  done: bool

  buf: [64]byte
  term.color(.GRAY)
  fmt.print("\n(archsim) ")
  term.color(.WHITE)

  input_len, _ := os.read(os.stdin, buf[:])
  
  cmd_str := str_strip_crlf(string(buf[:input_len]))
  command := tui_command_from_string(cmd_str)

  if command.type != .QUIT
  {
    fmt.print("\n")
  }

  switch command.type
  {
  case .QUIT:
    sim.should_quit = true
    done = true
  case .HELP:
    tui_print_commands_list()
    done = false
  case .STEP:
    sim.step_to_next = true
    done = true
  case .CONTINUE:
    sim.step_to_next = false
    done = true
  case .BREAKPOINT:
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
        if sim.instructions[line_idx].has_breakpoint == false
        {
          sim.instructions[line_idx].has_breakpoint = true

          term.color(.GREEN)
          fmt.printf("Breakpoint set at line %i.\n", line_idx + 1)
          term.color(.WHITE)
        }
      case "rem":
        if sim.instructions[line_idx].has_breakpoint == true
        {
          sim.instructions[line_idx].has_breakpoint = false

          term.color(.ORANGE)
          fmt.printf("Breakpoint removed at line %i.\n", line_idx + 1)
          term.color(.WHITE)
        }
      case "clear":
        for i in 0..<MAX_LINES
        {
          sim.instructions[i].has_breakpoint = false
        }

        term.color(.ORANGE)
        fmt.print("Breakpoints cleared.\n")
        term.color(.WHITE)
      case "list":
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
    
    done = false
  case .VIEW:
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

      tui_print_register_view(set, global_config.base)
    }
    else if command.args[0] == "m" || command.args[0] == "mem"
    {
      address: Address
      if str_is_numeric(command.args[1])
      {
        address = cast(Address) str_to_int(command.args[1])
        if !address_is_valid(address)
        {
          tui_print_message(.ERROR, "Address out of range.")
        }
      }
      else 
      {
        reg, err := register_from_token(Token{data=command.args[1]})
        if !err
        {
          address = cast(Address) sim.registers[reg]
        }
        else
        {
          val, ok := sim.symbol_table[command.args[1]]
          if !ok
          {
            tui_print_message(.ERROR, "Unidentified token for address.")
            done = false
            return done
          }
          else
          {
            address = cast(Address) val
          }
        }
      }

      offset: int
      if str_is_numeric(command.args[2])
      {
        offset = str_to_int(command.args[2])
      }

      tui_print_memory_view(address + Address(offset), global_config.base)
    }
    else if command.args[0] == "base" || command.args[0] == "mode"
    {
      err: bool
      switch command.args[1]
      {
      case "2", "bin", "binary":       global_config.base = .BIN
      case "10", "dec", "decimal":     global_config.base = .DEC
      case "16", "hex", "hexadecimal": global_config.base = .HEX
      case: err = true
      }

      if err
      {
        tui_print_message(.ERROR, "Invalid base. Must be 2, 10, or 16.")
      }
    }
  case .NONE:
    tui_print_message(.ERROR, "Please enter a valid command.")
    done = false
  }
  
  return done
}

// NOTE(dg): Expects a string without leading whitespace
tui_command_from_string :: proc(str: string) -> TUI_Command
{
  result: TUI_Command
  length := len(str)

  if length == 0
  {
    return TUI_Command{type=.STEP}
  }

  start, end: int
  for i := 0; i <= len(result.args) && end < length; i += 1
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

  return result
}

tui_print_welcome :: proc()
{
  term.color(.GRAY)
  fmt.print("======= ARCH SIM =======\n")
  fmt.print("Type [r] to run program or [s] to step to next instruction.\n")
  fmt.print("Type [h] for a list of commands.\n")
  term.color(.WHITE)
}

tui_print_sim_result :: proc(instruction: Line)
{
  line_idx := instruction.line_idx
  next_line_idx := sim.instructions[sim.next_instruction_idx].line_idx

  term.color(.GRAY)
  fmt.print("Instruction:  ")
  term.color(.WHITE)
  for tok in instruction.tokens
  {
    if tok.data != ""
    {
      fmt.print(tok.data, "")
    }
  }
  fmt.printf(" (line %i)\n", line_idx+1)

  term.color(.GRAY)
  fmt.print("Address:      ")
  term.color(.WHITE)
  fmt.printf("%#X\n", address_from_line_index(line_idx))

  term.color(.GRAY)
  fmt.print("Next address: ")
  term.color(.WHITE)
  fmt.printf("%#X\n", address_from_line_index(next_line_idx))

  print_register_title := true
  for reg in RegisterID
  {
    if sim.registers[reg] != sim.registers_prev[reg]
    {
      if print_register_title
      {
        term.color(.GRAY)
        fmt.print("Register:     ")
        term.color(.WHITE)

        print_register_title = false
      }

      fmt.printf("%s=%i\n", reg, sim.registers[reg])
      sim.registers_prev[reg] = sim.registers[reg]
    }
  }

  term.color(.GRAY)
  fmt.print("PC:           ")
  term.color(.WHITE)
  fmt.println(sim.program_counter)
}

tui_print_register_view :: proc(which: TUI_RegisterViewSet, base: TUI_Base)
{
  base := base
  base = .DEC

  // Print temporaries ----------------
  if .TEMPORARIES in which
  {
    fmt.print("[temporaries]\n")

    for reg in RegisterID
    {
      if (reg >= .T0 && reg <= .T2) || (reg >= .T3 && reg <= .T6)
      {
        switch base
        {
        case .BIN:
          fmt.printf(" %s=%b\n", reg, sim.registers[reg])
        case .DEC:
          fmt.printf(" %s=%i\n", reg, sim.registers[reg])
        case .HEX:
          fmt.printf(" %s=%X\n", reg, sim.registers[reg])
        }
      }
    }
  }

  // Print saved ----------------
  if .SAVED in which
  {
    fmt.print("[saved]\n")

    for reg in RegisterID
    {
      if reg == .S1 || (reg >= .S2 && reg <= .S11)
      {
        switch base
        {
        case .BIN:
          fmt.printf(" %s=%b\n", reg, sim.registers[reg])
        case .DEC:
          fmt.printf(" %s=%i\n", reg, sim.registers[reg])
        case .HEX:
          fmt.printf(" %s=%X\n", reg, sim.registers[reg])
        }
      }
    }
  }

  // Print arguments ----------------
  if .ARGUMENTS in which
  {
    fmt.print("[arguments]\n")

    for reg in RegisterID
    {
      if reg >= .A0 && reg <= .A7
      {
        switch base
        {
        case .BIN:
          fmt.printf(" %s=%b\n", reg, sim.registers[reg])
        case .DEC:
          fmt.printf(" %s=%i\n", reg, sim.registers[reg])
        case .HEX:
          fmt.printf(" %s=%X\n", reg, sim.registers[reg])
        }
      }
    }
  }

  // Print extras ----------------
  if .EXTRAS in which
  {
    fmt.print("[extras]\n")

    for reg in RegisterID
    {
      if (reg >= .RA && reg <= .TP) || reg == .FP
      {
        switch base
        {
        case .BIN:
          fmt.printf(" %s=%b\n", reg, sim.registers[reg])
        case .DEC:
          fmt.printf(" %s=%i\n", reg, sim.registers[reg])
        case .HEX:
          fmt.printf(" %s=%X\n", reg, sim.registers[reg])
        }
      }
    }
  }
}

tui_print_memory_view :: proc(address: Address, base: TUI_Base)
{
  for addr in address-3..=address+3 do if address_is_valid(addr)
  {
    if addr == address
    {
      term.color(.GREEN)
      fmt.print(" > ")
    }
    else
    {
      fmt.print("   ")
    }

    switch base
    {
    case .BIN:
      fmt.printf("%X : %b\n", addr, sim.memory[addr - BASE_ADDRESS])
    case .DEC:
      fmt.printf("%X : %i\n", addr, sim.memory[addr - BASE_ADDRESS])
    case .HEX:
      fmt.printf("%X : %X\n", addr, sim.memory[addr - BASE_ADDRESS])
    }
    
    term.color(.WHITE)
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
  fmt.print("  m, mem 'A'   |   view memory around address 'A'\n")
}

TUI_MessageLevel :: enum
{
  INFO,
  WARNING,
  ERROR,
}

tui_print_message :: proc(level: TUI_MessageLevel, msg: string, args: ..any)
{
  switch level
  {
  case .INFO:    term.color(.GRAY)
  case .WARNING: term.color(.YELLOW)
  case .ERROR:   term.color(.RED)
  }

  if args != nil
  {
    fmt.printfln(msg, args)
  }
  else
  {
    fmt.println(msg)
  }
  
  term.color(.WHITE)
}
