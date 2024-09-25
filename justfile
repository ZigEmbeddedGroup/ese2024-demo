build:
    zig build

disasm: build
    llvm-objdump -S zig-out/firmware/ese24-demo.elf | tee zig-out/firmware/ese24-demo.dump

load: build
    picotool load -uvx zig-out/firmware/ese24-demo.uf2

ocd:
    openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg -s tcl

gdb:
    gdb -x .gdbinit zig-out/firmware/ese24-demo.elf

monitor:
    picocom --baud 115200 /dev/ttyACM0
