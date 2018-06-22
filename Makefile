.RECIPEPREFIX +=

AS=nasm
ASFLAGS=-f obj
LD=alink
LDFLAGS=-oEXE -entry start
RM=rm -f

SAMPLES=23_1 \
        24_1 \
        25_1 25_2 25_3 \
        26_1 26_2 \
        27_1 27_3 \
        28_2 \
        29_1 29_2 29_3 \
        30_1 30_2 \
        31_1 31_2


%.obj : %.asm
    $(AS) $(ASFLAGS) $^

%.exe : %.obj
    $(LD) $(LDFLAGS) $^

all: $(SAMPLES:=.exe)

clean:
    $(RM) $(SAMPLES:=.obj)
    $(RM) $(SAMPLES:=.exe)

.PHONY: clean all
