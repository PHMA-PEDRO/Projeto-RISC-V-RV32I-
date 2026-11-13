// =============================================================================
// pl_alu_ctrl.sv
// Unidade de Controle da ALU -- RV32I pipelined
// =============================================================================

`timescale 1ns / 1ps

module pl_alu_ctrl (
    input  logic [1:0] ALUOp,
    input  logic [6:0] Funct7,
    input  logic [2:0] Funct3,
    output logic [3:0] Operation
);

    // Codigos de operacao da ALU
    localparam ALU_ADD  = 4'd1;
    localparam ALU_SUB  = 4'd2;
    localparam ALU_OR   = 4'd4;
    localparam ALU_AND  = 4'd5;
    localparam ALU_XOR  = 4'd6;
    localparam ALU_SLL  = 4'd7;
    localparam ALU_SRL  = 4'd8;
    localparam ALU_SRA  = 4'd9;
    localparam ALU_SLT  = 4'd11;
    localparam ALU_SLTU = 4'd12;

    always_comb begin

        Operation = ALU_ADD;

        case (ALUOp)

            // -------------------------------------------------------------
            // ADD: calculo de endereco
            // -------------------------------------------------------------
            2'b00: begin
                Operation = ALU_ADD;
            end

            // -------------------------------------------------------------
            // SUB: comparacao usada nos branches
            // -------------------------------------------------------------
            2'b01: begin
                Operation = ALU_SUB;
            end

            // -------------------------------------------------------------
            // R-type
            // -------------------------------------------------------------
            2'b10: begin

                case (Funct3)

                    3'b000: begin
                        if (Funct7 == 7'b0100000)
                            Operation = ALU_SUB;
                        else
                            Operation = ALU_ADD;
                    end

                    3'b001:
                        Operation = ALU_SLL;

                    3'b010:
                        Operation = ALU_SLT;

                    3'b011:
                        Operation = ALU_SLTU;

                    3'b100:
                        Operation = ALU_XOR;

                    3'b101: begin
                        if (Funct7 == 7'b0100000)
                            Operation = ALU_SRA;
                        else
                            Operation = ALU_SRL;
                    end

                    3'b110:
                        Operation = ALU_OR;

                    3'b111:
                        Operation = ALU_AND;

                    default:
                        Operation = ALU_ADD;

                endcase
            end

            // -------------------------------------------------------------
            // I-type
            // -------------------------------------------------------------
            2'b11: begin

                case (Funct3)

                    3'b000:
                        Operation = ALU_ADD;  // ADDI

                    3'b001:
                        Operation = ALU_SLL;  // SLLI

                    3'b010:
                        Operation = ALU_SLT;  // SLTI

                    3'b011:
                        Operation = ALU_SLTU; // SLTIU

                    3'b100:
                        Operation = ALU_XOR;  // XORI

                    3'b101: begin
                        if (Funct7 == 7'b0100000)
                            Operation = ALU_SRA; // SRAI
                        else
                            Operation = ALU_SRL; // SRLI
                    end

                    3'b110:
                        Operation = ALU_OR;   // ORI

                    3'b111:
                        Operation = ALU_AND;  // ANDI

                    default:
                        Operation = ALU_ADD;

                endcase
            end

            default:
                Operation = ALU_ADD;

        endcase
    end

endmodule
