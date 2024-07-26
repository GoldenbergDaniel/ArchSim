package main

MAX_SRC_BUF_BYTES :: 1024
MAX_INSTRUCTIONS  :: 16
REGISTER_COUNT    :: 3

Simulator :: struct
{
  current_command: Command,
  step_through: bool,

  registers: [REGISTER_COUNT]Number,
  cmp_flag: struct
  {
    equals: bool,
    greater: bool,
  },
}

OpcodeType :: enum
{
  NIL,

  MOV,

  ADD,
  SUB,
  SHL,
  SHR,

  CMP,
  JMP,
  JEQ,
  JNE,
  JLT,
  JGT,
}

OPCODE_STRINGS :: [OpcodeType]string{
  .NIL = "",
  
  .MOV = "mov",

  .ADD = "add",
  .SUB = "sub",
  .SHL = "shl",
  .SHR = "shr",

  .CMP = "cmp",
  .JMP = "jmp",
  .JEQ = "jeq",
  .JNE = "jne",
  .JLT = "jlt",
  .JGT = "jgt",
}

Number :: distinct u8
Register :: distinct u8

Operand :: union
{
  Number,
  Register,
}

NIL_REGISTER :: 255

@(private="file")
command_table: map[string]CommandType

main :: proc()
{
  fmt.print("======= ARCH SIM =======\n")
  fmt.print("Type [r] to run entire program or [s] to step to next instruction.\n")
  fmt.print("Type [h] for a list of commands.\n\n")

  src_file, err := os.open("data/main.asm")
  if err != 0
  {
    fmt.eprint("Error opening file.\n")
    return
  }

  buf: [MAX_SRC_BUF_BYTES]byte
  size, _ := os.read(src_file, buf[:])
  src_data := buf[:size]

  // Build command table ----------------
  {
    command_table["q"]    = .QUIT
    command_table["quit"] = .QUIT
    command_table["h"]    = .HELP
    command_table["help"] = .HELP
    command_table["r"]    = .RUN
    command_table["run"]  = .RUN
    command_table[""]     = .STEP
    command_table["s"]    = .STEP
    command_table["step"] = .STEP
  }

  simulator: Simulator

  instructions: InstructionStore
  instructions.data = make([][]Token, MAX_INSTRUCTIONS * 10)

  // Prompt execution option ----------------
  for true
  {
    buf: [8]byte
    fmt.print("> ")
    input_len, _ := os.read(os.stdin, buf[:])
    cmd_str := str_strip_crlf(string(buf[:input_len]))
    command := command_from_string(cmd_str)

    #partial switch command.type
    {
      case .QUIT: return
      case .HELP: print_commands_list(); continue
      case .RUN:  simulator.step_through = false
      case .STEP: simulator.step_through = true
      case:
      {
        set_color(.RED)
        fmt.print("\nPlease enter a valid command.\n\n")
        set_color(.WHITE)
        continue
      }
    }
    
    fmt.print("\n")
    break
  }

  // Tokenize lines ----------------
  line_start: int
  for line_num := 0; true;
  {
    line_end, is_done := next_line(src_data, line_start)
    line := tokenize_line(src_data[line_start:line_end])
    line_start = line_end + 1
    if len(line) == 0 do continue
    
    instructions.data[line_num] = line

    for &instruction, i in instructions.data[line_num]
    {
      instruction.line = line_num
      instruction.column = i
    }

    if is_done
    {
      instructions.line_count = line_num + 1
      break
    }
    
    line_num += 1
  }

  // Execute instruction ----------------
  for instruction_idx := 0; instruction_idx < instructions.line_count; instruction_idx += 1
  {
    instruction := instructions.data[instruction_idx]

    operands: [3]Token
    operand_idx: int
    for token in instruction
    {
      if token.type == .IDENTIFIER || token.type == .NUMBER
      {
        operands[operand_idx] = token
        operand_idx += 1
      }
    }

    error: bool
    switch instruction[0].opcode_type
    {
      case .MOV:
      {
        dest_reg, err0 := operand_from_operands(operands[:], 0)
        op1_reg, err1  := operand_from_operands(operands[:], 1)
        
        error = err0 || err1
        if !error
        {
          val: Number

          switch v in op1_reg
          {
            case Number:   val = v
            case Register: val = simulator.registers[v]
          }

          simulator.registers[dest_reg.(Register)] = val
        }
      }
      case .ADD: fallthrough
      case .SUB: fallthrough
      case .SHL: fallthrough
      case .SHR:
      {
        dest_reg, err0 := operand_from_operands(operands[:], 0)
        op1_reg,  err1 := operand_from_operands(operands[:], 1)
        op2_reg,  err2 := operand_from_operands(operands[:], 2)

        error = err0 || err1 || err2
        if !error
        {
          val1, val2: Number

          switch t in op1_reg
          {
            case Number:   val1 = op1_reg.(Number)
            case Register: val1 = simulator.registers[op1_reg.(Register)]
          }

          switch t in op2_reg
          {
            case Number:   val2 = op2_reg.(Number)
            case Register: val2 = simulator.registers[op2_reg.(Register)]
          }
          
          result: Number
          #partial switch instruction[0].opcode_type
          {
            case .ADD: result = val1 + val2
            case .SUB: result = val1 - val2
            case .SHL: result = val1 << val2
            case .SHR: result = val1 >> val2
          }

          simulator.registers[dest_reg.(Register)] = result
        }
      }
      case .CMP:
      {
        op1_reg, err0 := operand_from_operands(operands[:], 0)
        op2_reg, err1 := operand_from_operands(operands[:], 1)

        error = err0 || err1
        if !error
        {
          val1, val2: Number

          switch v in op1_reg
          {
            case Number:   val1 = v
            case Register: val1 = simulator.registers[v]
          }

          switch v in op2_reg
          {
            case Number:   val2 = v
            case Register: val2 = simulator.registers[v]
          }

          simulator.cmp_flag.equals = val1 == val2
          simulator.cmp_flag.greater = val1 > val2
        }
      }
      case .JMP: fallthrough
      case .JEQ: fallthrough
      case .JNE: fallthrough
      case .JLT: fallthrough
      case .JGT:
      {
        dest, err0 := operand_from_operands(operands[:], 0)

        should_jump := false
        #partial switch instruction[0].opcode_type
        {
          case .JMP: should_jump = true
          case .JEQ: should_jump = simulator.cmp_flag.equals
          case .JNE: should_jump = !simulator.cmp_flag.equals
          case .JLT: should_jump = !simulator.cmp_flag.greater
          case .JGT: should_jump = simulator.cmp_flag.greater
        }

        error = err0
        if !error && should_jump
        {
          instruction_idx = cast(int) dest.(Number) - 1
        }
      }
      case .NIL: {}
    }

    if error
    {
      set_color(.RED)
      fmt.eprintf("Error executing instruction on line %i.\n", instruction[0].line+1)
      set_color(.WHITE)
      assert(false)
    }

    set_color(.GRAY )
    fmt.print("Address: ")
    set_color(.GREEN)
    fmt.printf("%#X\n", instruction_idx)
    set_color(.WHITE)

    set_color(.GRAY)
    fmt.print("Instruction: ")
    set_color(.WHITE)
    for tok in instruction do fmt.print(string(tok.data), "")

    set_color(.GRAY)
    fmt.print("\nRegisters:\n")
    set_color(.WHITE)
    for reg in 0..<REGISTER_COUNT
    {
      fmt.printf(" r%i=%i\n", reg, simulator.registers[reg])
    }

    if simulator.step_through && instruction_idx < instructions.line_count - 1
    {
      // Prompt execution option ----------------
      for true
      {
        buf: [8]byte
        fmt.print("\n> ")
        input_len, _ := os.read(os.stdin, buf[:])
        cmd_str := str_strip_crlf(string(buf[:input_len]))
        command := command_from_string(cmd_str)

        #partial switch command.type
        {
          case .QUIT: return
          case .HELP: print_commands_list(); continue
          case .RUN:  simulator.step_through = false
          case .STEP: simulator.step_through = true
          case:
          {
            set_color(.RED)
            fmt.print("\nPlease enter a valid command.\n\n")
            set_color(.WHITE)
            continue
          }
        }
        
        fmt.print("\n")
        break
      }
    }
    else
    {
      fmt.print("\n")
    }
  }
}

next_line :: proc(buf: []byte, start: int) -> (end: int, is_done: bool)
{
  length := len(buf)

  for i in start..<length
  {
    if buf[i] == '\n' || buf[i] == '\r'
    {
      end = i
      break
    }
  }

  is_done = end == length-1

  return end, is_done
}

Command :: struct
{
  type: CommandType,
  run_to: int,
}

CommandType :: enum
{
  NONE,

  QUIT,
  HELP,
  RUN,
  RUN_TO,
  STEP,
}

command_from_string :: proc(str: string) -> Command
{
  result: Command
  result.type = command_table[str]
  
  return result
}

// @Token ////////////////////////////////////////////////////////////////////////////////

Token :: struct
{
  data: []byte,
  type: TokenType,
  opcode_type: OpcodeType,

  line: int,
  column: int,
}

TokenType :: enum
{
  NIL,

  OPCODE,
  NUMBER,
  IDENTIFIER,
}

Instruction :: []Token

InstructionStore :: struct
{
  data: []Instruction,
  line_count: int,
}

tokenize_line :: proc(buf: []byte) -> Instruction
{
  tokens := make(Instruction, 10, context.allocator)
  token_idx: int

  end_of_line := len(buf)

  // Ignore comment
  {
    for i in 0..<end_of_line-1
    {
      if buf[i] == '/' && buf[i+1] == '/'
      {
        end_of_line = i
        break
      }
    }
  }

  tokenizer_loop: for line_idx := 0; line_idx < end_of_line; line_idx += 1
  {
    // Ignore spaces
    if buf[line_idx] == ' ' do continue

    i: int
    for i = line_idx; i < end_of_line && buf[i] != ',' && buf[i] != ' '; i += 1 {}
    buf_str := string(buf[line_idx:i])

    // Tokenize opcode
    for op_str, op_type in OPCODE_STRINGS
    {
      if str_equals(buf_str, op_str)
      {
        tokens[token_idx] = Token{data=buf[line_idx:i], type=.OPCODE}
        tokens[token_idx].opcode_type = op_type
        token_idx += 1
        line_idx = i
        continue tokenizer_loop
      }
    }

    // Tokenize number
    if str_is_number(buf_str)
    {
      tokens[token_idx] = Token{data=buf[line_idx:i], type=.NUMBER}
      token_idx += 1
      line_idx = i
      continue tokenizer_loop
    }

    // Tokenize identifier
    {
      tokens[token_idx] = Token{data=buf[line_idx:i], type=.IDENTIFIER}
      token_idx += 1
      line_idx = i
      continue tokenizer_loop
    }
  }

  return tokens[:token_idx]
}

register_from_token :: proc(token: Token) -> Register
{
  result: Register

  switch str_from_token(token)
  {
    case "r0": result = 0
    case "r1": result = 1
    case "r2": result = 2
    case: result = NIL_REGISTER
  }

  return result
}

operand_from_operands :: proc(operands: []Token, idx: int) -> (opr: Operand, err: bool)
{
  token := operands[idx]

  if token.type == .NUMBER
  {
    opr = cast(Number) str_to_int(str_from_token(token))
  }
  else if token.type == .IDENTIFIER
  {
    reg := register_from_token(token)
    if reg != NIL_REGISTER do opr = reg
    else do err = true
  }
  else
  {
    err = true
  }

  return opr, err
}

// @Terminal /////////////////////////////////////////////////////////////////////////////

ColorKind :: enum
{
  BLACK,
  BLUE,
  GRAY,
  GREEN,
  RED,
  WHITE,
  YELLOW,
}

set_color :: proc(kind: ColorKind)
{
  switch kind
  {
    case .BLACK:  fmt.print("\u001b[38;5;16m")
    case .BLUE:   fmt.print("\u001b[38;5;4m")
    case .GRAY:   fmt.print("\u001b[38;5;7m")
    case .GREEN:  fmt.print("\u001b[38;5;2m")
    case .RED:    fmt.print("\u001b[38;5;1m")
    case .WHITE:  fmt.print("\u001b[38;5;15m")
    case .YELLOW: fmt.print("\u001b[38;5;3m")
  }
}

print_commands_list :: proc()
{
  fmt.print("\n")
  fmt.print("q, quit   :   quit simulator\n")
  fmt.print("h, help   :   print list of commands\n")
  fmt.print("r, run    :   run program to breakpoint\n")
  fmt.print("s, step   :   step to next line\n")
  fmt.print("\n")
}

// @String ///////////////////////////////////////////////////////////////////////////////

str_equals :: proc(str1: string, str2: string) -> bool
{
  if len(str1) != len(str2) do return false

  for i in 0..<len(str1)
  {
    if str1[i] != str2[i] do return false
  }

  return true
}

str_to_lower :: proc(str: string, allocator := context.temp_allocator) -> string
{
  result := make([]byte, len(str), allocator)
  
  for i in 0..<len(str)
  {
    if str[i] >= 65 && str[i] <= 90
    {
      result[i] = str[i] + 32
    }
    else
    {
      result[i] = str[i]
    }
  }

  return cast(string) result
}

str_is_number :: proc(str: string) -> bool
{
  if len(str) > 1 && str[0] == '0' do return false

  for i in 0..<len(str)
  {
    if str[i] < '0' || str[i] > '9' do return false
  }

  return true
}

str_to_int :: proc(str: string) -> int
{
  assert(str_is_number(str))

  result: int

  for i := len(str)-1; i >= 0; i -= 1
  {
    result += int(str[len(str)-1-i] - 48) * int(pow_uint(10, uint(i)))
  }

  return result
}

str_strip_crlf :: proc(str: string) -> string
{
  result := str
  str_len := len(str)

  if str_len >= 2 && str[str_len-2] == '\r'
  {
    result = str[:len(str)-2]
  }
  else if str_len >= 1 && str[str_len-1] == '\n'
  {
    result = str[:len(str)-1]
  }

  return result
}

str_from_token :: #force_inline proc(token: Token) -> string
{
  return cast(string) token.data
}

// @Math /////////////////////////////////////////////////////////////////////////////////

pow_uint :: proc(base, exp: uint) -> uint
{
  result: uint = 1
  
  for i: uint; i < exp; i += 1
  {
    result *= base
  }

  return result
}

// @Imports //////////////////////////////////////////////////////////////////////////////

import "core:fmt"
import "core:os"
