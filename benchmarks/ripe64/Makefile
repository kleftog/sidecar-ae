# Compiler
CLANG=../../sidecar/install/llvm-sidecar/bin/clang

# Common flags for all builds
CFLAGS_COMMON=-fno-stack-protector -z execstack -g -fvisibility=default -flto

# Specific flags for different sanitizers
CFLAGS_SAFESTACK=-fsanitize=shadow-call-stack
CFLAGS_SIDESTACK=-fsanitize=shadow-call-stack -fsanitize=sidestack
CFLAGS_CFI=-fsanitize=cfi-icall,cfi-vcall -fsanitize-cfi-cross-dso
CFLAGS_SDCFI=-fsanitize=cfi-icall,cfi-vcall -fsanitize-cfi-cross-dso -fsanitize-cfi-decouple

# Build targets
all: build/clang_attack_gen build/clang_scs_attack_gen build/clang_sdstk_attack_gen build/clang_cfi_attack_gen build/clang_sdcfi_attack_gen

build/gcc_attack_gen: ./source/attack_gen.c
	${CC} ${CFLAGS_COMMON} ./source/attack_gen.c -o ./build/gcc_attack_gen

build/clang_attack_gen: ./source/attack_gen.c
	${CLANG} ${CFLAGS_COMMON} ./source/attack_gen.c -o ./build/clang_attack_gen

build/clang_scs_attack_gen: ./source/attack_gen.c
	${CLANG} ${CFLAGS_COMMON} ${CFLAGS_SAFESTACK} ./source/attack_gen.c -o ./build/clang_scs_attack_gen

build/clang_sdstk_attack_gen: ./source/attack_gen.c
	${CLANG} ${CFLAGS_COMMON} ${CFLAGS_SIDESTACK} ./source/attack_gen.c -o ./build/clang_sdstk_attack_gen

build/clang_cfi_attack_gen: ./source/attack_gen.c
	${CLANG} ${CFLAGS_COMMON} ${CFLAGS_CFI} ./source/attack_gen.c -o ./build/clang_cfi_attack_gen

build/clang_sdcfi_attack_gen: ./source/attack_gen.c
	${CLANG} ${CFLAGS_COMMON} ${CFLAGS_SDCFI} ./source/attack_gen.c -o ./build/clang_sdcfi_attack_gen > clang_sdcfi_attack_gen.log 2>&1

clean:
	rm -f ./build/*

