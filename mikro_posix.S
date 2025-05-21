# mikro_posix_os.S - micro sistema operativo POSIX-like in RISC-V compatibile con RARS

.data
# Messaggi di sistema
prompt:          .string "\nmikro_posix$ "
newline:         .string "\n"
welcome_msg:     .string "MikroPOSIX v1.0 - Un micro sistema operativo POSIX per RISC-V\nDigita 'help' per la lista dei comandi.\n"
help_msg:        .string "Comandi disponibili:\n  echo [messaggio]  - Mostra un messaggio\n  ls                - Lista file simulati\n  cat [nome_file]   - Mostra contenuto file\n  pwd              - Mostra directory corrente\n  mkdir [nome_dir]  - Crea directory (simulato)\n  touch [nome_file] - Crea file (simulato)\n  rm [nome_file]    - Rimuove file (simulato)\n  cp [src] [dst]    - Copia file (simulato)\n  ps               - Mostra processi attivi\n  sleep [secondi]   - Attende N secondi\n  help             - Mostra questo aiuto\n  exit             - Termina il sistema\n"
error_cmd:       .string "Errore: comando non riconosciuto\n"
error_arg:       .string "Errore: argomenti insufficienti\n"
success_msg:     .string "Operazione completata con successo\n"

# Comandi
echo_cmd:        .string "echo"
ls_cmd:          .string "ls"
cat_cmd:         .string "cat"
pwd_cmd:         .string "pwd"
mkdir_cmd:       .string "mkdir"
touch_cmd:       .string "touch"
rm_cmd:          .string "rm"
cp_cmd:          .string "cp"
ps_cmd:          .string "ps"
sleep_cmd:       .string "sleep"
help_cmd:        .string "help"
exit_cmd:        .string "exit"

# File system simulato
current_dir:     .string "/home/user"
fs_entries:      .string "/home/user\n/home/user/documents\n/home/user/downloads\n"
file_contents:   .string "readme.txt:Questo è un file di esempio nel filesystem simulato.\nhello.c:int main() {\n    printf(\"Hello, world!\");\n    return 0;\n}\n"
process_list:    .string "PID  CMD\n  1  init\n  2  mikro_posix\n"

# Buffer
input_buf:       .space 128         # Buffer input utente
arg_buf:         .space 64          # Buffer per gli argomenti
command_buf:     .space 32          # Buffer per il comando
arg1_buf:        .space 32          # Buffer per primo argomento
arg2_buf:        .space 32          # Buffer per secondo argomento
temp_buf:        .space 128         # Buffer temporaneo

.text
.globl main
main:
    # Mostra messaggio di benvenuto
    li a7, 4
    la a0, welcome_msg
    ecall

command_loop:
    # Mostra il prompt
    li a7, 4
    la a0, prompt
    ecall

    # Legge input da tastiera
    li a7, 8
    la a0, input_buf
    li a1, 128
    ecall

    # Analizza l'input (parsing)
    jal ra, parse_input

    # Gestione dei comandi
check_exit:
    la t0, command_buf
    la t1, exit_cmd
    jal ra, str_eq
    beq a0, zero, check_help
    li a7, 10       # syscall: exit
    ecall

check_help:
    la t0, command_buf
    la t1, help_cmd
    jal ra, str_eq
    beq a0, zero, check_echo
    li a7, 4
    la a0, help_msg
    ecall
    j command_loop

check_echo:
    la t0, command_buf
    la t1, echo_cmd
    jal ra, str_eq
    beq a0, zero, check_ls
    la a0, arg1_buf
    jal ra, echo_handler
    j command_loop

check_ls:
    la t0, command_buf
    la t1, ls_cmd
    jal ra, str_eq
    beq a0, zero, check_cat
    jal ra, ls_handler
    j command_loop

check_cat:
    la t0, command_buf
    la t1, cat_cmd
    jal ra, str_eq
    beq a0, zero, check_pwd
    la a0, arg1_buf
    jal ra, cat_handler
    j command_loop

check_pwd:
    la t0, command_buf
    la t1, pwd_cmd
    jal ra, str_eq
    beq a0, zero, check_mkdir
    jal ra, pwd_handler
    j command_loop

check_mkdir:
    la t0, command_buf
    la t1, mkdir_cmd
    jal ra, str_eq
    beq a0, zero, check_touch
    la a0, arg1_buf
    jal ra, mkdir_handler
    j command_loop

check_touch:
    la t0, command_buf
    la t1, touch_cmd
    jal ra, str_eq
    beq a0, zero, check_rm
    la a0, arg1_buf
    jal ra, touch_handler
    j command_loop

check_rm:
    la t0, command_buf
    la t1, rm_cmd
    jal ra, str_eq
    beq a0, zero, check_cp
    la a0, arg1_buf
    jal ra, rm_handler
    j command_loop

check_cp:
    la t0, command_buf
    la t1, cp_cmd
    jal ra, str_eq
    beq a0, zero, check_ps
    la a0, arg1_buf
    la a1, arg2_buf
    jal ra, cp_handler
    j command_loop

check_ps:
    la t0, command_buf
    la t1, ps_cmd
    jal ra, str_eq
    beq a0, zero, check_sleep
    jal ra, ps_handler
    j command_loop

check_sleep:
    la t0, command_buf
    la t1, sleep_cmd
    jal ra, str_eq
    beq a0, zero, unknown_command
    la a0, arg1_buf
    jal ra, sleep_handler
    j command_loop

unknown_command:
    # Controllo se il comando è vuoto
    la t0, command_buf
    lbu t1, 0(t0)
    beq t1, zero, command_loop  # Se vuoto, torna al loop

    # Comando non riconosciuto
    li a7, 4
    la a0, error_cmd
    ecall
    j command_loop

# ---------------------------
# Funzione: parse_input - Analizza l'input e lo divide in comando e argomenti
parse_input:
    addi sp, sp, -4
    sw ra, 0(sp)

    # Pulisci i buffer
    la t0, command_buf
    sb zero, 0(t0)
    la t0, arg1_buf
    sb zero, 0(t0)
    la t0, arg2_buf
    sb zero, 0(t0)

    # Puntatori ai buffer
    la t0, input_buf    # Input sorgente
    la t1, command_buf  # Destinazione comando
    
    # Salta gli spazi iniziali
skip_spaces_start:
    lbu t2, 0(t0)
    beq t2, zero, parse_done  # Se fine stringa, esci
    li t3, 32   # Spazio
    beq t2, t3, skip_space_continue
    li t3, 9    # Tab
    beq t2, t3, skip_space_continue
    li t3, 10   # Newline
    beq t2, t3, skip_space_continue
    j extract_command
skip_space_continue:
    addi t0, t0, 1
    j skip_spaces_start

    # Estrai il comando
extract_command:
    lbu t2, 0(t0)
    beq t2, zero, parse_done  # Se fine stringa, esci
    li t3, 32   # Spazio
    beq t2, t3, extract_arg1_prep
    li t3, 9    # Tab
    beq t2, t3, extract_arg1_prep
    li t3, 10   # Newline
    beq t2, t3, parse_done
    
    sb t2, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    j extract_command
    
extract_arg1_prep:
    sb zero, 0(t1)  # Termina la stringa del comando
    la t1, arg1_buf  # Reset del puntatore all'argomento 1
    
    # Salta gli spazi tra comando e arg1
skip_spaces_arg1:
    addi t0, t0, 1
    lbu t2, 0(t0)
    beq t2, zero, parse_done  # Se fine stringa, esci
    li t3, 32   # Spazio
    beq t2, t3, skip_spaces_arg1
    li t3, 9    # Tab
    beq t2, t3, skip_spaces_arg1
    li t3, 10   # Newline
    beq t2, t3, parse_done
    
    # Estrai il primo argomento
extract_arg1:
    lbu t2, 0(t0)
    beq t2, zero, parse_done  # Se fine stringa, esci
    li t3, 32   # Spazio
    beq t2, t3, extract_arg2_prep
    li t3, 9    # Tab
    beq t2, t3, extract_arg2_prep
    li t3, 10   # Newline
    beq t2, t3, parse_done
    
    sb t2, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    j extract_arg1
    
extract_arg2_prep:
    sb zero, 0(t1)  # Termina la stringa dell'arg1
    la t1, arg2_buf  # Reset del puntatore all'argomento 2
    
    # Salta gli spazi tra arg1 e arg2
skip_spaces_arg2:
    addi t0, t0, 1
    lbu t2, 0(t0)
    beq t2, zero, parse_done  # Se fine stringa, esci
    li t3, 32   # Spazio
    beq t2, t3, skip_spaces_arg2
    li t3, 9    # Tab
    beq t2, t3, skip_spaces_arg2
    li t3, 10   # Newline
    beq t2, t3, parse_done
    
    # Estrai il secondo argomento
extract_arg2:
    lbu t2, 0(t0)
    beq t2, zero, arg2_done  # Se fine stringa, termina
    li t3, 10   # Newline
    beq t2, t3, arg2_done
    
    sb t2, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    j extract_arg2
    
arg2_done:
    sb zero, 0(t1)  # Termina la stringa dell'arg2

parse_done:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# ---------------------------
# Handler per i comandi

# echo_handler - Stampa il testo passato come argomento
echo_handler:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # Verifica se c'è un argomento
    lbu t0, 0(a0)
    bne t0, zero, echo_show
    
    # Stampa solo newline se non ci sono argomenti
    li a7, 4
    la a0, newline
    ecall
    j echo_done
    
echo_show:
    # Stampa l'argomento
    li a7, 4
    ecall
    
    # Aggiungi newline
    li a7, 4
    la a0, newline
    ecall
    
echo_done:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# ls_handler - Mostra lista file simulata
ls_handler:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    li a7, 4
    la a0, fs_entries
    ecall
    
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# cat_handler - Mostra contenuto di un file
cat_handler:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # Verifica se c'è un argomento
    lbu t0, 0(a0)
    bne t0, zero, cat_show
    
    # Errore: file non specificato
    li a7, 4
    la a0, error_arg
    ecall
    j cat_done
    
cat_show:
    # Cerca il file nel database simulato (a0 contiene il nome del file)
    la t0, file_contents
    mv t1, a0  # Nome file da cercare
    
cat_search_loop:
    lbu t2, 0(t0)
    beq t2, zero, cat_file_not_found
    
    # Confronta il nome del file con l'inizio della riga corrente
    mv t3, t0  # Posizione corrente nel file_contents
    mv t4, t1  # Nome file da cercare
    
cat_name_cmp:
    lbu t5, 0(t4)
    beq t5, zero, cat_name_end  # Fine nome file
    lbu t6, 0(t3)
    beq t6, zero, cat_next_file  # Fine riga prima della fine del nome
    li t2, 58  # ':' (Usiamo t2 che non è usato qui)
    beq t6, t2, cat_file_found_partial  # Fine nome nel file_contents
    
    bne t5, t6, cat_next_file  # Caratteri diversi
    
    addi t3, t3, 1
    addi t4, t4, 1
    j cat_name_cmp
    
cat_name_end:
    # Verifica che il carattere successivo sia ':'
    lbu t5, 0(t3)
    li t2, 58  # ':' (Usiamo t2 che non è usato qui)
    bne t5, t2, cat_next_file
    
    # File trovato, salta al contenuto
    addi t0, t3, 1  # Salta il ':'
    j cat_display_content
    
cat_file_found_partial:
    lbu t5, 0(t4)
    bne t5, zero, cat_next_file  # Non è il file corretto
    
    # File trovato, salta al contenuto
    addi t0, t3, 1  # Salta il ':'
    j cat_display_content
    
cat_next_file:
    # Vai alla prossima riga
cat_find_nextline:
    lbu t2, 0(t0)
    beq t2, zero, cat_file_not_found
    li t3, 10  # Newline
    beq t2, t3, cat_found_nextline
    addi t0, t0, 1
    j cat_find_nextline
    
cat_found_nextline:
    addi t0, t0, 1  # Salta il newline
    j cat_search_loop
    
cat_file_not_found:
    # File non trovato
    la a0, temp_buf
    la t0, arg1_buf
    
    # Copia il nome del file
cat_err_copy:
    lbu t1, 0(t0)
    sb t1, 0(a0)
    beq t1, zero, cat_err_append
    addi t0, t0, 1
    addi a0, a0, 1
    j cat_err_copy
    
cat_err_append:
    # Aggiungi il messaggio di errore
    la t0, temp_buf
    
    # Aggiungiamo manualmente il messaggio di errore
    # "File non trovato\n"
    li t1, 'F'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 'i'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 'l'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 'e'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, ' '
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 'n'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 'o'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 'n'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, ' '
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 't'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 'r'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 'o'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 'v'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 'a'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 't'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 'o'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, '\n'
    sb t1, 0(a0)
    addi a0, a0, 1
    li t1, 0
    sb t1, 0(a0)
    
    li a7, 4
    la a0, temp_buf
    ecall
    j cat_done
    
cat_display_content:
    # Copia il contenuto nel buffer temporaneo fino al prossimo file
    la t1, temp_buf
    
cat_copy_loop:
    lbu t2, 0(t0)
    beq t2, zero, cat_end_copy
    li t3, 10  # Newline
    beq t2, t3, cat_check_end
    
    # Normale copia
cat_normal_copy:
    sb t2, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    j cat_copy_loop
    
cat_check_end:
    # Copia il newline
    sb t2, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    
    # Controlla se il prossimo carattere è l'inizio di un nuovo file
    lbu t2, 0(t0)
    beq t2, zero, cat_end_copy
    
    # Cerca se c'è un ':' prima del prossimo newline
    mv t3, t0
cat_scan_ahead:
    lbu t4, 0(t3)
    beq t4, zero, cat_normal_copy_resume
    li t5, 10  # Newline
    beq t4, t5, cat_normal_copy_resume
    li t6, 58  # ':'
    beq t4, t6, cat_end_copy
    addi t3, t3, 1
    j cat_scan_ahead
    
cat_normal_copy_resume:
    j cat_copy_loop
    
cat_end_copy:
    sb zero, 0(t1)  # Termina la stringa
    
    # Mostra il contenuto
    li a7, 4
    la a0, temp_buf
    ecall
    
cat_done:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# pwd_handler - Mostra directory corrente
pwd_handler:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    li a7, 4
    la a0, current_dir
    ecall
    
    li a7, 4
    la a0, newline
    ecall
    
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# mkdir_handler - Simula creazione directory
mkdir_handler:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # Verifica se c'è un argomento
    lbu t0, 0(a0)
    bne t0, zero, mkdir_show
    
    # Errore: directory non specificata
    li a7, 4
    la a0, error_arg
    ecall
    j mkdir_done
    
mkdir_show:
    # Conferma l'operazione (nel sistema reale creerebbe la directory)
    li a7, 4
    la a0, success_msg
    ecall
    
mkdir_done:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# touch_handler - Simula creazione file
touch_handler:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # Verifica se c'è un argomento
    lbu t0, 0(a0)
    bne t0, zero, touch_show
    
    # Errore: file non specificato
    li a7, 4
    la a0, error_arg
    ecall
    j touch_done
    
touch_show:
    # Conferma l'operazione (nel sistema reale creerebbe il file)
    li a7, 4
    la a0, success_msg
    ecall
    
touch_done:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# rm_handler - Simula rimozione file
rm_handler:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # Verifica se c'è un argomento
    lbu t0, 0(a0)
    bne t0, zero, rm_show
    
    # Errore: file non specificato
    li a7, 4
    la a0, error_arg
    ecall
    j rm_done
    
rm_show:
    # Conferma l'operazione (nel sistema reale rimuoverebbe il file)
    li a7, 4
    la a0, success_msg
    ecall
    
rm_done:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# cp_handler - Simula copia file
cp_handler:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # Verifica se ci sono entrambi gli argomenti
    lbu t0, 0(a0)
    beq t0, zero, cp_arg_error
    lbu t0, 0(a1)
    beq t0, zero, cp_arg_error
    j cp_show
    
cp_arg_error:
    # Errore: argomenti insufficienti
    li a7, 4
    la a0, error_arg
    ecall
    j cp_done
    
cp_show:
    # Conferma l'operazione (nel sistema reale copierebbe il file)
    li a7, 4
    la a0, success_msg
    ecall
    
cp_done:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# ps_handler - Mostra processi attivi simulati
ps_handler:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    li a7, 4
    la a0, process_list
    ecall
    
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# sleep_handler - Pausa l'esecuzione per un numero di secondi
sleep_handler:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # Verifica se c'è un argomento
    lbu t0, 0(a0)
    bne t0, zero, sleep_start
    
    # Nessun argomento, usa 1 secondo di default
    li a0, 1
    j sleep_convert_done
    
sleep_start:
    # Converti la stringa in numero
    li a0, 0  # Risultato
    mv t0, a0  # Puntatore alla stringa
    
sleep_convert:
    lbu t1, 0(t0)
    beq t1, zero, sleep_convert_done
    li t2, '0'
    sub t1, t1, t2  # Converti ASCII in numero
    li t2, 10
    mul a0, a0, t2  # Moltiplica risultato per 10
    add a0, a0, t1  # Aggiungi cifra
    addi t0, t0, 1
    j sleep_convert
    
sleep_convert_done:
    # Limita a max 10 secondi per sicurezza
    li t0, 10
    blt a0, t0, sleep_continue
    li a0, 10
    
sleep_continue:
    # Conversione in millisecondi
    li t0, 1000
    mul a0, a0, t0
    
    # Syscall sleep (milliseconds)
    li a7, 32
    ecall
    
sleep_done:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# ---------------------------
# Utility di manipolazione stringhe

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

# str_len: calcola la lunghezza di una stringa
# IN: a0 = str
# OUT: a0 = lunghezza
str_len:
    mv t0, a0
    li a0, 0
str_len_loop:
    lbu t1, 0(t0)
    beq t1, zero, str_len_done
    addi a0, a0, 1
    addi t0, t0, 1
    j str_len_loop
str_len_done:
    ret

# str_copy: copia una stringa
# IN: a0 = dest, a1 = src
# OUT: nessuno
str_copy:
    mv t0, a0
    mv t1, a1
str_copy_loop:
    lbu t2, 0(t1)
    sb t2, 0(t0)
    beq t2, zero, str_copy_done
    addi t0, t0, 1
    addi t1, t1, 1
    j str_copy_loop
str_copy_done:
    ret