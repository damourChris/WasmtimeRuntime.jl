# Main generator script that runs the generation process
# This file can be executed directly to run the generation,
# or the functions can be imported from generator_functions.jl for testing

include("generator_functions.jl")

# Run the generation when this file is executed directly
# This allows the file to be included without running generation
if abspath(PROGRAM_FILE) == @__FILE__
    run_generation()
end
