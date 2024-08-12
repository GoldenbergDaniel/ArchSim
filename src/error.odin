package main

Error :: union
{
  bool,
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

resolve_error :: proc(error: Error) -> bool
{
  if error == nil do return false
  
  term.color(.RED)
  fmt.print("[ERROR]: ")
  
  switch v in error
  {
    case SyntaxError:
    {
      #partial switch v.type
      {
        case .MISSING_COLON: fmt.printf("Missing colon after label on line %i.\n", 
                                        v.line)
      }
    }
    case TypeError:
    {
      fmt.printf("Type mismatch on line %i. Expected \'%s\', got \'%s\'.\n", 
                 v.line, 
                 v.expected_type, 
                 v.actual_type)
    }
    case OpcodeError: {}
    case bool: {}
  }

  term.color(.WHITE)

  return true
}

import "core:fmt"

import "term"
