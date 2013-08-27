fat-fs:
	stap -g -p 4 -m s2e -I ./staplib ./fat-generated.stp

all: fat-fs

