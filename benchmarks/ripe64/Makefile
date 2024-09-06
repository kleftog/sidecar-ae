# Compiler
CLANG=../../sidecar/install/llvm-sidecar/bin/clang

# Common flags for all builds
CFLAGS_COMMON=-fno-stack-protector -z execstack -g -fvisibility=default -flto

# Specific flags for different sanitizers
CFLAGS_SAFESTACK=-fsanitize=shadow-call-stack
CFLAGS_SIDESTACK=-fsanitize=shadow-call-stack -fsanitize-sidestack
CFLAGS_CFI=-fsanitize=cfi-icall,cfi-vcall -fsanitize-cfi-cross-dso
CFLAGS_SIDECFI=-fsanitize=cfi-icall,cfi-vcall -fsanitize-cfi-cross-dso -fsanitize-cfi-decouple

# Ensure build directory exists
build:
	mkdir -p build

# Build targets
all: build/clang_attack_gen build/clang_safestack_attack_gen build/clang_sidestack_attack_gen build/clang_cfi_attack_gen build/clang_sidecfi_attack_gen

build/gcc_attack_gen: build ./source/attack_gen.c
	${CC} ${CFLAGS_COMMON} ./source/attack_gen.c -o ./build/gcc_attack_gen

build/clang_attack_gen: build ./source/attack_gen.c
	${CLANG} ${CFLAGS_COMMON} ./source/attack_gen.c -o ./build/clang_attack_gen

build/clang_safestack_attack_gen: build ./source/attack_gen.c
	${CLANG} ${CFLAGS_COMMON} ${CFLAGS_SAFESTACK} ./source/attack_gen.c -o ./build/clang_safestack_attack_gen

build/clang_sidestack_attack_gen: build ./source/attack_gen.c
	${CLANG} ${CFLAGS_COMMON} ${CFLAGS_SIDESTACK} ./source/attack_gen.c -o ./build/clang_sidestack_attack_gen

build/clang_cfi_attack_gen: build ./source/attack_gen.c
	${CLANG} ${CFLAGS_COMMON} ${CFLAGS_CFI} ./source/attack_gen.c -o ./build/clang_cfi_attack_gen

build/clang_sidecfi_attack_gen: build ./source/attack_gen.c
	${CLANG} ${CFLAGS_COMMON} ${CFLAGS_SIDECFI} ./source/attack_gen.c -o ./build/clang_sidecfi_attack_gen
	cd ./build && ../../sidecar/tools/gen_tp.sh clang_sidecfi_attack_gen

clean:
	rm -f ./build/*

