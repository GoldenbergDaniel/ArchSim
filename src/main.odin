package main

MAX_INSTRUCTIONS :: 16
REGISTER_COUNT :: 3

Simulator :: struct
{
  should_quit: bool,
  step_through: bool,

  registers: [REGISTER_COUNT]Number,
}

InstructionStore :: struct
{
  data: [][]Token,
  num_lines: int,
}

OpcodeType :: enum
{
  NIL,

  MOV,
  ADD,
  SUB,
  JMP,
}

OPCODES :: [OpcodeType]string{
  .NIL = "",
  
  .MOV = "mov",
  .ADD = "add",
  .SUB = "sub",
  .JMP = "jmp",
}

Number :: distinct u8
Register :: distinct u8

Operand :: union
{
  Number,
  Register
}

NIL_REGISTER :: 255

main :: proc()
{
  perm_arena := rt.create_arena(rt.MIB * 16)
  context.allocator = perm_arena.ally
  temp_arena := rt.create_arena(rt.MIB * 16)
  context.temp_allocator = temp_arena.ally

  src_file, err := os.open("data/main.asm")
  if err != 0
  {
    fmt.eprint("Error opening file.\n")
  }

  buf: [512]byte
  size, _ := os.read(src_file, buf[:])
  src_data := buf[:size]

  simulator: Simulator

  instructions: InstructionStore
  instructions.data = make([][]Token, MAX_INSTRUCTIONS * 10)

  fmt.print("===== ARCH SIM =====\n")
  fmt.print("Enter [r] to run or [s] to step through\n")

  // Select run option
  opt_loop: for true
  {
    buf: [8]byte
    fmt.print("> ")
    os.read(os.stdin, buf[:])
    fmt.print("\n")

    opt := buf[0]
    switch opt
    {
      case 'r': simulator.step_through = false
      case 's': simulator.step_through = true
      case 'q': simulator.should_quit = true
      case: continue opt_loop
    }

    break opt_loop
  }

  if simulator.should_quit do return

  line_start: int
  for line_num := 0; true; line_num += 1
  {
    line_end, is_done := next_line(src_data, line_start)
    instructions.data[line_num] = tokenize_line(src_data[line_start:line_end], perm_arena)
    line_start = line_end + 1

    for &instruction, i in instructions.data[line_num]
    {
      instruction.line = line_num
      instruction.column = i
    }

    if is_done
    {
      instructions.num_lines = line_num + 1
      break
    }
  }

  for instruction_idx := 0; instruction_idx < instructions.num_lines; instruction_idx += 1
  {
    instruction := instructions.data[instruction_idx]
    
    // Execute instruction
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

    if len(instruction) > 0 && instruction[0].type == .OPCODE
    {
      error: bool
      #partial switch instruction[0].opcode_type
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
        case .ADD:
        {
          dest_reg, err0 := operand_from_operands(operands[:], 0)
          op1_reg, err1  := operand_from_operands(operands[:], 1)
          op2_reg, err2  := operand_from_operands(operands[:], 2)

          error = err0 || err1 || err2
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

            simulator.registers[dest_reg.(Register)] = val1 + val2
          }
        }
        case .SUB:
        {
          dest_reg, err0 := operand_from_operands(operands[:], 0)
          op1_reg, err1  := operand_from_operands(operands[:], 1)
          op2_reg, err2  := operand_from_operands(operands[:], 2)

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

            simulator.registers[dest_reg.(Register)] = val1 - val2
          }
        }
        case .JMP:
        {
          dest, err0 := operand_from_operands(operands[:], 0)

          error = err0
          if !error
          {
            instruction_idx = cast(int) dest.(Number) - 1
          }
        }
      }

      if error
      {
        fmt.eprintf("Error executing instruction on line %i.\n", instruction[0].line+1)
        assert(false)
      }

      fmt.printf("Address: %#X\n", instruction_idx)

      fmt.print("Instruction: ")
      for tok in instruction do fmt.printf("%s ", string(tok.data))

      fmt.print("\nRegisters:\n")
      for reg in 0..<REGISTER_COUNT
      {
        fmt.printf(" r%i=%i\n", reg, simulator.registers[reg])
      }

      if simulator.step_through
      {
        for
        {
          buf: [8]byte
          buf_len, _ := os.read(os.stdin, buf[:])
          if buf_len <= 2 do break
        }
      }
      else
      {
        fmt.print("\n")
      }
    }
  }
}

next_line :: proc(buf: []byte, start: int) -> (end: int, is_done: bool)
{
  length := len(buf)

  for i in start..<length
  {
    if buf[i] == '\n'
    {
      end = i
      break
    }
  }

  is_done = end == length-1

  return end, is_done
}

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

tokenize_line :: proc(buf: []byte, arena: ^rt.Arena) -> Instruction
{
  tokens := make(Instruction, 10, arena.ally)
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
    for op_str, op_type in OPCODES
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

  switch string_from_token(token)
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
    opr = cast(Number) str_to_int(string_from_token(token))
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

string_from_token :: #force_inline proc(token: Token) -> string
{
  return cast(string) token.data
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
  if str[0] == '0' do return false

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
    result += int(str[i] - 48) * int(math.pow(10, f32(i)))
  }

  return result
}

// Imports ///////////////////////////////////////////////////////////////////////////////

import "core:fmt"
import "core:math"
import "core:os"

import rt "root"
