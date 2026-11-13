// =============================================================================
// pl_control.sv
// Unidade de Controle Principal -- RV32I pipelined
// =============================================================================

`timescale 1ns / 1ps

module pl_control (
    input  logic [6:0] Opcode,

    output logic       ALUSrc,
    output logic       MemtoReg,
    output logic       RegWrite,
    output logic       MemRead,
    output logic       MemWrite,
    output logic       Branch,
    output logic [1:0] ALUOp,

    output logic       IsLUI,
    output logic       IsAUIPC,
    output logic       IsJAL,
    output logic       IsJALR
);

    // OpCodes
    localparam R_TYPE = 7'b0110011;
    localparam LOAD   = 7'b0000011;
    localparam STORE  = 7'b0100011;
    localparam BRANCH = 7'b1100011;
    localparam I_TYPE = 7'b0010011;
    localparam LUI    = 7'b0110111;
    localparam AUIPC  = 7'b0010111;
    localparam JAL    = 7'b1101111;
    localparam JALR   = 7'b1100111;

    always_comb begin

        // Valores padrao
        ALUSrc   = 1'b0;
        MemtoReg = 1'b0;
        RegWrite = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        ALUOp    = 2'b00;

        IsLUI    = 1'b0;
        IsAUIPC  = 1'b0;
        IsJAL    = 1'b0;
        IsJALR   = 1'b0;

        case (Opcode)

            // -------------------------------------------------------------
            // R-type: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
            // -------------------------------------------------------------
            R_TYPE: begin
                RegWrite = 1'b1;
                ALUOp    = 2'b10;
            end

            // -------------------------------------------------------------
            // Loads: LB, LH, LW, LBU, LHU
            // -------------------------------------------------------------
            LOAD: begin
                ALUSrc   = 1'b1;
                MemtoReg = 1'b1;
                RegWrite = 1'b1;
                MemRead  = 1'b1;
                ALUOp    = 2'b00;
            end

            // -------------------------------------------------------------
            // Stores: SB, SH, SW
            // -------------------------------------------------------------
            STORE: begin
                ALUSrc   = 1'b1;
                MemWrite = 1'b1;
                ALUOp    = 2'b00;
            end

            // -------------------------------------------------------------
            // Branches: BEQ, BNE, BLT, BGE, BLTU, BGEU
            // A condicao sera avaliada no datapath usando Funct3.
            // -------------------------------------------------------------
            BRANCH: begin
                Branch = 1'b1;
                ALUOp  = 2'b01;
            end

            // -------------------------------------------------------------
            // I-type: ADDI, ANDI, ORI, SLTI, XORI, SLLI, SRLI, SRAI
            // -------------------------------------------------------------
            I_TYPE: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                ALUOp    = 2'b11;
            end

            // -------------------------------------------------------------
            // LUI
            // -------------------------------------------------------------
            LUI: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                IsLUI    = 1'b1;
                ALUOp    = 2'b00;
            end

            // -------------------------------------------------------------
            // AUIPC
            // -------------------------------------------------------------
            AUIPC: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                IsAUIPC  = 1'b1;
                ALUOp    = 2'b00;
            end

            // -------------------------------------------------------------
            // JAL: salto incondicional relativo ao PC
            // -------------------------------------------------------------
            JAL: begin
                RegWrite = 1'b1;
                IsJAL    = 1'b1;
            end

            // -------------------------------------------------------------
            // JALR: salto indireto usando rs1 + imediato
            // -------------------------------------------------------------
            JALR: begin
                ALUSrc   = 1'b1;
                RegWrite = 1'b1;
                IsJALR   = 1'b1;
                ALUOp    = 2'b00;
            end

            default: begin
                // todos os sinais permanecem desabilitados.
            end

        endcase
    end

endmodule
