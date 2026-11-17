# Teste desvios e saltos — BNE, BLT, BGE, BLTU, BGEU, JAL, JALR

Programa: [`branch_jump.asm`](branch_jump.asm) (101 instruções, não depende do `data.mif`).

## Como rodar

```
cd assembler
python assembler.py --dump ../tests/etapa02/branch_jump.asm
```

Copie `assembler/instruction.mif` para a pasta do projeto Quartus, compile, grave,
abra `python dump/serial_dump.py COMx` e aperte KEY0.

## Como ler o resultado

Operandos: `x1 = -1` (`0xFFFFFFFF`), `x2 = 1`, `x3 = 1`.
Com eles cada desvio é testado com e sem sinal, porque `-1 < 1` com sinal, mas
`0xFFFFFFFF > 1` sem sinal.

Cada caso grava uma flag na memória, e **1 significa que a instrução se comportou certo**:

```
desvio que DEVE ser tomado          desvio que NÃO deve ser tomado
addi x9,x0,1                        addi x9,x0,0
bne  x1,x2,+8                       bne  x2,x3,+8
addi x9,x0,0   <- pulada se tomou   addi x9,x0,1   <- executa se não tomou
sw   x9,...                         sw   x9,...
```

## Memória esperada

| Endereço | Esperado | Caso | Deve tomar? |
|---|---|---|---|
| `0x000` | `0x00000001` | `bne  x1,x2` (-1 ≠ 1) | sim |
| `0x004` | `0x00000001` | `bne  x2,x3` (1 = 1) | não |
| `0x008` | `0x00000001` | `blt  x1,x2` (-1 < 1) | sim |
| `0x00C` | `0x00000001` | `blt  x2,x1` (1 < -1?) | não |
| `0x010` | `0x00000001` | `blt  x2,x3` (iguais) | não |
| `0x014` | `0x00000001` | `bge  x2,x1` (1 ≥ -1) | sim |
| `0x018` | `0x00000001` | `bge  x2,x3` (iguais) | sim |
| `0x01C` | `0x00000001` | `bge  x1,x2` (-1 ≥ 1?) | não |
| `0x020` | `0x00000001` | `bltu x2,x1` (1 < 0xFFFFFFFF) | sim |
| `0x024` | `0x00000001` | `bltu x1,x2` (0xFFFFFFFF < 1?) | não |
| `0x028` | `0x00000001` | `bltu x2,x3` (iguais) | não |
| `0x02C` | `0x00000001` | `bgeu x1,x2` (0xFFFFFFFF ≥ 1) | sim |
| `0x030` | `0x00000001` | `bgeu x2,x3` (iguais) | sim |
| `0x034` | `0x00000001` | `bgeu x2,x1` (1 ≥ 0xFFFFFFFF?) | não |
| `0x038` | `0x00000005` | loop com `bne x5,x6,-4` (desvio para trás) | 4× sim, 1× não |
| `0x03C` | `0x00000001` | `bne` logo após o `addi` que gera o operando (forwarding) | não |
| `0x040` | `0x00000001` | `lw` + `blt` logo em seguida (load-use antes de desvio) | sim |
| `0x044` | `0x00000001` | `jal x0,+12` para frente, `jal x0,-8` para trás, `rd = x0` | — |
| `0x048` | `0x00000150` | link do `jal x7,+8` (PC 0x14C + 4) | — |
| `0x04C` | `0x0000000F` | chamada `jal x8` + retorno `jalr x0,x8,0` (5 na sub-rotina + 10 após voltar) | — |
| `0x050` | `0x00000188` | `jalr x14,x13,16` com x13 ímpar: destino `(0x179+16) & ~1 = 0x188` | — |
| `0x054` | `0x00000184` | link do `jalr` (PC 0x180 + 4) | — |
| `0x058`–`0x078` | `0x00000000` | — | — |
| `0x07C` | `0xFFFFFFFF` | rascunho: fonte do `lw` do caso `0x040` | — |

`0x048`, `0x050` e `0x054` são endereços absolutos. Eles mudam se o programa for editado.

## Registradores esperados

| x1 | x2 | x3 | x4 | x5 | x6 | x7 | x8 |
|---|---|---|---|---|---|---|---|
| `0xFFFFFFFF` | `0x00000001` | `0x00000001` | `0x00000000` | `0x00000005` | `0x00000005` | `0x00000150` | `0x00000160` |

`cycles = 160` (`0x0A0`) na simulação.

## Se algo vier errado

| Sintoma | Causa provável |
|---|---|
| flag 0 num caso "sim" | desvio não tomado quando deveria |
| flag 0 num caso "não" | desvio tomado quando não deveria |
| `0x020`/`0x024` ou `0x02C`/`0x034` com 0 | BLTU/BGEU comparando com sinal |
| só `0x018` ou `0x030` com 0 (iguais) | BGE/BGEU usando `>` em vez de `≥` |
| `0x038` diferente de 5 | desvio para trás (offset negativo) |
| só `0x03C` ou `0x040` com 0 | forwarding / stall antes do desvio |
| `0x044` diferente de 1 | `jal` para trás ou `jal` com `rd = x0` |
| `0x048`/`0x054` errados | valor de link (PC + 4) |
| `0x04C` diferente de 15 | retorno do `jalr` |
| `0x050` = `0x189` | JALR não zera o bit 0 do destino |

## Como os valores foram verificados

- Calculados por um modelo de referência RV32I em Python, que segue a especificação e não depende do hardware nem do assembler.
- Conferidos na simulação RTL com a dmem zerada e com a dmem cheia de `0xDEADBEEF`.
- Defeitos injetados de propósito no RTL foram todos detectados: BLTU comparando com sinal, BGE usando `>` e JALR sem zerar o bit 0.
