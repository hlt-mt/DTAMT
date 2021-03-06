#! /usr/bin/perl

use strict;
use Getopt::Long "GetOptions";
use File::Basename;

my $debug=0;

# Standard input:
# topic-vector
# source-sentence
# ...
#

# Standard output:
#  size-of-topic-vectors
#  topic-vector
#  src-phrase
#  ....
#  src-phrase
#  \newline
#  topic vector
#  src-phrase
#  ...
#  src-phrase
#  \newline


my ($vec)=();   #real vectors start from position 1
my ($src,@src)=();
my (%set)=();
my $printheader=1;

while (($vec=<STDIN>) && chop($src=<STDIN>)){
    print (scalar split(/ /,$vec)."\n"),$printheader="" if $printheader;
    print $vec;
    @src=split(/ /,$src);    
    %set=();
    print $src[0]."\n"; $set{$src[0]}++;
    for (my $i=1;$i <= $#src; $i++){
        print "$src[$i]\n" if !defined($set{"$src[$i]"});
        print "$src[$i-1] $src[$i]\n" if !defined($set{"$src[$i-1] $src[$i]"});
        $set{"$src[$i]"}++;$set{"$src[$i-1] $src[$i]"}++;
    }
    print "\n"; #final newline

}
