/** HOLY CORE DEBUG INTERFACE
*
*   The goal is to have a way to route inner signals to top module outputs for debug purpose
*/

interface debug_if;
    // Core debug signals
    logic [31:0] instruction;
    logic [31:0] pc;

    // Cache debug signals
    logic [2:0] i_cache_state; 
    logic [2:0] d_cache_state; 
    logic i_cache_stall;
    logic d_cache_stall; 
    logic [6:0] i_cache_set_ptr;
    logic [6:0] d_cache_set_ptr;

    // Modports for output
    modport master (
        output instruction,
        output pc,
        output i_cache_state,
        output d_cache_state,
        output i_cache_stall,
        output d_cache_stall,
        output i_cache_set_ptr,
        output d_cache_set_ptr
    );
endinterface