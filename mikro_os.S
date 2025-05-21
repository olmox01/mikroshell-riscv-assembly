# mikro_os.S - micro sistema operativo in RISC-V compatibile con RARS

.data
prompt:        .string "\n> "
newline:       .string "\n"

echo_cmd:      .string "echo"
halt_cmd:      .string "halt"

input_buf:     .space 128         # Buffer input utente
echo_msg_buf:  .space 123         # Buffer per messaggio echo

.text
.globl main
main:
loop:
    # Mostra il prompt
    li a7, 4
    la a0, prompt
    ecall

    # Legge input da tastiera
    li a7, 8
    la a0, input_buf
    li a1, 128
    ecall

    # Controlla se è halt
    la t0, input_buf
    la t1, halt_cmd
    jal ra, str_eq
    beq a0, x0, check_echo
    li a7, 10       # syscall: exit
    ecall

check_echo:
    la t0, input_buf
    la t1, echo_cmd
    jal ra, str_start_with
    beq a0, x0, loop  # Se non inizia con echo, ignora

    # Copia da input_buf+5 in echo_msg_buf
    la t2, input_buf
    addi t2, t2, 5       # salta "echo "

    la t3, echo_msg_buf  # destinazione
    li t5, 10            # newline
copy_loop:
    lbu t4, 0(t2)
    beq t4, t5, end_copy
    beq t4, x0, end_copy
    sb t4, 0(t3)
    addi t2, t2, 1
    addi t3, t3, 1
    j copy_loop
end_copy:
    li t4, 0
    sb t4, 0(t3)             # aggiunge terminatore null

    # Stampa echo_msg_buf
    li a7, 4
    la a0, echo_msg_buf
    ecall

    # Aggiunge newline
    li a7, 4
    la a0, newline
    ecall

    j loop

# ---------------------------
# str_eq: confronta due stringhe
# IN: t0 = str1, t1 = str2
# OUT: a0 = 1 se uguali, 0 altrimenti
str_eq:
    li a0, 1
str_eq_loop:
    lbu t2, 0(t0)
    lbu t3, 0(t1)
    bne t2, t3, str_eq_not_equal
    beq t2, x0, str_eq_done
    addi t0, t0, 1
    addi t1, t1, 1
    j str_eq_loop
str_eq_not_equal:
    li a0, 0
str_eq_done:
    ret

# ---------------------------
# str_start_with: verifica se str1 inizia con str2
# IN: t0 = str1, t1 = prefix
# OUT: a0 = 1 se str1 inizia con str2, 0 altrimenti
str_start_with:
    li a0, 1
str_sw_loop:
    lbu t2, 0(t1)
    beq t2, x0, str_sw_done
    lbu t3, 0(t0)
    bne t2, t3, str_sw_fail
    addi t0, t0, 1
    addi t1, t1, 1
    j str_sw_loop
str_sw_fail:
    li a0, 0
str_sw_done:
    ret

