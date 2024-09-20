package main

import "core:fmt"

import "term"

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

Instruction :: struct
{
  tokens: []Token,
  line_num: int,
  has_breakpoint: bool,
}

tokenize_code_from_bytes :: proc(src_data: []byte)
{
  line_start, line_end: int
  for line_idx := 0; line_end < len(src_data); line_idx += 1
  {
    defer free_all(context.temp_allocator)

    line_end = next_line_from_bytes(src_data, line_start)
    if line_start == line_end
    {
      line_start = line_end + 1
      end_of_file := line_end == len(src_data) - 1

      if end_of_file do break
      else do continue
    }

    // Skip lines containing only whitespace
    {
      is_whitespace := true
      line_bytes := src_data[line_start:line_end]

      for b in line_bytes
      {
        if b != ' ' && b != '\n' && b != '\r' && b != '\t'
        {
          is_whitespace = false
          break
        }
      }

      if is_whitespace
      {
        line_start = line_end + 1
        continue
      }
    }

    sim.instructions[line_idx].tokens = make([]Token, MAX_TOKENS_PER_LINE)
    
    // Tokenize line
    {
      line_bytes := src_data[line_start:line_end]
      line := sim.instructions[line_idx]
      token_cnt: int

      Tokenizer :: struct { pos, end: int }
      tokenizer: Tokenizer
      tokenizer.end = len(line_bytes)

      // Ignore commented portion
      for i in 0..<tokenizer.end
      {
        if line_bytes[i] == '#'
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
          else if b == ':' || b == '=' || b == ',' || b == ' ' || b == '[' || b == ']'
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
        tok_str := get_next_token_string(&tokenizer, line_bytes)
        if tok_str == "" || tok_str == "," || tok_str == "[" || tok_str == "]"
        {
          continue tokenizer_loop
        }

        // Tokenize opcode
        { 
          tok_str_lower := str_to_lower(tok_str)
          op_type := opcode_table[tok_str_lower]
          if op_type != .NIL
          {
            line.tokens[token_cnt] = Token{data=tok_str, type=.OPCODE}
            line.tokens[token_cnt].opcode_type = op_type
            token_cnt += 1
            continue tokenizer_loop
          }
        }

        // Tokenize number
        if str_is_bin(tok_str) || str_is_dec(tok_str) || str_is_hex(tok_str)
        {
          line.tokens[token_cnt] = Token{data=tok_str, type=.NUMBER}
          token_cnt += 1
          continue tokenizer_loop
        }

        // Tokenize operator
        {
          @(static)
          operators := [?]TokenType{':' = .COLON, '=' = .EQUALS}
          
          if tok_str == ":" || tok_str == "="
          {
            line.tokens[token_cnt] = Token{data=tok_str, type=operators[tok_str[0]]}
            token_cnt += 1
            continue tokenizer_loop
          }
        }

        // Tokenize directive
        if tok_str[0] == '.'
        {
          line.tokens[token_cnt] = Token{data=tok_str, type=.DIRECTIVE}
          token_cnt += 1
          continue tokenizer_loop
        }

        // Tokenize identifier
        {
          line.tokens[token_cnt] = Token{data=tok_str, type=.IDENTIFIER}
          token_cnt += 1
          continue tokenizer_loop
        }
      }
    }

    line_start = line_end + 1
    sim.line_count = line_idx + 1
    
    for &token, i in sim.instructions[sim.line_count].tokens
    {
      token.line = line_idx + 1
      token.column = i
    }
  }
}

error_check_instructions :: proc()
{
  // Syntax
  for line_num := 0; line_num < sim.line_count; line_num += 1
  {
    if sim.instructions[line_num].tokens == nil do continue

    error: ParserError
    instruction := sim.instructions[line_num]

    if instruction.tokens[0].line >= sim.text_section_pos && 
        instruction.tokens[0].type == .IDENTIFIER && 
        instruction.tokens[0].opcode_type == .NIL &&
        instruction.tokens[1].type == .OPCODE
    {
      error = SyntaxError{
        type = .MISSING_COLON,
        line = instruction.tokens[0].line
      }

      break
    }

    if resolve_parser_error(error) do return
  }

  // Semantics
  for line_num := 0; line_num < sim.line_count; line_num += 1
  {
    if sim.instructions[line_num].tokens == nil do continue

    error: ParserError
    instruction := sim.instructions[line_num]

    if line_num >= sim.text_section_pos
    {
      if instruction.tokens[0].opcode_type == .NIL && 
          instruction.tokens[2].opcode_type == .NIL
      {
        error = TypeError{
          line = instruction.tokens[0].line,
          column = instruction.tokens[0].column,
          token = instruction.tokens[0],
          expected_type = .OPCODE,
          actual_type = instruction.tokens[0].type
        }
      }
    }

    if resolve_parser_error(error) do return
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

print_tokens :: proc()
{
  for i in 0..<sim.line_count
  {
    for tok in sim.instructions[i].tokens
    {
      if tok.type == .NIL do continue
      fmt.print("{", tok.data, "|", tok.type , "}", "")
    }

    fmt.print("\n")
  }

  fmt.print("\n")
}

print_tokens_at :: proc(line_num: int)
{
  for tok in sim.instructions[line_num].tokens
  {
    if tok.type == .NIL do continue
    fmt.print("{", tok.data, "|", tok.type , "}", "")
  }
  
  fmt.print("\n")
}

register_from_token :: proc(token: Token) -> (RegisterID, bool)
{
  result: RegisterID
  err: bool

  switch token.data
  {
  case "x0", "zero": result = .ZR
  case "x1", "ra":   result = .RA
  case "x2", "sp":   result = .SP
  case "x3", "gp":   result = .GP
  case "x4", "tp":   result = .TP
  case "x5", "t0":   result = .T0
  case "x6", "t1":   result = .T1
  case "x7", "t2":   result = .T2
  case "x8", "fp":   result = .FP
  case "x9", "s1":   result = .S1
  case "x10", "a0":  result = .A0
  case "x11", "a1":  result = .A1
  case "x12", "a2":  result = .A2
  case "x13", "a3":  result = .A3
  case "x14", "a4":  result = .A4
  case "x15", "a5":  result = .A5
  case "x16", "a6":  result = .A6
  case "x17", "a7":  result = .A7
  case "x18", "s2":  result = .S2
  case "x19", "s3":  result = .S3
  case "x20", "s4":  result = .S4
  case "x21", "s5":  result = .S5
  case "x22", "s6":  result = .S6
  case "x23", "s7":  result = .S7
  case "x24", "s8":  result = .S8
  case "x25", "s9":  result = .S9
  case "x26", "s10": result = .S10
  case "x27", "s11": result = .S11
  case "x28", "t3":  result = .T3
  case "x29", "t4":  result = .T4
  case "x30", "t5":  result = .T5
  case "x31", "t6":  result = .T6
  case: err = true
  }

  return result, err
}

operand_from_operands :: proc(operands: []Token, idx: int) -> (Operand, bool)
{
  result: Operand
  err: bool

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

// @ParserError ////////////////////////////////////////////////////////////////

ParserError :: union
{
  SyntaxError,
  TypeError,
  OpcodeError,
}

SyntaxError :: struct
{
  type: SyntaxErrorType,
  line: int,
  column: int,
  token: Token,
}

SyntaxErrorType :: enum
{
  MISSING_IDENTIFIER,
  MISSING_LITERAL,
  MISSING_COLON,
  UNIDENTIFIED_IDENTIFIER,
}

TypeError :: struct
{
  line: int,
  column: int,
  expected_type: TokenType,
  actual_type: TokenType,
  token: Token,
}

OpcodeError :: struct
{
  line: int,
  column: int,
  token: Token,
}

resolve_parser_error :: proc(error: ParserError) -> bool
{
  if error == nil do return false
  
  term.color(.RED)
  fmt.print("[PARSER ERROR]: ")

  switch v in error
  {
  case SyntaxError:
    switch v.type
    {
    case .MISSING_COLON: 
      fmt.printf("Missing colon after label on line %i.\n", v.line)
    case .MISSING_IDENTIFIER: 
      fmt.printf("")
    case .MISSING_LITERAL: 
      fmt.printf("")
    case .UNIDENTIFIED_IDENTIFIER: 
      fmt.printf("")
    }
  case TypeError:
    fmt.printf("Type mismatch on line %i. Expected \'%s\', got \'%s\'.\n", 
                v.line, 
                v.expected_type, 
                v.actual_type)
  case OpcodeError:
  }

  term.color(.WHITE)

  return true
}
