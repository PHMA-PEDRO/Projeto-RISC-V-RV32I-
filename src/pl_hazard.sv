// =============================================================================
// pl_hazard.sv
// Unidade de deteccao de hazards -- RV32I pipelined
// =============================================================================

`timescale 1ns / 1ps

module pl_hazard (
    input  logic [6:0] if_id_opcode,
    input  logic [4:0] if_id_rs1,
    input  logic [4:0] if_id_rs2,

    input  logic [4:0] id_ex_rd,
    input  logic       id_ex_mem_read,

    output logic       stall
);

    logic uses_rs1;
    logic uses_rs2;

    always_comb begin

        uses_rs1 = 1'b0;
        uses_rs2 = 1'b0;

        case (if_id_opcode)

            // R-type
            7'b0110011: begin
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;
            end

            // Loads
            7'b0000011: begin
                uses_rs1 = 1'b1;
            end

            // Stores
            7'b0100011: begin
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;
            end

            // Branches
            7'b1100011: begin
                uses_rs1 = 1'b1;
                uses_rs2 = 1'b1;
            end

            // I-type arithmetic
            7'b0010011: begin
                uses_rs1 = 1'b1;
            end

            // JALR
            7'b1100111: begin
                uses_rs1 = 1'b1;
            end

            default: begin
                uses_rs1 = 1'b0;
                uses_rs2 = 1'b0;
            end

        endcase

    end

    assign stall = id_ex_mem_read &&
                   (id_ex_rd != 5'b0) &&
                   ((uses_rs1 && (id_ex_rd == if_id_rs1)) ||
                    (uses_rs2 && (id_ex_rd == if_id_rs2)));

endmodule
