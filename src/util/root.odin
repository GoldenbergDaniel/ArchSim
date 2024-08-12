package util

import runtime "base:runtime"
import intrinsics "base:intrinsics"

// @Arena ///////////////////////////////////////////////////////////////////////////

KIB :: 1 << 10
MIB :: 1 << 20
GIB :: 1 << 30

Arena :: struct
{
  data: [^]byte,
  size: int,
  offset: int,

  ally: runtime.Allocator,
}

create_arena :: proc(size: int, alloctor := context.allocator) -> ^Arena
{
  result: ^Arena = new(Arena, alloctor)
  result.data = make([^]byte, size, runtime.heap_allocator())
  result.size = size
  result.ally = {
    data=result, 
    procedure=arena_allocator_proc,
  }

  runtime.memset(result.data, 0, result.size)

  return result
}

destroy_arena :: proc(arena: ^Arena)
{
  delete(arena.data[:arena.size], runtime.heap_allocator())
}

arena_push :: proc
{
  arena_push_bytes,
  arena_push_item,
  arena_push_array,
}

arena_push_bytes :: proc(arena: ^Arena, size: int, alignment: int = 8) -> rawptr
{
  ptr: rawptr = &arena.data[arena.offset]
  result, offset := align_ptr(ptr, alignment);
  arena.offset += size + offset

  return result
}

arena_push_item :: proc(arena: ^Arena, $T: typeid) -> ^T
{
  ptr: rawptr = &arena.data[arena.offset]
  result, offset := align_ptr(ptr, align_of(T));
  arena.offset += size_of(T) + offset

  return cast(^T) result
}

arena_push_array :: proc(arena: ^Arena, $T: typeid, count: int) -> ^T
{
  ptr: rawptr = &arena.data[arena.offset]
  result, offset := align_ptr(ptr, align_of(T));
  arena.offset += (size_of(T) * count) + offset

  return cast(^T) result
}

arena_pop :: proc
{
  arena_pop_bytes,
  arena_pop_item,
  arena_pop_array,
  arena_pop_map,
}

arena_pop_bytes :: proc(arena: ^Arena, size: int)
{
  arena.offset -= size
  runtime.memset(&arena.data[arena.offset], 0, size)
}

arena_pop_item :: proc(arena: ^Arena, $T: typeid)
{
  arena.offset -= size_of(T)
  runtime.memset(&arena.data[arena.offset], 0, size_of(T))
}

arena_pop_array :: proc(arena: ^Arena, $T: typeid, count: u64)
{
  arena.offset -= size_of(T) * count
  runtime.memset(&arena.data[arena.offset], 0, size_of(T) * count)
}

arena_pop_map :: proc(arena: ^Arena, m: map[$K]$V)
{
  map_info := intrinsics.type_map_info(type_of(m))
  size := cast(int) runtime.map_total_allocation_size(uintptr(cap(m)), map_info)
  arena.offset -= size
  runtime.memset(&arena.data[arena.offset], 0, size)
}

arena_clear :: proc(arena: ^Arena)
{
  runtime.memset(arena.data, 0, arena.offset)
  arena.offset = 0
}

arena_from_allocator :: #force_inline proc(allocator: runtime.Allocator) -> ^Arena
{
  return cast(^Arena) allocator.data
}

arena_allocator_proc :: proc(allocator_data: rawptr, 
                             mode: runtime.Allocator_Mode,
                             size, alignment: int,
                             old_memory: rawptr, old_size: int,
                             location := #caller_location
                        ) -> ([]byte, runtime.Allocator_Error)
{
	arena := cast(^Arena) allocator_data
	switch mode
  {
	  case .Alloc, .Alloc_Non_Zeroed:
    {
      ptr := arena_push_bytes(arena, size, alignment)
      byte_slice := ([^]u8) (ptr)[:max(size, 0)]
      return byte_slice, nil
    }
    case .Free:
    {
      arena_pop_bytes(arena, size)
    }
    case .Free_All:
    {
      arena_clear(arena)
    }
    case .Query_Features, .Query_Info, .Resize, .Resize_Non_Zeroed:
    {
      return nil, .Mode_Not_Implemented
    }
	}

	return nil, nil
}

// @Misc ////////////////////////////////////////////////////////////////////////////

align_ptr :: #force_inline proc(ptr: rawptr, align: int) -> (rawptr, int)
{
	result := cast(uintptr) ptr
  offset: uintptr

	modulo := result & (uintptr(align) - 1)
	if modulo != 0
  {
    offset = uintptr(align) - modulo
		result += offset
	}

	return rawptr(result), int(offset)
}

cpu_cycle_counter :: #force_inline proc() -> i64
{
  return runtime.read_cycle_counter()
}
