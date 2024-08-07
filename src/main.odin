package main

MAX_SRC_BUF_BYTES   :: 1024
MAX_LINES           :: 32
MAX_TOKENS_PER_LINE :: 10
REGISTER_COUNT      :: 3

Simulator :: struct
{
  instructions: InstructionStore,
  symbol_table: SymbolTable,
  text_section_pos: int,

  current_command: Command,
  step_to_next: bool,

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
  B,
  BEQ,
  BNE,
  BLT,
  BGT,
}

OPCODE_STRINGS :: [OpcodeType]string{
  .NIL = "",
  
  .MOV = "mov",

  .ADD = "add",
  .SUB = "sub",
  .SHL = "shl",
  .SHR = "shr",

  .CMP = "cmp",
  .B   = "j",
  .BEQ = "jeq",
  .BNE = "jne",
  .BLT = "jlt",
  .BGT = "jgt",
}

Number :: distinct u8
Register :: distinct u8

Operand :: union
{
  Number,
  Register,
}

NIL_REGISTER :: 255

sim: Simulator

@(private="file")
command_table: map[string]CommandType = {
  "q"    = .QUIT,
  "quit" = .QUIT,
  "h"    = .HELP,
  "help" = .HELP,
  "r"    = .RUN,
  "run"  = .RUN,
  ""     = .STEP,
  "s"    = .STEP,
  "step" = .STEP,
}

main :: proc()
{
  fmt.print("======= ARCH SIM =======\n")
  fmt.print("Type [r] to run program or [s] to step next instruction.\n")
  fmt.print("Type [h] for a list of commands.\n\n")

  perm_arena := rt.create_arena(rt.MIB * 8)
  context.allocator = perm_arena.ally
  temp_arena := rt.create_arena(rt.MIB * 8)
  context.temp_allocator = temp_arena.ally

  src_file_path := "res/main.asm"
  if len(os.args) > 1
  {
    src_file_path = os.args[1]
  }

  src_file, err := os.open(src_file_path)
  if err != 0
  {
    term.color(.RED)
    fmt.eprintf("Error opening file \"%s\"\n", src_file_path)
    return
  }

  src_buf: [MAX_SRC_BUF_BYTES]byte
  src_size, _ := os.read(src_file, src_buf[:])
  src_data := src_buf[:src_size]

  sim.instructions.data = make([][]Token, MAX_LINES)

  /*
    Order of Operation
    1. tokenization
    2. syntax check (?)
    3. preprocessing
    4. type check
    5. execution
  */

  // Tokenize source code ----------------
  line_start: int
  for line_idx := 0; true;
  {
    line_end := next_line(src_data, line_start)
    sim.instructions.line_count = line_idx
    if line_start == line_end
    {
      line_start += 1
      if line_end == len(src_data) - 1 do break
      else do continue
    }
    
    sim.instructions.data[line_idx] = make(Instruction, 10, context.allocator)
    {
      line_bytes := src_data[line_start:line_end]

      line_tokens := sim.instructions.data[line_idx]
      token_cnt: int

      Tokenizer :: struct { pos, end: int }
      tokenizer: Tokenizer
      tokenizer.end = len(line_bytes)

      // Ignore comment
      for i in 0..<tokenizer.end-1
      {
        if line_bytes[i] == '/' && line_bytes[i+1] == '/'
        {
          tokenizer.end = i
          break
        }
      }

      get_next_token_string :: #force_inline proc(tokenizer: ^Tokenizer, buf: []byte) -> string
      {
        start, end, offset: int
        whitespace: bool
      
        i: int
        for i = tokenizer.pos; i < tokenizer.end; i += 1
        {
          b := buf[i]

          if i == tokenizer.pos && b == ' ' do whitespace = true

          if whitespace
          {
            if b == ' ' do start += 1
            else        do whitespace = false
          }
          else if b == ':' || b == '=' || b == ',' || b == ' '
          {
            offset = int(i == tokenizer.pos)
            break
          }
        }

        start += tokenizer.pos
        end = i + offset
        tokenizer.pos = end

        return cast(string) buf[start:end]
      }

      tokenizer_loop: for tokenizer.pos < tokenizer.end
      {
        buf_str := get_next_token_string(&tokenizer, line_bytes)
        if buf_str == "" || buf_str == "," do continue tokenizer_loop

        // Tokenize opcode
        for op_str, op_type in OPCODE_STRINGS
        {
          buf_str_lower := str_to_lower(buf_str)
          if buf_str_lower == op_str
          {
            line_tokens[token_cnt] = Token{data=buf_str, type=.OPCODE}
            line_tokens[token_cnt].opcode_type = op_type
            token_cnt += 1
            continue tokenizer_loop
          }

          free_all(context.temp_allocator)
        }

        // Tokenize number
        if str_is_bin(buf_str) || str_is_dec(buf_str) || str_is_hex(buf_str)
        {
          line_tokens[token_cnt] = Token{data=buf_str, type=.NUMBER}
          token_cnt += 1
          continue tokenizer_loop
        }

        // Tokenize operator
        {
          @(static)
          operator_table := [?]TokenType{':' = .COLON, '=' = .EQUALS}
          
          if buf_str == ":" || buf_str == "="
          {
            line_tokens[token_cnt] = Token{data=buf_str, type=operator_table[buf_str[0]]}
            token_cnt += 1
            continue tokenizer_loop
          }
        }

        // Tokenize directive
        if buf_str[0] == '$'
        {
          line_tokens[token_cnt] = Token{data=buf_str, type=.DIRECTIVE}
          token_cnt += 1
          continue tokenizer_loop
        }

        // Tokenize identifier
        {
          line_tokens[token_cnt] = Token{data=buf_str, type=.IDENTIFIER}
          token_cnt += 1
          continue tokenizer_loop
        }
      }

      sim.instructions.data[line_idx] = line_tokens[:token_cnt]
    }

    line_start = line_end + 1
    
    for &instruction, i in sim.instructions.data[line_idx]
    {
      instruction.line = line_idx + 1
      instruction.column = i
    }
    
    line_idx += 1
  }

  fmt.println(sim.instructions.line_count)
  print_tokens()
  // if true do return

  // Preprocess program ----------------
  for instruction_idx := 0; instruction_idx < sim.instructions.line_count; instruction_idx += 1
  {
    instruction := sim.instructions.data[instruction_idx]
    for i in 0..<len(instruction)
    {
      // Directives
      if instruction[i].type == .DIRECTIVE 
      {
        switch instruction[i].data
        {
          case "$define":
          {
            sim.symbol_table[instruction[i+1].data] = cast(Number) str_to_int(instruction[i+2].data)
          }
          case "$section":
          {
            section := instruction[i+1].data
            switch section
            {
              case ".data": {}
              case ".text": sim.text_section_pos = instruction_idx + 1
              case: {}
            }
          }
        }
      }

      // Labels
    }    
  }

  // fmt.println(sim.symbol_table)

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
      case .RUN:  sim.step_to_next = false
      case .STEP: sim.step_to_next = true
      case:
      {
        term.color(.RED)
        fmt.print("\nEnter a valid command.\n\n")
        term.color(.WHITE)
        continue
      }
    }
    
    fmt.print("\n")
    break
  }

  // Error check instructions ----------------
  for instruction_idx := sim.text_section_pos; 
      instruction_idx < sim.instructions.line_count; 
      instruction_idx += 1
  {
    error := syntax_and_semantic_check_instruction(sim.instructions.data[instruction_idx])
    switch v in error
    {
      case bool: {}
      case SyntaxError: {}
      case TypeError: {}
      case OpcodeError: {}
    }
  }

  // Execute instructions ----------------
  for instruction_idx := sim.text_section_pos; 
      instruction_idx < sim.instructions.line_count;
      instruction_idx += 1
  {
    instruction := sim.instructions.data[instruction_idx]

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

    opcode_token := instruction[0]
    switch opcode_token.opcode_type
    {
      case .NIL: {}
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
            case Register: val = sim.registers[v]
          }

          sim.registers[dest_reg.(Register)] = val
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

          switch v in op1_reg
          {
            case Number:   val1 = v
            case Register: val1 = sim.registers[v]
          }

          switch v in op2_reg
          {
            case Number:   val2 = v
            case Register: val2 = sim.registers[v]
          }
          
          result: Number
          #partial switch instruction[0].opcode_type
          {
            case .ADD: result = val1 + val2
            case .SUB: result = val1 - val2
            case .SHL: result = val1 << val2
            case .SHR: result = val1 >> val2
          }

          sim.registers[dest_reg.(Register)] = result
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
            case Register: val1 = sim.registers[v]
          }

          switch v in op2_reg
          {
            case Number:   val2 = v
            case Register: val2 = sim.registers[v]
          }

          sim.cmp_flag.equals = val1 == val2
          sim.cmp_flag.greater = val1 > val2
        }
      }
      case .B:   fallthrough
      case .BEQ: fallthrough
      case .BNE: fallthrough
      case .BLT: fallthrough
      case .BGT:
      {
        dest, err0 := operand_from_operands(operands[:], 0)
        error = err0

        should_jump: bool
        #partial switch opcode_token.opcode_type
        {
          case .B:   should_jump = true
          case .BEQ: should_jump = sim.cmp_flag.equals
          case .BNE: should_jump = !sim.cmp_flag.equals
          case .BLT: should_jump = !sim.cmp_flag.greater
          case .BGT: should_jump = sim.cmp_flag.greater
        }

        if !error && should_jump
        {
          instruction_idx = cast(int) dest.(Number) - 1
        }
      }
    }

    if error
    {
      term.color(.RED)
      fmt.eprintf("[ERROR]: Failed to execute instruction on line %i.\n", instruction[0].line)
      term.color(.WHITE)
      return
    }

    term.color(.GRAY)
    fmt.print("Address: ")
    term.color(.WHITE)
    fmt.printf("%#X\n", instruction_idx)

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

    if sim.step_to_next && instruction_idx < sim.instructions.line_count - 1
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
          case .RUN:  sim.step_to_next = false
          case .STEP: sim.step_to_next = true
          case:
          {
            term.color(.RED)
            fmt.print("\nPlease enter a valid command.\n\n")
            term.color(.WHITE)
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

next_line :: proc(buf: []byte, start: int) -> (end: int)
{
  length := len(buf)

  end = start
  for i in start..<length
  {
    if (buf[i] == '\n' || buf[i] == '\r') 
    {
      end = i
      break
    }
  }

  return end
}

next_line_bytes :: proc(buf: []byte) -> []byte
{
  return nil
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
  data: string,
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
  DIRECTIVE,
  COLON,
  EQUALS,
}

Instruction :: []Token

InstructionStore :: struct
{
  data: []Instruction,
  line_count: int,
}

SymbolTable :: map[string]Number

tokenize_line_from_bytes :: proc(buf: []byte) -> Instruction
{
  tokens := make(Instruction, 10, context.allocator)
  token_cnt: int

  Tokenizer :: struct { pos, end: int }
  tokenizer: Tokenizer
  tokenizer.end = len(buf)

  // Ignore comment
  for i in 0..<tokenizer.end-1
  {
    if buf[i] == '/' && buf[i+1] == '/'
    {
      tokenizer.end = i
      break
    }
  }

  get_next_token_string :: #force_inline proc(tokenizer: ^Tokenizer, buf: []byte) -> string
  {
    start, end, offset: int
    whitespace: bool
   
    i: int
    for i = tokenizer.pos; i < tokenizer.end; i += 1
    {
      b := buf[i]

      if i == tokenizer.pos && b == ' ' do whitespace = true

      if whitespace
      {
        if b == ' ' do start += 1
        else        do whitespace = false
      }
      else if b == ':' || b == '=' || b == ',' || b == ' '
      {
        offset = int(i == tokenizer.pos)
        break
      }
    }

    start += tokenizer.pos
    end = i + offset
    tokenizer.pos = end

    return cast(string) buf[start:end]
  }

  tokenizer_loop: for tokenizer.pos < tokenizer.end
  {
    buf_str := get_next_token_string(&tokenizer, buf)
    if buf_str == "" || buf_str == "," do continue tokenizer_loop

    // Tokenize opcode
    for op_str, op_type in OPCODE_STRINGS
    {
      buf_str_lower := str_to_lower(buf_str)
      if buf_str_lower == op_str
      {
        tokens[token_cnt] = Token{data=buf_str, type=.OPCODE}
        tokens[token_cnt].opcode_type = op_type
        token_cnt += 1
        continue tokenizer_loop
      }

      free_all(context.temp_allocator)
    }

    // Tokenize number
    if str_is_bin(buf_str) || str_is_dec(buf_str) || str_is_hex(buf_str)
    {
      tokens[token_cnt] = Token{data=buf_str, type=.NUMBER}
      token_cnt += 1
      continue tokenizer_loop
    }

    // Tokenize operator
    {
      @(static)
      operator_table := [?]TokenType{':' = .COLON, '=' = .EQUALS}
      
      if buf_str == ":" || buf_str == "="
      {
        tokens[token_cnt] = Token{data=buf_str, type=operator_table[buf_str[0]]}
        token_cnt += 1
        continue tokenizer_loop
      }
    }

    // Tokenize directive
    if buf_str[0] == '$'
    {
      tokens[token_cnt] = Token{data=buf_str, type=.DIRECTIVE}
      token_cnt += 1
      continue tokenizer_loop
    }

    // Tokenize identifier
    {
      tokens[token_cnt] = Token{data=buf_str, type=.IDENTIFIER}
      token_cnt += 1
      continue tokenizer_loop
    }
  }

  return tokens[:token_cnt]
}

syntax_and_semantic_check_instruction :: proc(instruction: Instruction) -> Error
{
  /*
    For this part, we check whether the instruction contains an opcode in either 
    the first slot when there is no label, or the second spot when there is one.
  */
  for opcode in OPCODE_STRINGS
  {
    if instruction[0].data != opcode
    {
      error := TypeError{
        line = instruction[0].line,
        column = instruction[0].column,
        token = instruction[0],
        expected_type = .OPCODE,
        actual_type = instruction[0].type
      }

      return error
    }
  }

  return nil
}

register_from_token :: proc(token: Token) -> (Register, bool)
{
  result: Register
  error: bool

  switch token.data
  {
    case "r0": result = 0
    case "r1": result = 1
    case "r2": result = 2
    case: 
    {
      result = NIL_REGISTER
      error = true
    }
  }

  return result, error
}

operand_from_operands :: proc(operands: []Token, idx: int) -> (opr: Operand, err: bool)
{
  token := operands[idx]

  if token.type == .NUMBER
  {
    opr = cast(Number) str_to_int(token.data)
  }
  else if token.type == .IDENTIFIER
  {
    opr, err = register_from_token(token)
    if err
    {
      ok: bool
      opr, ok = sim.symbol_table[token.data]
      err = !ok
    }
  }
  else
  {
    err = true
  }

  return opr, err
}

// @Terminal /////////////////////////////////////////////////////////////////////////////

print_tokens :: proc()
{
  for i in 0..<sim.instructions.line_count
  {
    for tok in sim.instructions.data[i]
    {
      fmt.print("{", tok.data, "|", tok.type , "} ")
    }

    fmt.print("\n")
  }

  fmt.println("\n")
}

print_commands_list :: proc()
{
  fmt.print("\n")
  fmt.print("q, quit   :   quit sim\n")
  fmt.print("h, help   :   print list of commands\n")
  fmt.print("r, run    :   run program to breakpoint\n")
  fmt.print("s, step   :   step to next line\n")
  fmt.print("\n")
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

import rt "root"
import "term"
