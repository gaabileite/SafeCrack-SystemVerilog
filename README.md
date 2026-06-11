# SafeCrack-SystemVerilog
The following project was a work done individually for @Victor Medeiros' class at my first semester of graduating Information Systems at CIn - UFPE. The whole project is written in SystemVerilog and I'll add my State Diagram along for better understanding.

<img width="1155" height="756" alt="image" src="https://github.com/user-attachments/assets/b7fb88e1-0267-42b6-a465-0fd439e3acae" />

# SafeCrack Pro 🔐

A digital safe implemented on the Intel/Altera **DE2-115** FPGA board, where the
password is entered digit-by-digit using push buttons and displayed on 7-segment
displays. Final project for **CIN0130 – Digital Systems** (CIn/UFPE, 2026.1).

## How it works

The password consists of **4 digits (0–9)**, shown on displays HEX3–HEX0
(HEX3 = first digit). The user composes the password one digit at a time,
navigating values with the board's push buttons:

| Button | Action |
|--------|--------|
| `KEY[3]` | Decrement the active digit (wraps 0 → 9) |
| `KEY[2]` | Increment the active digit (wraps 9 → 0) |
| `KEY[1]` | Confirm digit and move to the next; on the 4th digit, triggers password verification |
| `KEY[0]` | Reset to initial state (first digit active, displays at 0, LEDs off) |

Navigation is **forward-only** — confirmed digits can't be edited; restarting
requires a reset. The active digit is indicated by lighting its display's
decimal point (DP). Each button press registers as a **single edge-triggered
event**, so holding a button doesn't repeat the action.

## Verification & feedback

- ✅ **Correct password:** all green LEDs light up for **5 seconds** (safe opened)
- ❌ **Wrong password:** red LED(s) light up for **3 seconds**

In both cases, the system automatically returns to the initial state for a new attempt.

## Tech

- FSM written in **SystemVerilog**
- Simulated in **Quartus** (waveform analysis)
- Deployed and demonstrated on the **DE2-115** board
