package main

cli_print_welcome :: proc()
{
  fmt.print("======= ARCH SIM =======\n")
  fmt.print("Type [r] to run program or [s] to step next instruction.\n")
  fmt.print("Type [h] for a list of commands.\n")
}

cli_print_sim_result :: proc(instruction: Instruction, idx: int)
{
  term.color(.GRAY)
  fmt.print("Address: ")
  term.color(.WHITE)
  fmt.printf("%#X\n", idx - sim.text_section_pos)

  term.color(.GRAY)
  fmt.print("Next address: ")
  term.color(.WHITE)
  fmt.printf("%#X\n", sim.branch_to_idx - sim.text_section_pos)

  term.color(.GRAY)
  fmt.print("Instruction: ")
  term.color(.WHITE)
  for tok in instruction do fmt.print(tok.data, "")
  fmt.print("\n")

  term.color(.GRAY)
  fmt.print("Registers:\n")
  term.color(.WHITE)
  for reg in 0..<REGISTER_COUNT
  {
    fmt.printf(" r%i=%i\n", reg, sim.registers[reg])
  }
}

cli_prompt_command :: proc() -> bool
{
  done: bool

  buf: [8]byte
  fmt.print("\n> ")
  input_len, _ := os.read(os.stdin, buf[:])
  
  cmd_str := str_strip_crlf(string(buf[:input_len]))
  command := command_from_string(cmd_str)
  
  if cmd_str != "" && command.type != .QUIT
  {
    fmt.print("\n")
  }

  #partial switch command.type
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
    case .RUN:
    {
      sim.step_to_next = false
      done = true
    }
    case .STEP:
    {
      sim.step_to_next = true
      done = true
    }
    case:
    {
      term.color(.RED)
      fmt.print("\nPlease enter a valid command.\n\n")
      term.color(.WHITE)
      done = false
    }
  }
  
  fmt.print("\n")

  return done
}

cli_print_tokens :: proc()
{
  for i in 0..<sim.instructions.count
  {
    for tok in sim.instructions.data[i]
    {
      if tok.type == .NIL do continue
      fmt.print("{", tok.data, "|", tok.type , "} ")
    }

    fmt.print("\n")
  }

  fmt.println("\n")
}

cli_print_commands_list :: proc()
{
  fmt.print("q, quit   |   quit sim\n")
  fmt.print("h, help   |   print list of commands\n")
  fmt.print("r, run    |   run program to breakpoint\n")
  fmt.print("s, step   |   step to next line\n")
}

import "core:fmt"
import "core:os"

import "term"
