#!/usr/bin/env perl


#local $\ = undef;
my @file = <>;

my $template = "\@define <name>\n%(\n<actions>\n%)\n\n";

sub add_action {
   $_[0] .= "\n" . "\t" . $_[1];
}

my @list = ('inode', 'file', 'super', 'dentry');

foreach $i (@file) {
   chomp $i;
   if (not $i =~ m/^\s*$/) {
      my $tmpl = $template;
      my $actions;

      $tmpl =~ s/<name>/$i/;
      foreach $j (@list) {
         while ($i =~ m/(?<arg>$j\d?)/g) {
            print $+{arg} . "\n";
            add_action($actions, 'make_action(' . $+{arg} . ')');
         }
      }
      $tmpl =~ s/<actions>/$actions/;
      print $tmpl;
   }
}
