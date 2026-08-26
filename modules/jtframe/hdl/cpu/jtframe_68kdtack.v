/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-5-2021 */

/*

    Generates the standard /DTACK signal expected by the CPU,
    i.e. there is an idle cycle for each bus cycle

    If there is a special bus access, marked by bus_cs, and
    it takes longer to complete than one cycle, the extra time
    will be recovered for later. If bus_legit is high, the time
    will not be recovered as it is identified as legitim wait
    in the original system

    DSn -and not just ASn- must be used so read-modify-write
    instructions have a second /DTACK signal generated for
    the write cycle

    Note that if jtframe_ramrq is used, then DSn must also
    gate the SDRAM requests so you get a cs toggle in the
    middle of the read-modify-write cycles

    DSn goes low one cycle after ASn under some conditions, so
    if ASn | DSn is used to set DTACKn, it will take one more
    cycle than expected on those occasions. Both CPS and S16
    use only ASn to generate DTACKn.

    The M68K requires one wait cycle for all access. But it's
    common to have systems where 2 or 3 wait states are used too.
    The wait2 and wait3 inputs can be set high to use more wait
    states. Clock cycle recovery does not take effect during
    extra wait states requested by the system.

*/

module jtframe_68kdtack(
    input         rst,
    input         clk,
    input         cpu_cen,
    input         cpu_cenb,
    input         bus_busy, // when to apply wait states
    input         ASn,  // DTACKn set low at the next cpu_cen after ASn goes low
    input [1:0]   DSn,  // If DSn goes high, DTACKn is reset high
    input         wait2, // high for 2 wait states
    input         wait3, // high for 3 wait states

    output reg    DTACKn
);

reg [1:0] waitsh;
reg       wait1;

always @(posedge clk) begin : dtack_gen
    if( rst ) begin
        DTACKn <= 1;
        waitsh <= 0;
        wait1  <= 0;
    end else begin
        if( ASn | &DSn ) begin // DSn is needed for read-modify-write cycles
               // performed on the SDRAM. Just checking the DSn rising edge
               // is not enough on Rastan
            DTACKn <= 1;
            wait1  <= 1; // gives a clock cycle to bus_busy to toggle
            waitsh <= {wait3,wait2};
        end else if( !ASn ) begin
            wait1 <= 0;
            if( cpu_cen ) waitsh <= waitsh>>1;
            if( waitsh==0 && !wait1 ) begin
                DTACKn <= DTACKn && bus_busy;
            end
        end
    end
end

endmodule