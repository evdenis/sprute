STAP=stap
FLAGS=-g -p4
INCLUDELIB=-I ./staplib
LIBDEPS=staplib/current_task-generic.stp staplib/s2e.stp $(wildcard staplib/vfslib_*.stpm)
MODULES=$(patsubst %.stp,%_s2e,$(wildcard *.stp))

.PHONY: all clean

all: $(MODULES)

%_s2e : %.stp $(LIBDEPS)
	$(STAP) $(FLAGS) $(INCLUDELIB) $< -m $@

clean:
	-rm -f *.ko
