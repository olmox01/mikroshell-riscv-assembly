# Costanti per il file system
.eqv ENTRY_SIZE 161  # Dimensione di una voce: 1 (tipo) + 32 (nome) + 128 (contenuto)  
.eqv TYPE_OFFSET 0   # Offset del tipo nella voce
.eqv NAME_OFFSET 1   # Offset del nome nella voce
.eqv CONTENT_OFFSET 33 # Offset del contenuto nella voce
.eqv NUM_ENTRIES 10  # Numero massimo di voci nel file system

.data
# Messaggi di sistema
prompt: .string "\nmikro_posix$ "
newline: .string "\n"
welcome_msg: .string "MikroPOSIX v1.0 - Un micro sistema operativo POSIX per RISC-V\nDigita 'help' per la lista dei comandi.\n"
help_msg: .string "Comandi disponibili:\n echo [messaggio] - Mostra un messaggio\n ls - Lista file simulati\n cat [nome_file] - Mostra contenuto file\n pwd - Mostra directory corrente\n mkdir [nome_dir] - Crea directory\n touch [nome_file] - Crea file\n rm [nome_file] - Rimuove file o directory\n cp [src] [dst] - Copia file\n ps - Mostra processi attivi\n sleep [secondi] - Attende N secondi (default 1 se omesso)\n help - Mostra questo aiuto\n exit - Termina il sistema\n"
error_cmd: .string "Errore: comando non riconosciuto\n"
error_arg: .string "Errore: argomenti insufficienti o non validi\n"
error_fs_full: .string "Errore: file system pieno\n"
error_file_not_found: .string "Errore: file non trovato\n"
error_dir_not_found: .string "Errore: directory non trovata\n"
error_not_a_file: .string "Errore: non è un file\n"
error_not_a_dir: .string "Errore: non è una directory\n"
error_dir_not_empty: .string "Errore: directory non vuota\n"
error_invalid_arg: .string "Errore: argomento non valido\n"

# Comandi
echo_cmd: .string "echo"
ls_cmd: .string "ls"
cat_cmd: .string "cat"
pwd_cmd: .string "pwd"
mkdir_cmd: .string "mkdir"
touch_cmd: .string "touch"
rm_cmd: .string "rm"
cp_cmd: .string "cp"
ps_cmd: .string "ps"
sleep_cmd: .string "sleep"
help_cmd: .string "help"
exit_cmd: .string "exit"

# File system dinamico
fs_array: .space 1610  # NUM_ENTRIES * ENTRY_SIZE
current_dir: .string "/"
root_dir_name: .string "/"
slash_str: .string "/"
empty_string: .string ""

# Buffer
input_buf: .space 256
arg_buf: .space 128
command_buf: .space 64
arg1_buf: .space 64
arg2_buf: .space 64
temp_buf: .space 256

# Dati per init_fs
home_dir_name: .string "/home"
user_dir_name: .string "/home/user"
readme_file_name: .string "/home/user/readme.txt"
readme_content: .string "Questo è un file di esempio nel filesystem simulato."
hello_file_name: .string "/home/user/hello.c"
hello_content: .string "int main() {\n printf(\"Hello, world!\");\n return 0;\n}"
process_list: .string "PID CMD\n 1 init\n 2 mikro_posix\n"

.text
.globl main
main:
# Salva i registri
addi sp, sp, -4
sw ra, 0(sp)

# Inizializza il file system
jal ra, init_fs

# Mostra messaggio di benvenuto
li a7, 4
la a0, welcome_msg
ecall

command_loop:
# Salva i registri prima di ogni iterazione
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

# Mostra il prompt
li a7, 4
la a0, prompt
ecall

# Legge input da tastiera
li a7, 8
la a0, input_buf
li a1, 256
ecall

# Analizza l'input (parsing)
jal ra, parse_input

# Gestione dei comandi
check_exit:
la t0, command_buf
la t1, exit_cmd
jal ra, str_eq
beq a0, zero, check_help
# Ripristina registri e termina
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
lw ra, 0(sp)
addi sp, sp, 4
li a7, 10 # syscall: exit
ecall

check_help:
la t0, command_buf
la t1, help_cmd
jal ra, str_eq
beq a0, zero, check_echo
li a7, 4
la a0, help_msg
ecall
j end_loop

check_echo:
la t0, command_buf
la t1, echo_cmd
jal ra, str_eq
beq a0, zero, check_ls
la a0, arg1_buf
jal ra, echo_handler
j end_loop

check_ls:
la t0, command_buf
la t1, ls_cmd
jal ra, str_eq
beq a0, zero, check_cat
jal ra, ls_handler
j end_loop

check_cat:
la t0, command_buf
la t1, cat_cmd
jal ra, str_eq
beq a0, zero, check_pwd
la a0, arg1_buf
jal ra, cat_handler
j end_loop

check_pwd:
la t0, command_buf
la t1, pwd_cmd
jal ra, str_eq
beq a0, zero, check_mkdir
jal ra, pwd_handler
j end_loop

check_mkdir:
la t0, command_buf
la t1, mkdir_cmd
jal ra, str_eq
beq a0, zero, check_touch
la a0, arg1_buf
jal ra, mkdir_handler
j end_loop

check_touch:
la t0, command_buf
la t1, touch_cmd
jal ra, str_eq
beq a0, zero, check_rm
la a0, arg1_buf
jal ra, touch_handler
j end_loop

check_rm:
la t0, command_buf
la t1, rm_cmd
jal ra, str_eq
beq a0, zero, check_cp
la a0, arg1_buf
jal ra, rm_handler
j end_loop

check_cp:
la t0, command_buf
la t1, cp_cmd
jal ra, str_eq
beq a0, zero, check_ps
la a0, arg1_buf
la a1, arg2_buf
jal ra, cp_handler
j end_loop

check_ps:
la t0, command_buf
la t1, ps_cmd
jal ra, str_eq
beq a0, zero, check_sleep
jal ra, ps_handler
j end_loop

check_sleep:
la t0, command_buf
la t1, sleep_cmd
jal ra, str_eq
beq a0, zero, unknown_command
la a0, arg1_buf
jal ra, sleep_handler
j end_loop

unknown_command:
# Controllo se il comando è vuoto
la t0, command_buf
lbu t1, 0(t0)
beq t1, zero, end_loop # Se vuoto, torna al loop

# Comando non riconosciuto
li a7, 4
la a0, error_cmd
ecall
j end_loop

end_loop:
# Ripristina i registri
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
j command_loop

# ---------------------------
# Funzione: parse_input - Analizza l'input e lo divide in comando e argomenti
parse_input:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

# Pulisci i buffer
la t0, command_buf
sb zero, 0(t0)
la t0, arg1_buf
sb zero, 0(t0)
la t0, arg2_buf
sb zero, 0(t0)

# Puntatori ai buffer
la s0, input_buf # Input sorgente
la s1, command_buf # Destinazione comando

# Salta gli spazi iniziali
skip_spaces_start:
lbu t2, 0(s0)
beq t2, zero, parse_done # Se fine stringa, esci
li t3, 32 # Spazio
beq t2, t3, skip_space_continue
li t3, 9 # Tab
beq t2, t3, skip_space_continue
li t3, 10 # Newline
beq t2, t3, skip_space_continue
j extract_command
skip_space_continue:
addi s0, s0, 1
j skip_spaces_start

# Estrai il comando
extract_command:
la t4, command_buf
li t5, 63 # Max 63 caratteri + null
extract_command_loop:
lbu t2, 0(s0)
beq t2, zero, parse_done # Se fine stringa, esci
li t3, 32 # Spazio
beq t2, t3, extract_arg1_prep
li t3, 9 # Tab
beq t2, t3, extract_arg1_prep
li t3, 10 # Newline
beq t2, t3, parse_done

# Controlla overflow buffer comando
sub t6, s1, t4
bge t6, t5, parse_overflow
sb t2, 0(s1)
addi s0, s0, 1
addi s1, s1, 1
j extract_command_loop

extract_arg1_prep:
sb zero, 0(s1) # Termina la stringa del comando
la s1, arg1_buf # Reset del puntatore all'argomento 1

# Salta gli spazi tra comando e arg1
skip_spaces_arg1:
addi s0, s0, 1
lbu t2, 0(s0)
beq t2, zero, parse_done # Se fine stringa, esci
li t3, 32 # Spazio
beq t2, t3, skip_spaces_arg1
li t3, 9 # Tab
beq t2, t3, skip_spaces_arg1
li t3, 10 # Newline
beq t2, t3, parse_done

# Estrai il primo argomento
extract_arg1:
la t4, arg1_buf
li t5, 63
extract_arg1_loop:
lbu t2, 0(s0)
beq t2, zero, parse_done # Se fine stringa, esci
li t3, 32 # Spazio
beq t2, t3, extract_arg2_prep
li t3, 9 # Tab
beq t2, t3, extract_arg2_prep
li t3, 10 # Newline
beq t2, t3, parse_done

# Controlla overflow buffer arg1
sub t6, s1, t4
bge t6, t5, parse_overflow
sb t2, 0(s1)
addi s0, s0, 1
addi s1, s1, 1
j extract_arg1_loop

extract_arg2_prep:
sb zero, 0(s1) # Termina la stringa dell'arg1
la s1, arg2_buf # Reset del puntatore all'argomento 2

# Salta gli spazi tra arg1 e arg2
skip_spaces_arg2:
addi s0, s0, 1
lbu t2, 0(s0)
beq t2, zero, parse_done # Se fine stringa, esci
li t3, 32 # Spazio
beq t2, t3, skip_spaces_arg2
li t3, 9 # Tab
beq t2, t3, skip_spaces_arg2
li t3, 10 # Newline
beq t2, t3, parse_done

# Estrai il secondo argomento
extract_arg2:
la t4, arg2_buf
li t5, 63
extract_arg2_loop:
lbu t2, 0(s0)
beq t2, zero, arg2_done # Se fine stringa, termina
li t3, 10 # Newline
beq t2, t3, arg2_done

# Controlla overflow buffer arg2
sub t6, s1, t4
bge t6, t5, parse_overflow
sb t2, 0(s1)
addi s0, s0, 1
addi s1, s1, 1
j extract_arg2_loop

arg2_done:
sb zero, 0(s1) # Termina la stringa dell'arg2

parse_done:
# Ripristina i registri
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

parse_overflow:
li a7, 4
la a0, error_arg
ecall
j parse_done

# ---------------------------
# Funzione: init_fs - Inizializza il file system
init_fs:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

# Imposta tutte le voci come libere (tipo = -1)
li t0, 0
la t1, fs_array
init_loop:
li t2, NUM_ENTRIES
bge t0, t2, init_entries
li t3, ENTRY_SIZE
mul t4, t0, t3
add t5, t1, t4
li t6, -1
sb t6, TYPE_OFFSET(t5)
addi t0, t0, 1
j init_loop

init_entries:
# Aggiunge directory "/"
li a0, 1
la a1, root_dir_name
la a2, empty_string
jal ra, add_entry

# Aggiunge directory "/home"
li a0, 1
la a1, home_dir_name
la a2, empty_string
jal ra, add_entry

# Aggiunge directory "/home/user"
li a0, 1
la a1, user_dir_name
la a2, empty_string
jal ra, add_entry

# Aggiunge file "/home/user/readme.txt"
li a0, 0
la a1, readme_file_name
la a2, readme_content
jal ra, add_entry

# Aggiunge file "/home/user/hello.c"
li a0, 0
la a1, hello_file_name
la a2, hello_content
jal ra, add_entry

# Ripristina i registri
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# ---------------------------
# Funzione: get_free_entry - Trova la prima voce libera
# OUT: a0 = indice della voce libera, -1 se non trovato
get_free_entry:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

li t0, 0
la t1, fs_array
find_free_loop:
li t2, NUM_ENTRIES
bge t0, t2, no_free_entry
li t3, ENTRY_SIZE
mul t4, t0, t3
add t5, t1, t4
lb t6, TYPE_OFFSET(t5) # Carica con segno
li t3, -1              # Uso t3 invece di t7
beq t6, t3, free_entry_found
addi t0, t0, 1
j find_free_loop

no_free_entry:
li a0, -1
j get_free_done

free_entry_found:
mv a0, t0

get_free_done:
# Ripristina i registri
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# ---------------------------
# Funzione: find_entry_by_name - Cerca una voce per nome
# IN: a0 = nome
# OUT: a0 = indice della voce, -1 se non trovato
find_entry_by_name:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv s0, a0
li t0, 0
la t1, fs_array
find_loop:
li t2, NUM_ENTRIES
bge t0, t2, not_found
li t3, ENTRY_SIZE
mul t4, t0, t3
add t5, t1, t4
lb t6, TYPE_OFFSET(t5) # Carica con segno
li t3, -1              # Uso t3 invece di t7
beq t6, t3, skip_entry
mv a0, s0
addi a1, t5, NAME_OFFSET
jal ra, str_eq
bne a0, zero, entry_found
skip_entry:
addi t0, t0, 1
j find_loop

entry_found:
mv a0, t0
j find_done

not_found:
li a0, -1

find_done:
# Ripristina i registri
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# ---------------------------
# Funzione: add_entry - Aggiunge una nuova voce
# IN: a0 = tipo (0=file, 1=dir), a1 = nome, a2 = contenuto (per file)
add_entry:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv s0, a0
mv s1, a1
mv s2, a2

# Trova uno slot libero
jal ra, get_free_entry
li t0, -1
beq a0, t0, add_fs_full

# Calcola l'indirizzo della voce
li t1, ENTRY_SIZE
mul t2, a0, t1
la t3, fs_array
add t4, t3, t2

# Imposta il tipo
sb s0, TYPE_OFFSET(t4)

# Copia il nome (max 31 byte + null)
addi a0, t4, NAME_OFFSET
mv a1, s1
li a2, 31
jal ra, str_copy_n

# Se è un file, copia il contenuto (max 127 byte + null)
li t5, 0
beq s0, t5, copy_content
j add_done

copy_content:
addi a0, t4, CONTENT_OFFSET
mv a1, s2
li a2, 127
jal ra, str_copy_n

add_done:
# Ripristina i registri
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

add_fs_full:
li a7, 4
la a0, error_fs_full
ecall
j add_done

# ---------------------------
# Funzione: remove_entry - Rimuove una voce
# IN: a0 = indice
remove_entry:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv s0, a0

# Calcola l'indirizzo della voce
li t1, ENTRY_SIZE
mul t2, s0, t1
la t3, fs_array
add t4, t3, t2

# Imposta il tipo a -1
li t5, -1
sb t5, TYPE_OFFSET(t4)

# Ripristina i registri
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# ---------------------------
# Funzione: resolve_path - Risolve un percorso relativo o assoluto
# IN: a0 = path
# OUT: a0 = percorso assoluto in temp_buf
resolve_path:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv s0, a0

# Controlla se il percorso è assoluto (inizia con '/')
lbu t0, 0(s0)
li t1, 47 # '/'
beq t0, t1, copy_absolute

# Percorso relativo: concatena current_dir e path
la a0, temp_buf
la a1, current_dir
jal ra, str_copy

# Aggiungi '/' se current_dir non è '/'
la a0, current_dir
la a1, root_dir_name
jal ra, str_eq
beq a0, zero, append_slash

# Se current_dir è '/', non aggiungere '/'
j append_path

append_slash:
la a0, temp_buf
la a1, slash_str
jal ra, str_append

append_path:
la a0, temp_buf
mv a1, s0
jal ra, str_append
j resolve_done

copy_absolute:
la a0, temp_buf
mv a1, s0
jal ra, str_copy

resolve_done:
# Ripristina i registri
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# ---------------------------
# Handler per i comandi

# echo_handler - Stampa il testo passato come argomento
echo_handler:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv s0, a0
lbu t0, 0(s0)
bne t0, zero, echo_show

li a7, 4
la a0, newline
ecall
j echo_done

echo_show:
li a7, 4
mv a0, s0
ecall
li a7, 4
la a0, newline
ecall

echo_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# ls_handler - Mostra lista file nella directory corrente
ls_handler:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

# Inizializza indice e base array
li s0, 0                 # s0 = indice corrente
la s1, fs_array         # s1 = base fs_array
la s2, current_dir      # s2 = current_dir

ls_loop:
li t0, NUM_ENTRIES
bge s0, t0, ls_done     # Se indice >= NUM_ENTRIES, termina

# Calcola indirizzo entry corrente
li t1, ENTRY_SIZE
mul t2, s0, t1
add t3, s1, t2          # t3 = indirizzo entry

# Controlla se entry è valida
lb t4, TYPE_OFFSET(t3)
li t5, -1
beq t4, t5, ls_next     # Se entry libera, salta

# Stampa nome file
li a7, 4
addi a0, t3, NAME_OFFSET
ecall
li a7, 4
la a0, newline
ecall

ls_next:
addi s0, s0, 1
j ls_loop

ls_done:
# Ripristina registri
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# cat_handler - Mostra contenuto di un file
cat_handler:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv s0, a0
lbu t0, 0(s0)
bne t0, zero, cat_resolve
li a7, 4
la a0, error_arg
ecall
j cat_done

cat_resolve:
# Risolve il percorso
mv a0, s0
jal ra, resolve_path
la a0, temp_buf
jal ra, find_entry_by_name
li t0, -1
beq a0, t0, cat_not_found
mv s1, a0
# Controlla se è un file
li t1, ENTRY_SIZE
mul t2, s1, t1
la t3, fs_array
add t4, t3, t2
lb t5, TYPE_OFFSET(t4)
li t6, 0
bne t5, t6, cat_not_file
# Stampa il contenuto
li a7, 4
addi a0, t4, CONTENT_OFFSET
ecall
li a7, 4
la a0, newline
ecall
j cat_done

cat_not_found:
li a7, 4
la a0, error_file_not_found
ecall
j cat_done

cat_not_file:
li a7, 4
la a0, error_not_a_file
ecall

cat_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# pwd_handler - Mostra directory corrente
pwd_handler:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

li a7, 4
la a0, current_dir
ecall
li a7, 4
la a0, newline
ecall

lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# mkdir_handler - Crea directory
mkdir_handler:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv s0, a0
lbu t0, 0(s0)
bne t0, zero, mkdir_resolve
li a7, 4
la a0, error_arg
ecall
j mkdir_done

mkdir_resolve:
mv a0, s0
jal ra, resolve_path
la a0, temp_buf
jal ra, find_entry_by_name
li t0, -1
bne a0, t0, mkdir_exists
# Crea la directory
li a0, 1
la a1, temp_buf
la a2, empty_string
jal ra, add_entry
j mkdir_done

mkdir_exists:
li a7, 4
la a0, error_invalid_arg
ecall

mkdir_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# touch_handler - Crea file
touch_handler:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv s0, a0
lbu t0, 0(s0)
bne t0, zero, touch_resolve
li a7, 4
la a0, error_arg
ecall
j touch_done

touch_resolve:
mv a0, s0
jal ra, resolve_path
la a0, temp_buf
jal ra, find_entry_by_name
li t0, -1
beq a0, t0, touch_create
# Se esiste, controlla se è un file
mv s1, a0
li t1, ENTRY_SIZE
mul t2, s1, t1
la t3, fs_array
add t4, t3, t2
lb t5, TYPE_OFFSET(t4)
li t6, 0
beq t5, t6, touch_done
li a7, 4
la a0, error_not_a_file
ecall
j touch_done

touch_create:
# Crea il file
li a0, 0
la a1, temp_buf
la a2, empty_string
jal ra, add_entry

touch_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# rm_handler - Rimuove file o directory
rm_handler:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv s0, a0
lbu t0, 0(s0)
bne t0, zero, rm_resolve
li a7, 4
la a0, error_arg
ecall
j rm_done

rm_resolve:
mv a0, s0
jal ra, resolve_path
la a0, temp_buf
jal ra, find_entry_by_name
li t0, -1
beq a0, t0, rm_not_found
mv s1, a0
# Controlla se è una directory
li t1, ENTRY_SIZE
mul t2, s1, t1
la t3, fs_array
add t4, t3, t2
lb t5, TYPE_OFFSET(t4)
li t6, 1
bne t5, t6, rm_remove
# Verifica se la directory è vuota
mv a0, s1
jal ra, check_dir_empty
beq a0, zero, rm_dir_not_empty
rm_remove:
mv a0, s1
jal ra, remove_entry
j rm_done

rm_not_found:
li a7, 4
la a0, error_file_not_found
ecall
j rm_done

rm_dir_not_empty:
li a7, 4
la a0, error_dir_not_empty
ecall

rm_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# check_dir_empty - Verifica se una directory è vuota
check_dir_empty:
# Salva registri (ordine: ra, s0, s1, s2, s3, s4, s5)
addi sp, sp, -28
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)
sw s3, 16(sp)
sw s4, 20(sp)
sw s5, 24(sp)

mv s0, a0          # s0 = indice directory

# Prepara il prefisso della directory in temp_buf (nome + '/')
li t0, ENTRY_SIZE
mul t1, s0, t0
la t2, fs_array
add t3, t2, t1
addi t4, t3, NAME_OFFSET

la a0, temp_buf
mv a1, t4
jal ra, str_copy
la a0, temp_buf
la a1, slash_str
jal ra, str_append

# Inizializza contatori
li s1, 0           # s1 = contatore entries
la s2, fs_array    # s2 = base array
la s3, temp_buf    # s3 = prefisso da cercare

dir_check_loop:
li t0, NUM_ENTRIES
bge s1, t0, dir_is_empty    # Se finito array, directory vuota

# Calcola indirizzo entry corrente in modo sicuro (tutti i valori sono piccoli)
li t0, ENTRY_SIZE
mul t1, s1, t0
add s4, s2, t1     # s4 = entry corrente

# Verifica se entry è valida
lb t0, TYPE_OFFSET(s4)
li t1, -1
beq t0, t1, dir_check_next  # Se entry libera, salta
beq s1, s0, dir_check_next  # Se è la directory stessa, salta

# Verifica se il nome inizia con il prefisso (cioè è contenuto nella dir)
addi t5, s4, NAME_OFFSET
mv a0, t5
mv a1, s3
jal ra, str_start_with
beq a0, zero, dir_check_next
# Se a0 != 0, la directory NON è vuota
j dir_not_empty

dir_check_next:
addi s1, s1, 1
j dir_check_loop

dir_is_empty:
li a0, 1
j dir_check_done

dir_not_empty:
li a0, 0

dir_check_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
lw s3, 16(sp)
lw s4, 20(sp)
lw s5, 24(sp)
addi sp, sp, 28
ret

# cp_handler - Copia file
cp_handler:
# Salva i registri
addi sp, sp, -20       # Modificato: aumentato per s3
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)
sw s3, 16(sp)         # Aggiunto: salva s3

mv s0, a0
mv s1, a1
lbu t0, 0(s0)
beq t0, zero, cp_arg_error
lbu t0, 0(s1)
beq t0, zero, cp_arg_error
j cp_resolve

cp_arg_error:
li a7, 4
la a0, error_arg
ecall
j cp_done

cp_resolve:
# Risolve il percorso di origine
mv a0, s0
jal ra, resolve_path
la a0, temp_buf
jal ra, find_entry_by_name
li t0, -1
beq a0, t0, cp_src_not_found
mv s2, a0
# Controlla se è un file
li t1, ENTRY_SIZE
mul t2, s2, t1
la t3, fs_array
add t4, t3, t2
lb t5, TYPE_OFFSET(t4)
li t6, 0
bne t5, t6, cp_not_file

# Risolve il percorso di destinazione
mv a0, s1
jal ra, resolve_path
la a0, temp_buf
jal ra, find_entry_by_name
li t0, -1
beq a0, t0, cp_create_dst
# Se esiste, controlla se è un file
mv s3, a0
li t1, ENTRY_SIZE
mul t2, s3, t1
la t3, fs_array
add t5, t3, t2
lb t6, TYPE_OFFSET(t5)
li t3, 0               # Uso t3 invece di t7
bne t6, t3, cp_not_file_dst
# Copia il contenuto
addi a0, t5, CONTENT_OFFSET
addi a1, t4, CONTENT_OFFSET
jal ra, str_copy
j cp_done

cp_create_dst:
# Crea un nuovo file con il contenuto di src
li a0, 0
la a1, temp_buf
addi a2, t4, CONTENT_OFFSET
jal ra, add_entry
j cp_done

cp_src_not_found:
li a7, 4
la a0, error_file_not_found
ecall
j cp_done

cp_not_file:
li a7, 4
la a0, error_not_a_file
ecall
j cp_done

cp_not_file_dst:
li a7, 4
la a0, error_not_a_file
ecall

cp_done:
# Ripristina i registri
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
lw s3, 16(sp)         # Aggiunto: ripristina s3
addi sp, sp, 20       # Modificato: aggiustato per s3
ret

# ps_handler - Mostra processi attivi simulati
ps_handler:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

li a7, 4
la a0, process_list
ecall

lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# is_numeric - Verifica se una stringa contiene solo cifre
# IN: a0 = stringa
# OUT: a0 = 1 se numerica, 0 altrimenti
is_numeric:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv t0, a0
is_numeric_loop:
lbu t1, 0(t0)
beq t1, zero, is_numeric_true
li t2, '0'
blt t1, t2, is_numeric_false
li t2, '9'
bgt t1, t2, is_numeric_false
addi t0, t0, 1
j is_numeric_loop

is_numeric_true:
li a0, 1
j is_numeric_done

is_numeric_false:
li a0, 0

is_numeric_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# sleep_handler - Pausa l'esecuzione per un numero di secondi
sleep_handler:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv s0, a0
lbu t0, 0(s0)
bne t0, zero, sleep_check_numeric
li a0, 1 # Default a 1 secondo se arg mancante
j sleep_convert_done

sleep_check_numeric:
mv a0, s0
jal ra, is_numeric
beq a0, zero, sleep_invalid_arg
li a0, 0
mv t0, s0

sleep_convert:
lbu t1, 0(t0)
beq t1, zero, sleep_convert_done
li t2, '0'
sub t1, t1, t2
li t2, 10
mul a0, a0, t2
add a0, a0, t1
addi t0, t0, 1
j sleep_convert

sleep_convert_done:
li t0, 10
blt a0, t0, sleep_continue
li a0, 10

sleep_continue:
li t0, 1000
mul a0, a0, t0
li a7, 32
ecall
j sleep_done

sleep_invalid_arg:
li a7, 4
la a0, error_arg
ecall

sleep_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# ---------------------------
# Utility di manipolazione stringhe

# str_eq: confronta due stringhe
# IN: a0 = str1, a1 = str2
# OUT: a0 = 1 se uguali, 0 altrimenti
str_eq:
addi sp, sp, -28
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)
sw s3, 16(sp)
sw s4, 20(sp)
sw s5, 24(sp)

mv s0, a0   # s0 = str1
mv s1, a1   # s1 = str2

str_eq_loop:
lbu t2, 0(s0)
lbu t3, 0(s1)
bne t2, t3, str_eq_not_equal
beq t2, zero, str_eq_equal
addi s0, s0, 1
addi s1, s1, 1
j str_eq_loop
str_eq_not_equal:
li a0, 0
j str_eq_done
str_eq_equal:
li a0, 1
str_eq_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
lw s3, 16(sp)
lw s4, 20(sp)
lw s5, 24(sp)
addi sp, sp, 28
ret

# str_start_with: verifica se str1 inizia con str2
# IN: a0 = str1, a1 = prefix
# OUT: a0 = 1 se str1 inizia con str2, 0 altrimenti
str_start_with:
addi sp, sp, -28
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)
sw s3, 16(sp)
sw s4, 20(sp)
sw s5, 24(sp)

mv s0, a0      # s0 = str1
mv s1, a1      # s1 = prefix

str_sw_loop:
lbu t2, 0(s1)
beq t2, zero, str_sw_true   # fine prefix, match
lbu t3, 0(s0)
beq t3, zero, str_sw_false  # fine str1, no match
bne t2, t3, str_sw_false    # caratteri diversi, no match
addi s0, s0, 1
addi s1, s1, 1
j str_sw_loop

str_sw_true:
li a0, 1
j str_sw_done

str_sw_false:
li a0, 0

str_sw_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
lw s3, 16(sp)
lw s4, 20(sp)
lw s5, 24(sp)
addi sp, sp, 28
ret

# str_len: calcola la lunghezza di una stringa
# IN: a0 = str
# OUT: a0 = lunghezza
str_len:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv t0, a0
li a0, 0
str_len_loop:
lbu t1, 0(t0)
beq t1, zero, str_len_done
addi a0, a0, 1
addi t0, t0, 1
j str_len_loop
str_len_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# str_copy: copia una stringa
# IN: a0 = dest, a1 = src
str_copy:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

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
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# str_copy_n: copia una stringa con limite
# IN: a0 = dest, a1 = src, a2 = max_chars
str_copy_n:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv t0, a0
mv t1, a1
mv t2, a2
str_copy_n_loop:
beq t2, zero, str_copy_n_end
lbu t3, 0(t1)
sb t3, 0(t0)
beq t3, zero, str_copy_n_done
addi t0, t0, 1
addi t1, t1, 1
addi t2, t2, -1
j str_copy_n_loop
str_copy_n_end:
sb zero, 0(t0)
str_copy_n_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# str_append: appende una stringa a un'altra
# IN: a0 = dest, a1 = src
str_append:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv t0, a0
str_append_find_end:
lbu t1, 0(t0)
beq t1, zero, str_append_copy
addi t0, t0, 1
j str_append_find_end
str_append_copy:
mv a0, t0
mv a1, a1
jal ra, str_copy

lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret

# str_contains: verifica se una stringa contiene un carattere
# IN: a0 = str, a2 = char
# OUT: a0 = 1 se contiene, 0 altrimenti
str_contains:
# Salva i registri
addi sp, sp, -16
sw ra, 0(sp)
sw s0, 4(sp)
sw s1, 8(sp)
sw s2, 12(sp)

mv s0, a0      # Salva str in s0
mv s1, a2      # Salva char in s1

str_contains_loop:
lbu t0, 0(s0)  # Legge carattere corrente usando s0
beq t0, zero, str_contains_not_found
beq t0, s1, str_contains_found
addi s0, s0, 1
j str_contains_loop

str_contains_found:
li a0, 1
j str_contains_done

str_contains_not_found:
li a0, 0

str_contains_done:
lw ra, 0(sp)
lw s0, 4(sp)
lw s1, 8(sp)
lw s2, 12(sp)
addi sp, sp, 16
ret