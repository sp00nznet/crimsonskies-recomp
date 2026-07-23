cmake_minimum_required(VERSION 3.20)
project(crimsonskies_recomp C)

# Crimson Skies: High Road to Revenge - Static Recompilation
# Builds all compatibility layers and the recompiled game executable

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Common definitions
add_compile_definitions(
    WIN32_LEAN_AND_MEAN
    NOMINMAX
)

# Record every indirect-branch target the game reaches, so the next codegen
# pass can seed function detection with measurements instead of inference.
# Costs one byte store per indirect call; off by default.
# See xboxrecomp docs/technical/indirect-calls.md ("Target Feedback").
option(CS_ICALL_FEEDBACK "Record indirect-branch targets for codegen feedback" OFF)
if(CS_ICALL_FEEDBACK)
    add_compile_definitions(RECOMP_ICALL_FEEDBACK)
    message(STATUS "ICALL target feedback: ON")
endif()

# ── xboxrecomp runtime libraries ──────────────────────────
# Point this to your xboxrecomp checkout
set(XBOXRECOMP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../xboxrecomp" CACHE PATH "Path to xboxrecomp toolkit")
add_subdirectory(${XBOXRECOMP_DIR} ${CMAKE_BINARY_DIR}/xboxrecomp)

# ── Recompiled game executable ─────────────────────────────
# add_subdirectory(src/game)   # enable once the kernel layer is wired up
