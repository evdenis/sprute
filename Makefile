jfs:
	stap -g -p 4 -m jfs_s2e -I ./staplib ./jfs.stp

minix:
	stap -g -p 4 -m minix_s2e -I ./staplib ./minix.stp

msdos:
	stap -g -p 4 -m msdos_s2e -I ./staplib ./msdos.stp

vfat:
	stap -g -p 4 -m vfat_s2e -I ./staplib ./vfat.stp

fat:
	stap -g -p 4 -m fat_s2e -I ./staplib ./fat.stp

all: fat vfat msdos minix jfs

