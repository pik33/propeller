{{

┌──────────────────────────────────────────┐
│ morse_code_demo_SOS                      │
│ Author: Tósaki Tamás                     │              
└──────────────────────────────────────────┘

SOS - > S:--- ( 3 * Dot / 3* Hosszú )  O:*** ( 3 * Dash / 3 * Rövid ) S:--- ( 3 * Dot / 3 * Hosszú )

}}

OBJ
  MORSE : "morse_code"

PUB Start
    MORSE.start_up(10)                                       ' On 10 pin / 10-es lábon
    MORSE.help                                               ' SOS