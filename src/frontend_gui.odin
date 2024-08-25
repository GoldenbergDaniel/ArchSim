package main

gui_run :: proc()
{
  sapp.run(sapp.Desc{
    window_title = "ArchSim",
    width = 900,
    height = 600,
    fullscreen = false,
    init_cb = gui_init,
    event_cb = gui_input,
    frame_cb = gui_frame,
  })
}

gui_init :: proc "c" ()
{

}

gui_input :: proc "c" (event: ^sapp.Event)
{

}

gui_frame :: proc "c" ()
{

}

import sapp "ext:sokol/app"
