# 8086 Microprocessor-Based Keypad Authentication System with LED Display & Buzzer

This project implements a **simple authentication and LED pattern display system using an 8086 microprocessor**, interfaced with a 4x3 keypad, LEDs, and a buzzer. The system authenticates a user-entered password and, upon success, allows selection of LED display patterns.

``` mathematica
Start → Init 8255 → Enter PIN → [Correct?]
                                    │
                      ┌──── No ─────┐  ──── yes ─────┐
                      ▼             ▼                ▼
                  Buzzer ON       Retry            Pattern
                                  Auth             Choice 
                                                      ▼
                                                 Keypad Input → Run Pattern → Loop
```

### Main Hardware Components 

+ **8086 Microprocessor [U1]**: Core CPU controlling the system flow.
+ **8255 Programmable Peripheral Interface (PPI) [U8]**: Used to interface with keypad, LEDs and buzzer.
+ **74LS373 Octal Transparent Latch [U2, U3, U4]**: To isolate the address bits permanently for decoding or interfacing.
  + LE (Latch Enable): Connected to ALE from 8086
  + OE (Output Enable): Grounded
+ **74LS138 3-to-8 Line Decoder [U7]**: To decode address lines and generate chip select (CS) signals for the 8255 PPI (U8).

  Port selection happens with A1 and A2 with PortA starting address calculated by bitmasking the last 2 digits of the university ID:
  
  ```
  0100 1001 & 1111 1000 = 0100 1000 (48H) 
  ```
  Resulting in the port addresses (48H, 4AH, 4CH, 4EH). The remaining bits are used for the chip select.
    + Inputs A, B and C receive address lines A3, A4 and A6, enabling 8255 on `101`
    + Inputs E2 and E3 receive address lines A5 and A7
+ **74LS245 Octal Bus Transceiver [U5, U6]**: To buffer or isolate data buses from peripherals for timing or voltage protection.
  + U5 connects the lower data bus (D0–D7)
  + U6 connects the upper data bus (D8–D15)
 
<p align = center>
  <img src="https://github.com/user-attachments/assets/281b5445-404d-458a-ba61-e10f92a500b3" width = 100%>
</p>

### Software Components 
Written for 8086 architecture with password authentication (8-6-4-9) and four different LED patterns (Left to Right, Alternating, Counting, Ping-Pong) and buzzer feedback for incorrect password attempts. Data segment initialization is as follows:

``` assembly
DATA SEGMENT
    portA     EQU 48H     ; LEDs (PA0-PA7)
    portB     EQU 4AH     ; Keypad rows (PB0-PB3)
    portC     EQU 4CH     ; Keypad cols (PC0-PC3) + Buzzer (PC7)
    CWR       EQU 4EH     ; 8255 Control Register

    pswd      DB 8,6,4,9
    buzzer    DB 0        ; 00h = off, 80h = on
    buffer    DB 4 DUP (0)
DATA ENDS
```

The assembly source code includes explicit routines for initialization, keypad scanning, authentication and LED patterns. 

#### Pattern 1: Left to Right Shift
```
AL = 00000001b → 00000010b → ... → 10000000b
```
#### Pattern 2: Alternating Blink
```
AL = 01010101b → 10101010b → repeat 8 times
```
#### Pattern 3: Binary Counter
```
AL = 00000000b to 11111111b (0 to 255)
```
#### Pattern 6: Ping-Pong
```
AL = 00000001b → shift left to 10000000b → then shift back to 00000001b → repeat
```

This project includes a software-controlled buzzer for safe I/O handling, a modular 8086 assembly design with distinct processes for every LED pattern, and appropriate stack usage to maintain register state. After successful authentication, it continuously loops a few chosen LED patterns and features dependable keypad input with software debounce.
