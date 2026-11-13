// =============================================================================
// pl_pipe_pkg.sv
// Definicoes dos registradores de pipeline -- processador RV32I pipelined
//
// Quatro registradores de pipeline:
//   IF/ID  : resultado da busca de instrucao
//   ID/EX  : resultado da decodificacao + leitura do banco de registradores
//   EX/MEM : resultado da execucao (ALU)
//   MEM/WB : resultado do acesso a memoria
// =============================================================================

package pl_pipe_pkg;

    // IF/ID
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] instr;
    } if_id_t;


    // ID/EX
    typedef struct packed {

        // Sinais de controle
        logic        alu_src;
        logic        mem_to_reg;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic [1:0]  alu_op;

        logic        branch;
        logic        is_lui;
        logic        is_auipc;
        logic        is_jal;
        logic        is_jalr;

        // Dados
        logic [31:0] pc;
        logic [31:0] rd1;
        logic [31:0] rd2;

        logic [4:0]  rs1;
        logic [4:0]  rs2;
        logic [4:0]  rd;

        logic [31:0] imm_ext;

        logic [2:0]  funct3;
        logic [6:0]  funct7;

    } id_ex_t;


    // EX/MEM
    typedef struct packed {

        // Sinais de controle
        logic        mem_to_reg;
        logic        reg_write;
        logic        mem_read;
        logic        mem_write;
        logic        is_link;

        // Dados
        logic [31:0] alu_result;
        logic [31:0] write_data;
        logic [31:0] pc_plus4;

        logic [4:0]  rd;
        logic [2:0]  funct3;

    } ex_mem_t;


    // MEM/WB
    typedef struct packed {

        // Sinais de controle
        logic        mem_to_reg;
        logic        reg_write;
        logic        is_link;

        // Dados
        logic [31:0] alu_result;
        logic [31:0] read_data;
        logic [31:0] pc_plus4;

        logic [4:0]  rd;

    } mem_wb_t;

endpackage
