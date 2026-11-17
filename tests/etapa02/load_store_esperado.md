# Teste load/store — LB, LH, LBU, LHU, SB, SH

Programa: [`load_store.asm`](load_store.asm) (57 instruções, não depende do `data.mif`).

## Como rodar

```
cd assembler
python assembler.py --dump ../tests/etapa02/load_store.asm
```

Copie `assembler/instruction.mif` para a pasta do projeto Quartus, compile, grave,
abra `python dump/serial_dump.py COMx` e aperte KEY0.

## Palavra de teste

`W = 0x80FF7F01`, montada com `lui`/`addi` e gravada com `sw` em `0x040`.
Em little-endian os bytes ficam:

| Endereço | 0x040 | 0x041 | 0x042 | 0x043 |
|---|---|---|---|---|
| Byte | `0x01` | `0x7F` | `0xFF` | `0x80` |

Os quatro casos de sinal estão cobertos: positivo pequeno, maior positivo (`0x7F`),
`-1` (`0xFF`) e menor negativo (`0x80`).

## Memória esperada

| Endereço | Esperado | Instrução testada | O que verifica |
|---|---|---|---|
| `0x000` | `0x00000001` | `lb  x3,64(x0)` | byte 0, positivo |
| `0x004` | `0x0000007F` | `lb  x3,65(x0)` | maior byte positivo não estende sinal |
| `0x008` | `0xFFFFFFFF` | `lb  x3,66(x0)` | `0xFF` estende sinal → -1 |
| `0x00C` | `0xFFFFFF80` | `lb  x3,67(x0)` | `0x80` estende sinal → -128 |
| `0x010` | `0x000000FF` | `lbu x3,66(x0)` | LBU completa com zeros |
| `0x014` | `0x00000080` | `lbu x3,67(x0)` | LBU completa com zeros |
| `0x018` | `0x00007F01` | `lh  x3,64(x0)` | metade baixa, positiva |
| `0x01C` | `0xFFFF80FF` | `lh  x3,66(x0)` | metade alta `0x80FF` estende sinal |
| `0x020` | `0x00007F01` | `lhu x3,64(x0)` | metade baixa sem extensão |
| `0x024` | `0x000080FF` | `lhu x3,66(x0)` | LHU completa com zeros |
| `0x028` | `0xFFFFFF80` | `lb  x3,-1(x5)` (x5 = 0x044) | offset negativo; base vinda do `addi` anterior (forwarding) |
| `0x02C` | `0x000080FF` | `lhu x3,-2(x5)` | offset negativo em meia palavra |
| `0x030` | `0xFFFFFF00` | `lb x2,67(x0)` + `add x2,x2,x2` | load-use: o `add` logo após o `lb` precisa de stall |
| `0x034`–`0x03C` | `0x00000000` | — | não escritos |
| `0x040` | `0x80FF7F01` | `sw x1,64(x0)` | palavra W (fonte dos loads) |
| `0x044` | `0x34FF00FF` | palavra `0xFFFFFFFF`; `sb x0` em +1; `sb 0x234` em +3 | SB altera só o byte endereçado e grava só os 8 bits baixos |
| `0x048` | `0x5678FFFF` | palavra `0xFFFFFFFF`; `sh 0x12345678` em +2 | SH na metade alta, só os 16 bits baixos |
| `0x04C` | `0x0000FFFE` | palavra `0`; `sh -2` em +0 | SH na metade baixa |
| `0x050` | `0x80FF7F01` | 4× `sb` (`1`, `127`, `-1`, `-128`) | SB monta W byte a byte |
| `0x054` | `0x80FF7F01` | `sh x1` em +0, `sh (x1>>16)` em +2 | SH monta W por metades |
| `0x058` | `0x0000005A` | `addi x6,x0,90` + `sb` logo depois | forwarding do dado do store |
| `0x05C`–`0x07C` | `0x00000000` | — | não escritos |

## Registradores esperados

| x1 | x2 | x3 | x4 | x5 | x6 | x7 | x8 |
|---|---|---|---|---|---|---|---|
| `0x80FF7F01` | `0xFFFFFF00` | `0x000080FF` | `0xFFFFFFFF` | `0x00000044` | `0x0000005A` | `0x12345678` | `0xFFFFFFFE` |

`cycles = 92` (`0x5C`) na simulação.

## Se algo vier errado

| Sintoma | Causa provável |
|---|---|
| `0x008`, `0x00C` ou `0x01C` positivos | LB/LH não estendem o sinal |
| `0x010`, `0x014` ou `0x024` começando com `FFFF` | LBU/LHU estendendo o sinal |
| `0x044` diferente de `0x34FF00FF` | SB grava no byte errado ou apaga os vizinhos |
| `0x048`/`0x04C` errados | SH grava na metade errada |
| `0x050`/`0x054` diferentes de `0x040` | SB/SH não montam a palavra corretamente |
| só `0x030` errado | stall de load-use |
| só `0x058` errado | forwarding do dado do store |

## Como os valores foram verificados

- Calculados por um modelo de referência RV32I em Python, que segue a especificação e não depende do hardware nem do assembler.
- Conferidos na simulação RTL com a dmem zerada e com a dmem cheia de `0xDEADBEEF`, porque o KEY0 não limpa a dmem.
- Defeitos injetados de propósito no RTL foram todos detectados: LB sem extensão de sinal, LHU com extensão de sinal e SB ignorando o offset do byte.
