# builds the sources
build:
    zig build -freference-trace --prominent-compile-errors # -Doptimize=ReleaseSmall

# creates a disassembly of the project
disasm: build
    llvm-objdump -S zig-out/firmware/ese24-demo.elf | tee zig-out/firmware/ese24-demo.dump

# loads the application via picotool
load: build
    picotool load -uvx zig-out/firmware/ese24-demo.uf2

# flashes the application via openocd
flash: build
    openocd -f tools/openocd.cfg -c "program zig-out/firmware/ese24-demo.elf reset exit"

# starts openocd server to listen for gdb connection
ocd:
    openocd -f tools/openocd.cfg -s tcl

# starts gdb. requires "ocd" before
gdb:
    gdb -x .gdbinit zig-out/firmware/ese24-demo.elf

# starts picocom to monitor the target
monitor:
    picocom --baud 115200 /dev/ttyACM0
