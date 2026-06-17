# SafeCrack--SystemVerilog

# SafeCrack Pro — Cofre com seleção de dígitos por push buttons

**CIN0130 — Sistemas Digitais** · Professor: Victor Medeiros · Semestre 2026.1

Implementação em SystemVerilog de um cofre digital para a placa **DE2-115**. A senha de quatro dígitos (0–9) é composta um dígito por vez, navegando os valores com os push buttons e confirmando dígito a dígito. Ao final, o sistema compara a senha inserida com a senha correta e sinaliza o resultado pelos LEDs.

---

## Sumário

- [Visão geral](#visão-geral)
- [Como os requisitos foram implementados](#como-os-requisitos-foram-implementados)
- [Arquitetura do código](#arquitetura-do-código)
- [Diagrama de estados](#diagrama-de-estados)
- [Mapeamento de pinos (DE2-115)](#mapeamento-de-pinos-de2-115)
- [Simulação e waveforms](#simulação-e-waveforms)
- [Como compilar e gravar na placa](#como-compilar-e-gravar-na-placa)
- [Known issues](#known-issues)

---

## Visão geral

O sistema mantém quatro registradores de 4 bits (`register3`–`register0`), um para cada dígito da senha. Os dígitos são exibidos simultaneamente nos displays de 7 segmentos **HEX3–HEX0**, e o display **HEX4** indica qual dígito está sendo editado no momento (o dígito ativo).

A interação acontece pelos quatro push buttons da placa (`KEY[3:0]`, ativos em nível baixo):

| Botão | Porta no código | Função |
|-------|-----------------|--------|
| `KEY[3]` | `btn_dec` | Seta para a esquerda — decrementa o dígito ativo |
| `KEY[2]` | `btn_inc` | Seta para a direita — incrementa o dígito ativo |
| `KEY[1]` | `key_conf` | Confirma o dígito atual e avança para o próximo |
| `KEY[0]` | `rst` | Reset — volta ao estado inicial |

A senha correta é definida por parâmetros (`pass0`–`pass3`) e está configurada como **2 - 7 - 3 - 9**.

---

## Como os requisitos foram implementados

### Composição da senha dígito a dígito

A FSM percorre os estados `A → B → C → D`, um para cada dígito. Em cada estado, os botões de incremento/decremento alteram apenas o registrador daquele dígito:

- Estado `A` edita `register3` (primeiro dígito, exibido em HEX3)
- Estado `B` edita `register2` (HEX2)
- Estado `C` edita `register1` (HEX1)
- Estado `D` edita `register0` (último dígito, HEX0)

A confirmação (`key_conf`) avança para o próximo estado e incrementa o contador `position`, que indica o dígito ativo. A navegação é sempre para frente — não há retorno a um dígito já confirmado, conforme a especificação. Para recomeçar, usa-se o reset.

### Incremento, decremento e wrap-around

Cada botão de seta leva a um estado auxiliar de edição (`A_INC`, `A_DEC`, `B_INC`, …). Esses estados duram um único ciclo de clock, alteram o registrador correspondente e retornam imediatamente ao estado pai. O wrap-around é tratado explicitamente: ao incrementar a partir do 9, o valor volta a 0; ao decrementar a partir do 0, vai para 9.

```systemverilog
A_INC: begin
   if      (register3 < 4'b1001)  next_register3 = register3 + 1'b1;
   else if (register3 == 4'b1001) next_register3 = 4'b0000;  // 9 -> 0
end
```

### Uma ação por pressionamento (detecção de borda)

Para que manter o botão pressionado não gere múltiplas ações, cada botão tem um detector de borda de subida. O sinal é primeiro invertido (os `KEY` são ativos em nível baixo) e comparado com seu valor no ciclo anterior:

```systemverilog
btn_inc_pos  = ~btn_inc;                       // ativo em nível alto
btn_inc_edge = btn_inc_pos & ~btn_inc_prev;    // detecta a transição 0 -> 1
```

A FSM só reage quando `*_edge` está em 1, ou seja, somente no instante do pressionamento.

### Indicação do dígito ativo (HEX4)

O contador `position` (2 bits) é decodificado no display HEX4 para mostrar o índice do dígito em edição, fornecendo feedback visual claro de qual dígito está selecionado.

### Verificação e feedback pelos LEDs

Após a confirmação do quarto dígito, o estado `CHECK` compara os quatro registradores com a senha parametrizada:

- **Senha correta** → estado `CORRECT` → todos os LEDs verdes acesos por 5 segundos.
- **Senha incorreta** → estado `WRONG` → LEDs vermelhos acesos por 3 segundos.

A contagem de tempo usa o contador `delay_cnt`, dimensionado para `5 × ONE_SECOND` ticks (250 milhões de ciclos a 50 MHz). Um flag `was_correct` guarda o resultado da verificação para que os LEDs permaneçam acesos durante todo o estado `WAIT`. Ao fim do tempo, o sistema retorna automaticamente ao estado inicial.

### Reset

O reset é **assíncrono e ativo em nível baixo**, coerente com os `KEY` da DE2-115. Pressionar `KEY[0]` (nível 0) leva a FSM de volta ao estado `A`, zera todos os registradores e o `position`, e apaga os LEDs, independentemente do estado atual:

```systemverilog
always_ff @(posedge clk or negedge rst) begin
   if (!rst) begin
      state <= A;
      // ... zera registradores, position, was_correct
   end else begin
      // ... lógica normal
   end
end
```

---

## Arquitetura do código

| Arquivo | Descrição |
|---------|-----------|
| `safecrackpro_top.sv` | Módulo top-level. Conecta as entradas/saídas físicas, instancia a FSM e os decodificadores de 7 segmentos. |
| `safecrack.sv` | A FSM principal: lógica de estados, edição dos dígitos, verificação da senha e controle dos LEDs. |
| `bcd_to_7segment_anodo.sv` | Decodificador de BCD (0–9) para 7 segmentos, ânodo comum (ativo em nível baixo). |

O `ONE_SECOND` é um **parâmetro** do módulo `safecrack`, com valor padrão `50_000_000` (1 segundo a 50 MHz). Isso permite reduzi-lo na simulação para acelerar os testes, sem alterar o comportamento na placa.

---

## Diagrama de estados

> O reset (`KEY[0]`) é assíncrono e leva **qualquer** estado de volta a `A`. As setas de reset foram omitidas do diagrama para legibilidade.
> Vale notar que o estado WAIT foi adicionado mais tarde, por motivos de eficiência do projeto. Este diagrama é o primeiro que foi feito durante as aulas.
<img width="1147" height="740" alt="image" src="https://github.com/user-attachments/assets/aa8b43a0-6a1a-4b2f-88b2-58997d26d804" />

---

## Mapeamento de pinos (DE2-115)

Entradas principais:

| Porta | Sinal na placa | Pino |
|-------|----------------|------|
| `clk` | CLOCK_50 | `PIN_Y2` |
| `rst` | KEY[0] | `PIN_M23` |
| `key_conf` | KEY[1] | `PIN_M21` |
| `btn_dec` | KEY[2] | `PIN_N21` |
| `btn_inc` | KEY[3] | `PIN_R24` |

Saídas (correspondência lógica — atribua aos pinos do `.qsf` padrão da DE2-115):

| Porta | Sinal na placa |
|-------|----------------|
| `seg_pos4` | HEX3 (primeiro dígito) |
| `seg_pos3` | HEX2 |
| `seg_pos2` | HEX1 |
| `seg_pos1` | HEX0 (último dígito) |
| `seg_cur_pos` | HEX4 (dígito ativo) |
| `led_red` | LEDR[17:0] |
| `led_green` | LEDG[8:0] |

---

## Simulação e waveforms

A simulação foi feita com o testbench `safecrack_tb.sv`, que estimula a FSM em dois cenários: uma tentativa com **senha incorreta** (LED vermelho) e uma com **senha correta** 2-7-3-9 (LED verde), incluindo um wrap-around (0 → 9) para demonstrar essa funcionalidade. O `ONE_SECOND` é reduzido para 5 no testbench, tornando o tempo de espera observável na simulação.

<img width="1843" height="284" alt="image" src="https://github.com/user-attachments/assets/2b122b17-8163-453d-89e0-ad93b2a580b0" />

### Como reproduzir a simulação

A simulação pode ser feita online no [EDA Playground](https://edaplayground.com), sem instalação:

1. Cole `safecrack.sv` no painel **design.sv** e `safecrack_tb.sv` no painel **testbench.sv**.
2. Em *Tools & Simulators*, escolha um simulador SystemVerilog (ex.: Aldec Riviera-PRO).
3. Marque **Open EPWave after run** e clique em **Run**.
4. Na janela EPWave, adicione os sinais `state`, `position`, `register3`–`register0`, `led_green`, `led_red` e os botões.

---

## Known issues

- **Sincronização dos botões:** as entradas dos push buttons são amostradas diretamente, sem um sincronizador de dois flip-flops. Na prática, os `KEY` da DE2-115 já possuem tratamento de bounce em hardware, então o sistema funciona de forma estável; ainda assim, do ponto de vista de boas práticas, existe um risco teórico de metaestabilidade que um sincronizador eliminaria.
- **Índice do dígito ativo em base 1:** o display HEX4 exibe o índice do dígito em uma faixa de 1 a 4 (via `position + 1` no top-level). Caso o esperado seja a faixa 0 a 3, basta remover o incremento na instanciação do decodificador.
- **Sem navegação para trás:** não é possível voltar a um dígito já confirmado — isso é intencional e está de acordo com a especificação (a correção só é possível via reset).
