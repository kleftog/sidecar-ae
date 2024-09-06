GCC=gcc
CLG=clang
CLG_SCS=/home/pzielins/Documents/shadow-stack/llvm-project-llvmorg-12.0.1-originalSCS/BUILD/bin/clang
CLG_SDSTK=/home/pzielins/Documents/shadow-stack/llvm-project-llvmorg-12.0.1/BUILD/bin/clang
CLG_CFI=/home/pzielins/llvm-project-12.0.1/BUILDLTO/bin/clang
CLG_SDCFI=/home/kleftog/software/sidecfi/bin/clang
# Disable stack protection, make the stack executable and add debug info
CFLAGS=-fno-stack-protector -z execstack -g
CFLAGS_SDSTK=-fsanitize=shadow-call-stack,side-stack
CFLAGS_ASAN=-fsanitize=address
CFLAGS_SCS=-fsanitize=shadow-call-stack,side-stack
CFLAGS_CFI=-flto -fvisibility=hidden -fsanitize=cfi-icall,cfi-vcall -fsanitize-cfi-cross-dso
CFLAGS_SDCFI=-flto -fvisibility=default -fsanitize=cfi-icall,cfi-vcall -fsanitize-cfi-cross-dso -fsanitize-cfi-decouple

all: build/clang_sdcfi_attack_gen

build/gcc_attack_gen: ./source/attack_gen.c
	${GCC} ${CFLAGS} ./source/attack_gen.c -o ./build/gcc_attack_gen

build/clang_attack_gen: ./source/attack_gen.c
	${CLG} ${CFLAGS} ./source/attack_gen.c -o ./build/clang_attack_gen

build/clang_scs_attack_gen: ./source/attack_gen.c
	${CLG_SCS} ${CFLAGS} ${CFLAGS_SCS} ./source/attack_gen.c -o ./build/clang_scs_attack_gen

build/clang_asan_attack_gen: ./source/attack_gen.c
	${CLG} ${CFLAGS} ${CFLAGS_ASAN} ./source/attack_gen.c -o ./build/clang_asan_attack_gen

build/clang_sdstk_attack_gen: ./source/attack_gen.c
	${CLG_SDSTK} ${CFLAGS} ${CFLAGS_SDSTK} ./source/attack_gen.c -o ./build/clang_sdstk_attack_gen

build/clang_cfi_attack_gen: ./source/attack_gen.c
	${CLG_CFI} ${CFLAGS}  ${CFLAGS_CFI} ./source/attack_gen.c -o ./build/clang_cfi_attack_gen

build/clang_sdcfi_attack_gen: ./source/attack_gen.c
	${CLG_SDCFI} ${CFLAGS} ${CFLAGS_SDCFI} ./source/attack_gen.c -o ./build/clang_sdcfi_attack_gen > clang_sdcfi_attack_gen.log 2>&1

clean:
	rm ./build/*
