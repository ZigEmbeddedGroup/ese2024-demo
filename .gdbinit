target extended-remote :3333

define cll
shell just build
target extended-remote :3333
load
monitor reset init
end

define mri
monitor reset init
end
