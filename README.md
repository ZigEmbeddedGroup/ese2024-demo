# MicroZig Example Project for ESE Kongress 2024

This repository contains an example project for MicroZig, showcasing how to implement a small "product" based on the following requirement.

## "Product Requirements"

> Create a device which can take a rotary input and show the current value in a visual gauge.
>
> The user must be able to turn a jog wheel left or right, and by clicking the jog wheel, reset
> the displayed value back to the original one.

## Implementation

These requirements are implemented by chosing the Raspberry Pi Pico, a SSD1306
based OLED display with 128x64 pixels resolution and a rotary encoder as an input.

All parts are supported well by MicroZig and showcase the usability experience the
project wants to enable for many embedded targets.

All source files are well-explained on how they work and what the features do.

## Compiling

You need the following tools installed to compile the firmware:

- [Zig 0.13.0](https://ziglang.org/download/)

**Hint:** You need to clone this repository recursively, as we use MicroZig as a submodule!

Optionally, you can install the following tools to get an improved user experience:

- [openocd](https://github.com/raspberrypi/openocd) fork by the Raspberry Pi Foundation, to load the application via SWD (you need a debug probe for this!)
- [picotool](https://github.com/raspberrypi/picotool) to load the application without drag-and-drop
- [just](https://github.com/casey/just), to execute prepared recipies
- gdb to debug. Also requires to have *openocd* installed and a debug probe

If you have everything installed, you can use these commands to build the project:

```sh-session
[dev@workstation] ~/ese-24-demo $ just build # use this if you have just installed
zig build -freference-trace --prominent-compile-errors -Doptimize=ReleaseSmall
[dev@workstation] ~/ese-24-demo $ 
[dev@workstation] ~/ese-24-demo $ zig build # or use zig directly
[dev@workstation] ~/ese-24-demo $ 
```

Both commands will yield two files in `zig-out/firmware`:

- `ese24-demo.uf2`: Can be installed via drag-and-drop on your Raspberry Pi Pico
- `ese24-demo.elf`: Can be used for debugging with `gdb` or flashing with `openocd`

## Wiring

Depending on which OLED you have available, you can use one of the two options:

### I²C Wiring

!!!!

### 4-Wire SPI Wiring

!!!!

