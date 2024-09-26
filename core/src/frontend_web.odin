package main

@(export, private="file")
get_simulator_data :: proc "contextless" () -> rawptr
{
  return &sim
}
