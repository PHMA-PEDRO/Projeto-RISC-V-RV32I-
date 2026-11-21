# Processador RV32I com Pipeline de 5 Estágios — Relatório do Projeto

Processador RISC-V de 32 bits implementado em SystemVerilog, com pipeline de 5 estágios
baseado nas seções 4.6 a 4.10 de *Computer Organization and Design: RISC-V Edition*
(Patterson & Hennessy). A plataforma alvo é a placa **DE2-115** (Intel Cyclone IV E,
EP4CE115F29C7).

O projeto partiu de um processador-base que executava 8 instruções (`ADD`, `SUB`, `OR`,
`AND`, `SLT`, `LW`, `SW`, `BEQ`). Ao longo de duas etapas, a equipe estendeu o processador
até cobrir **as 37 instruções do conjunto base RV32I** e validou cada uma em simulação
e na placa, por meio de um dump serial do estado do processador.

## Equipe

| Integrante | Identificação no Git |
|---|---|
| Pedro Henrique de Melo Albuquerque | `Pedro Henrique de Melo Albuquerque` |
| Pedro Henrique Borges Ribeiro | `Pedro Ribeio` / `Pedro Henrique Borges Ribeiro` |
| Diogo Dias | `diogodias0902` |

---

## Sumário

1. [Resultado final](#resultado-final)
2. [Arquitetura](#arquitetura)
3. [Etapa 01 — R-type e I-type aritmético](#etapa-01--r-type-e-i-type-aritmético)
4. [Etapa 02 — memória, desvios, saltos e U-type](#etapa-02--memória-desvios-saltos-e-u-type)
5. [Validação na placa: dump serial](#validação-na-placa-dump-serial)
6. [Problemas encontrados na placa e soluções](#problemas-encontrados-na-placa-e-soluções)
7. [Testes](#testes)
8. [Como reproduzir](#como-reproduzir)
9. [Estrutura do repositório](#estrutura-do-repositório)

---

## Resultado final

| Categoria | Instruções | Status |
|---|---|:---:|
| R-type | `ADD` `SUB` `SLL` `SLT` `SLTU` `XOR` `SRL` `SRA` `OR` `AND` | ✅ 10/10 |
| I-type aritmético | `ADDI` `SLTI` `SLTIU` `XORI` `ORI` `ANDI` `SLLI` `SRLI` `SRAI` | ✅ 9/9 |
| I-type load | `LB` `LH` `LW` `LBU` `LHU` | ✅ 5/5 |
| S-type | `SB` `SH` `SW` | ✅ 3/3 |
| B-type | `BEQ` `BNE` `BLT` `BGE` `BLTU` `BGEU` | ✅ 6/6 |
| U-type | `LUI` `AUIPC` | ✅ 2/2 |
| J-type | `JAL` `JALR` | ✅ 2/2 |
| **Total** | | **✅ 37/37** |

Os resultados dos testes na placa batem com os valores esperados, calculados à mão e por
um modelo de referência independente (ver [Testes](#testes)).

---

## Arquitetura

### Pipeline

```
+------+     +------+     +------+     +------+     +------+
|  IF  | --> |  ID  | --> |  EX  | --> | MEM  | --> |  WB  |
+------+     +------+     +------+     +------+     +------+
  Busca      Decode       ALU          dmem/MMIO   Regfile
  instrução  Regs         Desvios      Loads com   Link (PC+4)
             Imediatos    Saltos       extensão
```

Registradores de pipeline `IF/ID`, `ID/EX`, `EX/MEM` e `MEM/WB` em `pl_pipe_pkg.sv`.

### Hazards

| Hazard | Solução | Onde |
|---|---|---|
| Dependência de dados (RAW) | Forwarding EX/MEM → EX e MEM/WB → EX, inclusive do valor de link (PC+4) de `JAL`/`JALR` | `pl_forward.sv`, `pl_datapath.sv` |
| Load seguido de uso | Stall de 1 ciclo. A unidade só considera `rs1`/`rs2` que a instrução realmente lê, conforme o opcode | `pl_hazard.sv` |
| Desvio tomado / salto | Resolvido em EX; o PC vai ao destino e IF e ID são esvaziados (2 ciclos de penalidade) | `pl_datapath.sv` |
| Leitura e escrita no mesmo registrador | Banco de registradores escreve na borda de descida, e o ID lê o valor novo no mesmo ciclo | `pl_regfile.sv` |

### Mapa de memória

| Endereço | Acesso | Descrição |
|---|---|---|
| `0x000 – 0x3FC` | R/W | Memória de dados, 256 × 32 bits, com acesso por byte, meia palavra e palavra |
| `0x400` | R | `SW[17:0]` — chaves |
| `0x404` | R | `KEY[3:0]` — botões |
| `0x408` | W | `LEDR[17:0]` — LEDs vermelhos |
| `0x40C` | W | `LEDG[8:0]` — LEDs verdes |
| `0x410` | R/W | UART RS-232, 9600 8N1. `sw` envia os 4 bytes da palavra; `lw` lê `{tx_busy[9], rx_ready[8], rx_data[7:0]}` |
| `0x414` | R | Contador de ciclos de clock |

O bit 10 do endereço seleciona o controlador de E/S (`pl_mmio.sv`).

### Top-level

| Arquivo | Clock da CPU | Uso |
|---|---|---|
| `pl_top.sv` | 10 MHz (PLL 50 → 10 MHz) | top-level usado nos testes |
| `pl_top_no_pll.sv` | 50 MHz (direto) | variante sem PLL; atende o timing a 50 MHz (Fmax ≈ 61 MHz no pior caso) |

Os dois passam a frequência real para a UART pelo parâmetro `CLK_HZ`, então a serial sai
a 9600 baud em qualquer um deles.

---

## Etapa 01 — R-type e I-type aritmético

### O que foi pedido

Implementar `XOR`, `SLL`, `SRL`, `SRA`, `SLTU` (R-type) e `ADDI`, `ANDI`, `ORI`, `SLTI`,
`SLLI`, `SRLI`, `SRAI` (I-type).

### Como foi feito

**R-type.**
- A ALU (`pl_alu.sv`) ganhou as operações XOR, SLL, SRL, SRA e SLTU.
- Os deslocamentos usam só os 5 bits baixos de `rs2`.
- SRA usa deslocamento aritmético (`>>>`), que preserva o sinal.
- SLTU compara sem sinal.
- O controle da ALU (`pl_alu_ctrl.sv`) passou a decodificar todos os `funct3`, usando `funct7` para separar `ADD`/`SUB` e `SRL`/`SRA`.

**I-type aritmético.**
- A unidade de controle (`pl_control.sv`) ganhou o opcode `0010011`, com o imediato como segundo operando da ALU e um novo código `ALUOp = 11`.
- `pl_sign_ext.sv` passou a gerar o imediato tipo I.
- No controle da ALU, o I-type é decodificado só por `funct3`. O bit 30 da instrução só é consultado para separar `SRLI` de `SRAI`, porque nas outras instruções ele faz parte do imediato. Isso evita que um `ADDI` com imediato negativo seja executado como subtração.

### Como foi testado

- `tests/etapa01/rtype.asm`: testa cada operação R-type com operandos positivos e negativos, cobrindo a diferença entre SRL e SRA e entre SLT e SLTU. Foi validado em simulação (ModelSim) contra `tests/etapa01/golden.txt`.
- Programa do professor com `ADDI`/`ANDI`/`ORI`/`SLTI`/`SLLI`/`SRLI`/`SRAI` seguido de operações R-type: executado na placa com dump serial.

---

## Etapa 02 — memória, desvios, saltos e U-type

### O que foi pedido

Loads `LB`, `LH`, `LBU`, `LHU`; stores `SB`, `SH`; desvios `BNE`, `BLT`, `BGE`, `BLTU`,
`BGEU`; saltos `JAL`, `JALR`; e `LUI`, `AUIPC`.

### Como foi feito

**Loads e stores por byte e meia palavra.** A memória de dados (`pl_dmem.sv`) recebe o
`funct3` da instrução e os 2 bits baixos do endereço:
- **Escrita:** gera um *byte enable* de 4 bits — `SB` habilita 1 byte, `SH` habilita 2 e `SW` habilita 4. O dado é deslocado para a posição do byte, e só os bytes habilitados são gravados, sem alterar os vizinhos.
- **Leitura:** a palavra é deslocada até o byte ou a meia palavra pedida e estendida. `LB`/`LH` estendem o sinal; `LBU`/`LHU` completam com zeros.

**Desvios.** A comparação é feita em EX, com os operandos já passados pelo forwarding,
de acordo com o `funct3`:
- `BEQ`/`BNE`: igualdade;
- `BLT`/`BGE`: comparação com sinal;
- `BLTU`/`BGEU`: comparação sem sinal.

**Saltos.**
- `JAL` desvia para `PC + imediato`.
- `JALR` desvia para `(rs1 + imediato)` com o bit 0 zerado, como exige a especificação.
- Os dois gravam `PC + 4` em `rd`. Esse valor de link percorre o pipeline e também pode ser repassado por forwarding a instruções seguintes.
- A unidade de hazard passou a considerar o `rs1` do `JALR`.

**U-type.** `LUI` coloca o imediato nos 20 bits altos. `AUIPC` soma o imediato ao PC da
própria instrução, usando o PC como primeiro operando da ALU.

### Como foi testado

| Teste | Cobre | Resultado |
|---|---|---|
| `tests/etapa02/I-B-J-Type.asm` | todas as instruções da etapa | placa ✅ (13/13 valores esperados) |
| `tests/etapa02/load_store.asm` | `LB` `LH` `LBU` `LHU` `SB` `SH` em detalhe | simulação ✅ |
| `tests/etapa02/branch_jump.asm` | `BNE` `BLT` `BGE` `BLTU` `BGEU` `JAL` `JALR` em detalhe | simulação ✅ |

Os dois testes detalhados e suas tabelas de valores esperados estão descritos em
[Testes](#testes).

---

## Validação na placa: dump serial

Para ver o resultado de um programa na placa, o assembler tem o modo `--dump`. Ele monta
o programa do usuário a partir do endereço `0x000` e acrescenta uma rotina em `0x080`
que, ao final do programa, faz o seguinte:

1. salva `x1`–`x8` na memória de dados;
2. envia pela UART o contador de ciclos, `x1`–`x8` e a memória `0x000`–`0x07C` — 41 palavras, 164 bytes;
3. acende todos os LEDs verdes e para.

No PC, `dump/serial_dump.py` recebe os 164 bytes e imprime a tabela de registradores e
memória (e salva em `dump.txt`).

**Regras para programas usados com `--dump`:**
- no máximo 127 instruções;
- os resultados que se quer ver precisam estar em `x1`–`x8` ou ser gravados em `0x000`–`0x07C`;
- não depender de valores iniciais no `data.mif` (ver abaixo); montar constantes com `addi`/`lui`;
- o `beq x0,x0,0` (halt) no fim é removido automaticamente.

---

## Problemas encontrados na placa e soluções

Os testes passavam na simulação, mas o dump na placa falhava. A investigação levantou
os problemas abaixo, cada um confirmado por evidência antes da correção.

| # | Sintoma na placa | Causa | Como foi confirmado | Solução |
|---|---|---|---|---|
| 1 | LEDs verdes apagados e nada chega na serial | A memória de dados é sintetizada como registradores (por causa da escrita por byte e da leitura assíncrona), e o Quartus **ignora o `data.mif`**: a memória liga zerada. A rotina de dump lia suas constantes (endereço da UART, máscara, valor dos LEDs) do `data.mif` e lia zeros. | Síntese no Quartus: sem `instruction.mif` dá erro, sem `data.mif` não aparece nenhuma mensagem; `pl_dmem` aparece com 8192 registradores e 0 bits de memória. A simulação com a memória zerada reproduz o sintoma. | As constantes do dump passaram a ser geradas com `addi` (o valor fica dentro da instrução). |
| 2 | Mesmo sintoma em programas terminados em `beq x0,x0,0` | O halt prende o processador antes do desvio para a rotina de dump. | Simulação com e sem a linha. | O `--dump` remove o halt final e avisa. |
| 3 | Serial ilegível a 9600 baud | A UART estava configurada para 50 MHz, mas com a PLL a CPU roda a 10 MHz: a serial saía a ~1920 baud. | Conta do divisor (5208 clocks/bit a 10 MHz) e o padrão dos bytes recebidos (só `0x00`/`0xF0`). | Parâmetro `CLK_HZ` passado do top-level até a UART: 9600 baud nas duas hierarquias. |
| 4 | Palavras "partidas" e deslocadas entre execuções | A rotina enviava 129 palavras, mas o script lê 41; o restante ficava no buffer do adaptador USB-serial e era lido na execução seguinte. A 1920 baud (fora do padrão), bytes também se perdiam. | Simulação contando bytes transmitidos (516 em vez de 164); comparação byte a byte do dump recebido. | A rotina envia exatamente 41 palavras; o script descarta o buffer ao abrir a porta. |
| 5 | `SRAI` com deslocamento de 16 a 31 executava como `SRLI` | O assembler codificava o deslocamento com 6 bits, empurrando o bit que diferencia SRAI/SRLI para fora do lugar. | `srai x1,x2,31` gerava `0x81F15093` em vez de `0x41F15093`. | Deslocamento codificado com 5 bits e validado (0–31). |

---

## Testes

Todos os testes estão em `tests/` e rodam com `assembler.py --dump` (exceto o da
etapa 01, que usa o testbench do ModelSim).

| Teste | Arquivo de valores esperados |
|---|---|
| R-type (etapa 01) | `tests/etapa01/golden.txt` |
| I-B-J (etapa 02) | `tests/etapa02/results.txt` |
| Loads e stores | [`tests/etapa02/load_store_esperado.md`](tests/etapa02/load_store_esperado.md) |
| Desvios e saltos | [`tests/etapa02/branch_jump_esperado.md`](tests/etapa02/branch_jump_esperado.md) |

**Testes detalhados de loads/stores e desvios/saltos.**
- Loads e stores:
  - leem todos os bytes e metades de uma palavra com bytes positivos e negativos (`0x80FF7F01`);
  - usam offsets negativos;
  - verificam que `SB`/`SH` não alteram os bytes vizinhos.
- Desvios e saltos:
  - testam cada desvio tomado, não tomado e com operandos iguais, usando `-1` e `1` para separar a comparação com sinal da sem sinal;
  - testam loop para trás, valores de link, chamada e retorno com `JALR`, e o bit 0 do destino do `JALR`.
- Os dois também exercitam forwarding e stall junto dessas instruções.

**Como os valores esperados foram validados:**
1. calculados por um modelo de referência RV32I em Python, escrito a partir da especificação e independente do hardware e do assembler;
2. conferidos na simulação RTL com a memória de dados zerada e com a memória cheia de valores inválidos (o reset pelo KEY0 não limpa a memória);
3. seis defeitos foram inseridos de propósito no hardware: LB sem extensão de sinal, LHU com extensão, SB ignorando o byte, BLTU comparando com sinal, BGE usando `>` e JALR sem zerar o bit 0. **Os seis foram detectados pelos testes.**

---

## Como reproduzir

### Simulação (ModelSim)

1. Copie `program.hex`, `data.hex` e `golden.txt` do teste para `modelsim/`.
2. Compile todos os arquivos de `src/`, começando por `pl_pipe_pkg.sv`.
3. Simule `pl_cpu_tb` com `run -all`. O testbench detecta o halt, imprime registradores e memória e compara com `golden.txt`.

### Placa (DE2-115)

```
cd assembler
python assembler.py --dump ../tests/etapa02/load_store.asm
```

1. Copie `assembler/instruction.mif` para a pasta do projeto Quartus.
2. Use `pl_top` como top-level, com os pinos de `quartus/add_to_qsf.txt` e o SDC `quartus/pl_top.sdc`.
3. Faça a **compilação completa**. A memória de instruções é implementada em lógica, então todo MIF novo exige compilação completa.
4. Grave a placa.
5. No PC, rode:
   ```
   python dump/serial_dump.py COM26
   ```
6. Aperte **KEY0** (reset). Os LEDs verdes acendem quando o dump termina.

### Formato aceito pelo assembler

Uma instrução por linha, sem rótulos e sem comentários. Imediatos em decimal, sem espaço
depois das vírgulas. Offsets de desvio e salto em bytes, relativos ao PC. `JALR` no
formato `jalr rd,rs1,imm`.

```
addi x1,x0,-107
lw   x2,4(x10)
bne  x1,x2,+8
jalr x18,x16,20
```

---

## Estrutura do repositório

```
src/                 SystemVerilog do processador
  pl_top.sv            top-level com PLL (10 MHz)
  pl_top_no_pll.sv     top-level sem PLL (50 MHz)
  pl_cpu.sv            controle + datapath
  pl_datapath.sv       pipeline de 5 estágios
  pl_control.sv        unidade de controle
  pl_alu.sv            ALU
  pl_alu_ctrl.sv       controle da ALU
  pl_sign_ext.sv       geração de imediatos (I, S, B, U, J)
  pl_hazard.sv         detecção de load-use
  pl_forward.sv        forwarding
  pl_regfile.sv        banco de registradores
  pl_imem.sv           memória de instruções
  pl_dmem.sv           memória de dados com acesso por byte/meia palavra
  pl_mmio.sv           E/S mapeada em memória (chaves, botões, LEDs, UART, ciclos)
  pl_uart.sv           UART 8N1
  pl_cpu_tb.sv         testbench
assembler/assembler.py montador (modo normal e --dump)
dump/serial_dump.py    recepção e formatação do dump serial
tests/etapa01/         teste R-type
tests/etapa02/         testes I-B-J, loads/stores, desvios/saltos
mifs/                  programas de exemplo do projeto-base
modelsim/              arquivos de simulação
quartus/               pinos (add_to_qsf.txt) e restrições de timing (*.sdc)
```
