

source ./sprute.conf 
 
setup_compilation_env () { 
   mkdir -p "$CHROOT_HOME/bin/" 
   #upload fakeuname 
   cp -f "$FAKEUNAME" "$CHROOT_HOME/bin/" && 
   #upload_sprute 
   rsync -ur --exclude '/.git' "$SPRUTE_SRC_DIR" "$CHROOT_HOME/sprute" 
} 
 
get_stap_binaries () { 
   stub 
   #cp 
   #chown work:work -r 
}



