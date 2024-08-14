package main

MAX_SRC_BUF_BYTES   :: 1024
MAX_LINES           :: 32
MAX_TOKENS_PER_LINE :: 8

REGISTER_COUNT :: 3

Simulator :: struct
{
  should_quit: bool,
  current_command: Command,
  step_to_next: bool,

  instructions: InstructionStore,
  symbol_table: SymbolTable,
  data_section_pos: int,
  text_section_pos: int,
  branch_to_idx: int,

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
  BLE,
  BGE,
}

OPCODE_STRINGS :: [OpcodeType]string{
  .NIL = "",
  
  .MOV = "mov",

  .ADD = "add",
  .SUB = "sub",
  .SHL = "shl",
  .SHR = "shr",

  .CMP = "cmp",

  .B   = "b",
  .BEQ = "beq",
  .BNE = "bne",
  .BLT = "blt",
  .BGT = "bgt",
  .BLE = "ble",
  .BGE = "bge",
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
  "q"          = .QUIT,
  "quit"       = .QUIT,
  "h"          = .HELP,
  "help"       = .HELP,
  "r"          = .RUN,
  "run"        = .RUN,
  ""           = .STEP,
  "s"          = .STEP,
  "step"       = .STEP,
  "bp"         = .SET_BREAK,
  "breakpoint" = .SET_BREAK,
}

USE_GUI :: false

main :: proc()
{
  when USE_GUI
  {
    sapp.run(sapp.Desc{
      window_title = "ArchSim",
      width = 900,
      height = 600,
      fullscreen = false,
      init_cb = gfx_init,
      event_cb = gfx_input,
      frame_cb = gfx_frame,
    })

    // if true do return
  }

  cli_print_welcome()
  
  perm_arena := util.create_arena(util.MIB * 8)
  context.allocator = perm_arena.ally
  temp_arena := util.create_arena(util.MIB * 8)
  context.temp_allocator = temp_arena.ally

  src_file_path := "res/main.asm"
  // if len(os.args) > 1
  // {
  //   src_file_path = os.args[1]
  // }

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

  // Tokenize ----------------
  {
    line_start, line_end: int
    for line_idx := 0; line_end < len(src_data); line_idx += 1
    {
      line_end = next_line_from_bytes(src_data, line_start)

      if line_start == line_end
      {
        line_start += 1
        if line_end == len(src_data) - 1 do break
        else do continue
      }
      
      sim.instructions.data[sim.instructions.count] = make(Instruction, MAX_TOKENS_PER_LINE)
      {
        line_bytes := src_data[line_start:line_end]

        line_tokens := sim.instructions.data[sim.instructions.count]
        token_cnt: int

        Tokenizer :: struct { pos, end: int }
        tokenizer: Tokenizer
        tokenizer.end = len(line_bytes)

        // Ignore commented section
        for i in 0..<tokenizer.end-1
        {
          if line_bytes[i] == '/' && line_bytes[i+1] == '/'
          {
            tokenizer.end = i
            break
          }
        }

        get_next_token_string :: proc(tokenizer: ^Tokenizer, buf: []byte) -> string
        {
          start, end, offset: int
          whitespace: bool
        
          i: int
          for i = tokenizer.pos; i < tokenizer.end; i += 1
          {
            b := buf[i]

            if i == tokenizer.pos && b == ' '
            {
              whitespace = true
            }

            if whitespace
            {
              if b == ' '
              {
                start += 1
              }
              else
              {
                whitespace = false
              }
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

      sim.instructions.count += 1
      line_start = line_end + 1
      
      for &instruction, i in sim.instructions.data[sim.instructions.count]
      {
        instruction.line = line_idx + 1
        instruction.column = i
      }
    }
  }

  // print_tokens()
  // if true do return

  // Preprocess ----------------
  {
    for instruction_idx := 0; 
        instruction_idx < sim.instructions.count; 
        instruction_idx += 1
    {
      instruction := sim.instructions.data[instruction_idx]
      {
        // Directives
        if instruction[0].type == .DIRECTIVE
        {
          if len(instruction) < 3 do continue

          switch instruction[0].data
          {
            case "$define":
            {
              sim.symbol_table[instruction[1].data] = Number(str_to_int(instruction[2].data))
            }
            case "$section":
            {
              section := instruction[1].data
              switch section
              {
                case ".data": sim.data_section_pos = instruction_idx + 1
                case ".text": sim.text_section_pos = instruction_idx + 1
                case: {}
              }
            }
          }
        }

        // Labels
        if instruction[0].type == .IDENTIFIER && instruction[1].type == .COLON
        {
          sim.symbol_table[instruction[0].data] = Number(instruction_idx - sim.text_section_pos)
        }
      }    
    }
  }

  // Error check ----------------
  {
    // Syntax
    for instruction_idx := 0; 
        instruction_idx < sim.instructions.count; 
        instruction_idx += 1
    {
      error: Error
      instruction := sim.instructions.data[instruction_idx]

      if  instruction[0].line >= sim.text_section_pos && 
          instruction[0].type == .IDENTIFIER && 
          instruction[0].opcode_type == .NIL &&
          instruction[1].type == .OPCODE
      {
        error = SyntaxError{
          type = .MISSING_COLON,
          line = instruction[0].line
        }

        break
      }

      if resolve_error(error) do return
    }

    // Semantics
    for instruction_idx := 0; 
        instruction_idx < sim.instructions.count; 
        instruction_idx += 1
    {
      error: Error
      instruction := sim.instructions.data[instruction_idx]

      if instruction_idx >= sim.text_section_pos
      {
        if instruction[0].opcode_type == .NIL && instruction[2].opcode_type == .NIL
        {
          error = TypeError{
            line = instruction[0].line,
            column = instruction[0].column,
            token = instruction[0],
            expected_type = .OPCODE,
            actual_type = instruction[0].type
          }
        }
      }

      if resolve_error(error) do return
    }
  }

  if true do return

  // Prompt user command ----------------
  for done: bool; !done;
  {
    done = cli_prompt_command()
  }

  if sim.should_quit do return

  // Execute/Simulate ----------------
  for instruction_idx := sim.text_section_pos; 
      instruction_idx < sim.instructions.count;
  {
    instruction := sim.instructions.data[instruction_idx]
    sim.branch_to_idx = instruction_idx + 1

    // Determine opcode and operand indices ----------------
    opcode: Token
    operands: [3]Token
    {
      if instruction[0].type == .OPCODE
      {
        opcode = instruction[0]
        operands[0] = instruction[1]
        operands[1] = instruction[2]
        operands[2] = instruction[3]
      }
      else if instruction[2].type == .OPCODE
      {
        opcode = instruction[2]
        operands[0] = instruction[3]
        operands[1] = instruction[4]
        operands[2] = instruction[5]
      }
    }

    error: bool

    switch opcode.opcode_type
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
      case .BGT: fallthrough
      case .BLE: fallthrough
      case .BGE:
      {
        dest, err0 := operand_from_operands(operands[:], 0)
        error = err0

        should_jump: bool
        #partial switch opcode.opcode_type
        {
          case .B:   should_jump = true
          case .BEQ: should_jump = sim.cmp_flag.equals
          case .BNE: should_jump = !sim.cmp_flag.equals
          case .BLT: should_jump = !sim.cmp_flag.greater
          case .BGT: should_jump = sim.cmp_flag.greater
          case .BLE: should_jump = sim.cmp_flag.greater || sim.cmp_flag.equals
          case .BGE: should_jump = sim.cmp_flag.greater || sim.cmp_flag.equals
        }

        if !error && should_jump
        {
          sim.branch_to_idx = cast(int) dest.(Number) + sim.text_section_pos
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

    cli_print_sim_result(instruction, instruction_idx)

    // Set next instruction to result of branch
    instruction_idx = sim.branch_to_idx

    if sim.step_to_next && instruction_idx < sim.instructions.count - 1
    {
      // Prompt user command ----------------
      for done: bool; !done;
      {
        done = cli_prompt_command()
      }
    }
    else
    {
      fmt.print("\n")
    }

    if sim.should_quit do return
  }
}

next_line_from_bytes :: proc(buf: []byte, start: int) -> (end: int)
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
  SET_BREAK,
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
  count: int,
}

SymbolTable :: map[string]Number

register_from_token :: proc(token: Token) -> (result: Register, err: bool)
{
  switch token.data
  {
    case "r0": result = 0
    case "r1": result = 1
    case "r2": result = 2
    case: 
    {
      result = NIL_REGISTER
      err = true
    }
  }

  return result, err
}

operand_from_operands :: proc(operands: []Token, idx: int) -> (result: Operand, err: bool)
{
  token := operands[idx]

  if token.type == .NUMBER
  {
    result = cast(Number) str_to_int(token.data)
  }
  else if token.type == .IDENTIFIER
  {
    result, err = register_from_token(token)
    if err
    {
      ok: bool
      result, ok = sim.symbol_table[token.data]
      err = !ok
    }
  }
  else
  {
    err = true
  }

  return result, err
}

// @Imports //////////////////////////////////////////////////////////////////////////////


import "core:fmt"
import "core:os"

import "util"
import "term"

import sapp "ext:sokol/app"
