package main

import "core:fmt"
import "core:mem/virtual"
import "core:os"

import "term"

MAX_SRC_BUF_BYTES   :: 2048
MAX_LINES           :: 64
MAX_TOKENS_PER_LINE :: 8

BASE_ADDRESS     :: 0x10_00_00_00
MEMORY_SIZE      :: 65535
INSTRUCTION_SIZE :: 4

Address :: distinct u32
Number  :: distinct i32

Simulator :: struct
{
  should_quit: bool,
  step_to_next: bool,

  instructions: []Instruction,
  line_count: int,
  symbol_table: map[string]Number,
  data_section_pos: int,
  text_section_pos: int,
  branch_to_idx: int,

  memory: []byte,
  registers: [RegisterID]Number,
  registers_prev: [RegisterID]Number,

  perm_arena: virtual.Arena,
  temp_arena: virtual.Arena
}

OpcodeType :: enum
{
  NIL,

  NOP,
  MV,
  
  ADD,
  SUB,
  AND,
  OR,
  XOR,
  NOT,
  NEG,
  SLL,
  SRL,
  SRA,

  J,
  JR,
  JAL,
  JALR,

  BEQ,
  BNE,
  BLT,
  BGT,
  BLE,
  BGE,
  BEQZ,
  BNEZ,
  BLTZ,
  BGTZ,
  BLEZ,
  BGEZ,

  LB,
  LH,
  LW,
  SB,
  SH,
  SW,

  LUI,
}

RegisterID :: enum
{
  ZR, RA, SP, GP, TP, T0, T1, T2, 
  FP, S1, A0, A1, A2, A3, A4, A5, 
  A6, A7, S2, S3, S4, S5, S6, S7, 
  S8, S9, S10, S11, T3, T4, T5, T6, 
}

Operand :: union
{
  Number,
  RegisterID,
}

opcode_table: map[string]OpcodeType = {
  ""      = .NIL,

  "nop"   = .NOP,
  "mv"    = .MV,

  "add"   = .ADD,
  "sub"   = .SUB,
  "and"   = .AND,
  "or"    = .OR,
  "xor"   = .XOR,
  "not"   = .NOT,
  "neg"   = .NEG,
  "sll"   = .SLL,
  "srl"   = .SRL,
  "sra"   = .SRA,

  "j"     = .J,
  "jr"    = .JR,
  "jal"   = .JAL,
  "jalr"  = .JALR,

  "beq"   = .BEQ,
  "bne"   = .BNE,
  "blt"   = .BLT,
  "bgt"   = .BGT,
  "ble"   = .BLE,
  "bge"   = .BGE,
  "beqz"  = .BEQZ,
  "bnez"  = .BNEZ,
  "bltz"  = .BLTZ,
  "bgtz"  = .BGTZ,
  "blez"  = .BLEZ,
  "bgez"  = .BGEZ,

  "lb"    = .LB,
  "lh"    = .LH,
  "lw"    = .LW,
  "sb"    = .SB,
  "sh"    = .SH,
  "sw"    = .SW,

  "lui"   = .LUI,
}

sim: Simulator

main :: proc()
{
  // Initialize memory arenas ----------------
  {
    err := virtual.arena_init_static(&sim.perm_arena)
    assert(err == nil, "Failed to initialize perm arena!")

    err = virtual.arena_init_growing(&sim.temp_arena)
    assert(err == nil, "Failed to initialize temp arena!")
  }

  perm_arena_ally := virtual.arena_allocator(&sim.perm_arena)
  context.allocator = perm_arena_ally

  temp_arena_ally := virtual.arena_allocator(&sim.temp_arena)
  context.temp_allocator = temp_arena_ally

  tui_print_welcome()

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
  os.close(src_file)

  sim.instructions = make([]Instruction, MAX_LINES)
  sim.memory = make([]byte, MEMORY_SIZE)
  sim.step_to_next = true

  // Tokenize ----------------
  tokenize_code_from_bytes(src_data)
  // print_tokens()

  // Preprocess ----------------
  {
    data_offset: Address

    for line_num := 0; line_num < sim.line_count; line_num += 1
    {
      defer free_all(context.temp_allocator)

      if sim.instructions[line_num].tokens == nil do continue

      instruction := sim.instructions[line_num]

      // Directives
      if instruction.tokens[0].type == .DIRECTIVE
      {
        if len(instruction.tokens) < 2 do continue

        switch instruction.tokens[0].data
        {
        case ".equ":
          val := cast(Number) str_to_int(instruction.tokens[2].data)
          sim.symbol_table[instruction.tokens[1].data] = val
        case ".byte":
          val := cast(Number) str_to_int(instruction.tokens[2].data)
          bytes := bytes_from_value(val, 1)
          address := BASE_ADDRESS + data_offset
          memory_store_bytes(address, bytes)
          sim.symbol_table[instruction.tokens[1].data] = cast(Number) address
          data_offset += 1
        case ".half":
          val := cast(Number) str_to_int(instruction.tokens[2].data)
          bytes := bytes_from_value(val, 2)
          address := BASE_ADDRESS + data_offset
          memory_store_bytes(address, bytes)
          sim.symbol_table[instruction.tokens[1].data] = cast(Number) address
          data_offset += 2
        case ".word":
          val := cast(Number) str_to_int(instruction.tokens[2].data)
          bytes := bytes_from_value(val, 4)
          address := BASE_ADDRESS + data_offset
          memory_store_bytes(address, bytes)
          sim.symbol_table[instruction.tokens[1].data] = cast(Number) address
          data_offset += 4
        case ".section":
          if instruction.tokens[1].data == ".text"
          {
            sim.text_section_pos = line_num + 1
          }
        }
      }

      // Labels
      if instruction.tokens[0].type == .IDENTIFIER && 
         instruction.tokens[1].type == .COLON
      {
        sim.symbol_table[instruction.tokens[0].data] = cast(Number) line_num
      }
    }
  }

  // Error check ----------------
  error_check_instructions()

  // Execute ----------------
  for line_num := sim.text_section_pos; line_num < sim.line_count;
  {
    defer free_all(context.temp_allocator)

    if sim.instructions[line_num].tokens == nil
    {
      line_num += 1
      continue
    }

    instruction := sim.instructions[line_num]

    if instruction.has_breakpoint
    {
      sim.step_to_next = true
    }

    // Prompt user command ----------------
    if sim.step_to_next && line_num < sim.line_count
    {
      for done: bool; !done;
      {
        done = tui_prompt_command()
      }
    }

    if sim.should_quit do return

    sim.branch_to_idx = line_num + 1

    // Fetch opcode and operands ----------------
    opcode: Token
    operands: [3]Token
    {
      if instruction.tokens[0].type == .OPCODE
      {
        opcode = instruction.tokens[0]
        operands[0] = instruction.tokens[1]
        operands[1] = instruction.tokens[2]
        operands[2] = instruction.tokens[3]
      }
      else if instruction.tokens[2].type == .OPCODE
      {
        opcode = instruction.tokens[2]
        operands[0] = instruction.tokens[3]
        operands[1] = instruction.tokens[4]
        operands[2] = instruction.tokens[5]
      }
    }

    error: bool

    switch opcode.opcode_type
    {
    case .NIL: panic("NIL opcode")
    case .NOP: {}
    case .MV:
      dest_reg, err0 := operand_from_operands(operands[:], 0)
      op1_reg, err1  := operand_from_operands(operands[:], 1)
      
      error = err0 || err1
      if !error
      {
        val: Number
        switch v in op1_reg
        {
        case Number:     val = v
        case RegisterID: val = sim.registers[v]
        }

        sim.registers[dest_reg.(RegisterID)] = val
      }
    case .ADD: fallthrough
    case .SUB: fallthrough
    case .AND: fallthrough
    case .OR:  fallthrough
    case .XOR: fallthrough
    case .NOT: fallthrough
    case .NEG: fallthrough
    case .SLL: fallthrough
    case .SRL: fallthrough
    case .SRA: fallthrough
    case .LUI:
      dest_reg, err0 := operand_from_operands(operands[:], 0)
      op1_reg,  err1 := operand_from_operands(operands[:], 1)
      op2_reg,  err2 := operand_from_operands(operands[:], 2)

      error = err0 || err1 || err2
      if !error
      {
        val1, val2: Number
        
        switch v in op1_reg
        {
        case Number:     val1 = v
        case RegisterID: val1 = sim.registers[v]
        }

        switch v in op2_reg
        {
        case Number:     val2 = v
        case RegisterID: val2 = sim.registers[v]
        }
        
        result: Number
        #partial switch instruction.tokens[0].opcode_type
        {
          case .ADD:   result = val1 + val2
          case .SUB:   result = val1 - val2
          case .AND:   result = val1 & val2
          case .OR:    result = val1 | val2
          case .XOR:   result = val1 | val2
          case .NOT:   result = ~val1
          case .NEG:   result = -result
          case .SLL:   result = val1 << u64(val2)
          case .SRL:   {}
          case .SRA:   result = arithmetic_shift_right(val1, uint(val2))
          case .LUI:   result = val1 << 12
        }

        sim.registers[dest_reg.(RegisterID)] = result
      }
    case .BEQ:  fallthrough
    case .BNE:  fallthrough
    case .BLT:  fallthrough
    case .BGT:  fallthrough
    case .BLE:  fallthrough
    case .BGE:  fallthrough
    case .BEQZ: fallthrough
    case .BNEZ: fallthrough
    case .BLTZ: fallthrough
    case .BGTZ: fallthrough
    case .BLEZ: fallthrough
    case .BGEZ:
      oper1, err0 := operand_from_operands(operands[:], 0)
      oper2, err1 := operand_from_operands(operands[:], 1)
      dest, err2  := operand_from_operands(operands[:], 2)

      error = err0 || err1 || err2
      if !error
      {
        val1, val2: Number

        switch v in oper1
        {
        case Number:     val1 = v
        case RegisterID: val1 = sim.registers[v]
        }

        switch v in oper2
        {
        case Number:     val2 = v
        case RegisterID: val2 = sim.registers[v]
        }

        should_jump: bool
        #partial switch opcode.opcode_type
        {
          case .BEQ:  should_jump = val1 == val2
          case .BNE:  should_jump = val1 != val2
          case .BLT:  should_jump = val1 < val2
          case .BGT:  should_jump = val1 > val2
          case .BLE:  should_jump = val1 <= val2
          case .BGE:  should_jump = val1 >= val2
          case .BEQZ: should_jump = val1 == 0
          case .BNEZ: should_jump = val1 != 0
          case .BLTZ: should_jump = val1 < 0
          case .BGTZ: should_jump = val1 > 0
          case .BLEZ: should_jump = val1 <= 0
          case .BGEZ: should_jump = val1 >= 0
        }

        if should_jump
        {
          sim.branch_to_idx = cast(int) dest.(Number)
        }
      }
    case .J:   fallthrough
    case .JR:  fallthrough
    case .JAL: fallthrough
    case .JALR:
      oper, err0 := operand_from_operands(operands[:], 0)

      target_line_num: int
      if opcode.opcode_type == .JR || opcode.opcode_type == .JALR
      {
        target_line_num = cast(int) sim.registers[oper.(RegisterID)]
      }
      else
      {
        target_line_num = cast(int) oper.(Number)
      }

      error = err0
      if !error
      {
        should_jump: bool
        #partial switch opcode.opcode_type
        {
        case .J:
          should_jump = true
        case .JR:
          should_jump = true
          target_line_num = line_index_from_address(Address(target_line_num))
        case .JAL:
          should_jump = true
          sim.registers[.RA] = cast(Number) target_line_num + 1
        case .JALR:
          should_jump = true
          sim.registers[.RA] = cast(Number) target_line_num + 1
          target_line_num = line_index_from_address(Address(target_line_num))
        }

        if should_jump
        {
          sim.branch_to_idx = target_line_num
        }
      }
    case .LB: fallthrough
    case .LH: fallthrough
    case .LW:
      dest, err0 := operand_from_operands(operands[:], 0)
      src, err1  := operand_from_operands(operands[:], 1)
      off, err2  := operand_from_operands(operands[:], 2)

      error = err0 || err1 || err2
      if !error
      {
        src_address := cast(Address) off.(Number)
        switch v in src
        {
        case Number:     src_address += cast(Address) v
        case RegisterID: src_address += cast(Address) sim.registers[v]
        }

        @(static)
        size := [?]uint{
          OpcodeType.LB = 1, 
          OpcodeType.LH = 2, 
          OpcodeType.LW = 4
        }

        bytes := memory_load_bytes(src_address, size[opcode.opcode_type])
        value := value_from_bytes(bytes)
        sim.registers[dest.(RegisterID)] = value
      }
    case .SB: fallthrough
    case .SH: fallthrough
    case .SW:
      src, err0  := operand_from_operands(operands[:], 0)
      dest, err1 := operand_from_operands(operands[:], 1)
      off, err2  := operand_from_operands(operands[:], 2)

      error = err0 || err1 || err2
      if !error
      {
        dest_address := cast(Address) off.(Number)
        switch v in dest
        {
        case Number:     dest_address += cast(Address) v
        case RegisterID: dest_address += cast(Address) sim.registers[v]
        }

        @(static)
        size := [?]int{OpcodeType.SB = 1, OpcodeType.SH = 2, OpcodeType.SW = 4}

        value := sim.registers[src.(RegisterID)]
        bytes := bytes_from_value(value, size[opcode.opcode_type])
        memory_store_bytes(dest_address, bytes)
      }
    }

    if error
    {
      term.color(.RED)
      fmt.eprintf("[ERROR]: Failed to execute instruction on line %i.\n", line_num+1)
      term.color(.WHITE)
      return
    }

    tui_print_sim_result(instruction, line_num)

    // Set next instruction to result of branch
    line_num = sim.branch_to_idx

    if !(sim.step_to_next && line_num < sim.line_count - 1)
    {
      fmt.print("\n")
    }  
  }
}

address_is_valid :: proc(address: Address) -> bool
{
  return address >= BASE_ADDRESS && address <= BASE_ADDRESS + MEMORY_SIZE
}

address_from_line_index :: proc(line_num: int) -> Address
{
  assert(line_num < MAX_LINES)

  result: Address

  @(static)
  line_num_to_address_cache: [MAX_LINES]Address

  if line_num_to_address_cache[line_num] != 0
  {
    result = line_num_to_address_cache[line_num]
  }
  else
  {
    for i := sim.text_section_pos; i < line_num; i += 1
    {
      if sim.instructions[i].tokens != nil
      {
        result += INSTRUCTION_SIZE
      }
    }

    line_num_to_address_cache[line_num] = result
  }

  result += BASE_ADDRESS

  return result
}

line_index_from_address :: proc(address: Address) -> int
{
  assert(int(address - BASE_ADDRESS) < sim.line_count * INSTRUCTION_SIZE)

  result: int

  address := address
  address -= BASE_ADDRESS
  accumulator: Address

  @(static)
  address_to_line_num_cache: [MAX_LINES]int

  if address_to_line_num_cache[address] != 0
  {
    result = address_to_line_num_cache[address]
  }
  else
  {
    for i := 0; i < sim.line_count && accumulator <= address; i += 1
    {
      if sim.instructions[i].tokens != nil && i >= sim.text_section_pos
      {
        accumulator += INSTRUCTION_SIZE
      }

      result += 1
    }

    address_to_line_num_cache[address] = result
  }

  result -= 1

  return result
}

arithmetic_shift_right :: proc(number: Number, shift: uint) -> Number
{
  number := number  

  for _ in 0..<shift
  {
    BIT_31 :: 1 << 31
    if number & transmute(Number) u32(BIT_31) != 0
    {
      number >>= 1
      number |= transmute(Number) u32(BIT_31)
    }
    else
    {
      number >>= 1
    }
  }

  return number
}

memory_load_bytes :: proc(address: Address, size: uint) -> []byte
{
  address := cast(uint) address
  assert(address >= BASE_ADDRESS && address + size <= BASE_ADDRESS + 0xFFFF)
  address -= BASE_ADDRESS

  return sim.memory[address:address+size]
}

memory_store_bytes :: proc(address: Address, bytes: []byte)
{
  address := cast(int) address
  size := len(bytes)
  assert(address >= BASE_ADDRESS && address + size <= BASE_ADDRESS + 0xFFFF)
  address -= BASE_ADDRESS

  for i in address..<address+size
  {
    sim.memory[i] = bytes[i - address]
  }
}

value_from_bytes :: proc(bytes: []byte) -> Number
{
  result: Number
  size := len(bytes)

  assert(size == 1 || size == 2 || size == 4 || size == 8)

  for i in 0..<size
  {
    result |= Number(bytes[i]) << (uint(size-i-1) * 8)
  }

  return result
}

bytes_from_value :: proc(value: Number, size: int) -> []byte
{
  result: []byte = make([]byte, size)

  for i in 0..<size
  {
    result[i] = byte((value >> (uint(size-i-1) * 8)) & 0b11111111)
  }

  return result
}
