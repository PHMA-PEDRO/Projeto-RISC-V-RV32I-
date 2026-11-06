`timescale 1ns / 1ps

module pl_dmem (
    input  logic        clk,
    input  logic        MemWrite,
    input  logic [7:0]  addr,
    input  logic [1:0]  addr_offset,
    input  logic [2:0]  funct3,
    input  logic [31:0] WriteData,
    output logic [31:0] ReadData
);

    (* ram_init_file = "data.mif" *) logic [31:0] ram [0:255];

    logic [31:0] shifted_write_data;
    logic [31:0] shifted_read_data;
    logic [3:0] byte_enable;

    // synthesis translate_off
    initial begin
        for (int i = 0; i < 256; i++) ram[i] = 32'h00000000;
        $readmemh("data.hex", ram);
    end
    // synthesis translate_on

    //store
    always_comb begin
        byte_enable = 4'b0000;

        case (funct3)
            3'b000: byte_enable = 4'b0001 << addr_offset; // SB

            3'b001: begin
                if (addr_offset[0] == 1'b0)
                    byte_enable = 4'b0011 << addr_offset; // SH
            end

            3'b010: begin
                if (addr_offset == 2'b00)
                    byte_enable = 4'b1111; // SW
            end

            default: byte_enable = 4'b0000;
        endcase
    end

    assign shifted_write_data = WriteData << (8 * addr_offset);

    always_ff @(posedge clk) begin
        if (MemWrite) begin
            for (int i = 0; i < 4; i++) begin
                if (byte_enable[i])
                    ram[addr][8*i +: 8] <= shifted_write_data[8*i +: 8];
            end
        end
    end

    //load
    assign shifted_read_data = ram[addr] >> (8 * addr_offset);

    always_comb begin
        case (funct3)
            3'b000: ReadData = {{24{shifted_read_data[7]}}, shifted_read_data[7:0]}; // LB
            3'b001: ReadData = {{16{shifted_read_data[15]}}, shifted_read_data[15:0]}; // LH
            3'b010: ReadData = ram[addr]; // LW
            3'b100: ReadData = {24'b0, shifted_read_data[7:0]}; // LBU
            3'b101: ReadData = {16'b0, shifted_read_data[15:0]}; // LHU
            default: ReadData = 32'b0;
        endcase
    end

endmodule
