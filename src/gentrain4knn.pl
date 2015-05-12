#! /usr/bin/perl

use strict;
use Getopt::Long "GetOptions";
use File::Basename;

my $debug=0;

#Input:
#File with phrase-pairs extracted from training data
# src-phrase ||| trg-phrase ||| segment-id
# ...
# ...
# file is sorted by src-phrase
#
#File with topic vectors
# t1 t2 ... tn
# ....
# the n-th line contains vector of segment n

#Output:
#  size-of-topic-vectors
#  src-phrase  number-of-translations
#  trg-phrase  topic-vector
#  ....
#  trg-phrase  topic-vector
#  src phrase  number-of-translations
#  trg-phrase  topic-vector
#  ....


my (@VEC)=("DUMMY"); #real vectors start from position 1

#We filter out phrase pairs with low frequency
#Phrase collection must be sorted wrt source phrase

my ($minfreq)=5;      #skip src phrases that appear less than N times
my ($maxdocfreq)=0.05; #skip src phrases that appear in X% of the lines

sub loadvectors(){
    my ($file)=@_;
    open(VECFILE,"<$file") || die "Cannot open $file\n";
    printf STDERR "loading vectors ...";
    while(chop($_=<VECFILE>)){
        push(@VEC,$_);
    }
    close(VECFILE);
    printf STDERR "done (". $#VEC.")\n";
   
}


#####

my ($phfile,$vecfile,$knnfile)=(@ARGV);


&loadvectors($vecfile);

#check that knn file does not exist
die "cannot overwrite $knnfile\n" if -e $knnfile;
open(KNNFILE,">$knnfile") || die "Cannot open knn file $phfile\n";


my ($src,$trg,$align,$seg)=();


#First pass: count translations for each source phrase
printf STDERR "Pass 1: count translations of each source phrase\n";
my (%count,%count2,%doclist,%dcount,$totdoc)=();
open(PHFILE,"<$phfile") || die "Cannot read from file $phfile\n";
while (chop($_=<PHFILE>)){
    ($src,$trg,$align,$seg)=split(/ \|\|\| /,$_);
    $count{"$src"}++;
    ${$count2{"$src"}}{"$seg"}++;
    $doclist{"$seg"}++;
}
close(PHFILE);

#compute document frequency for each src phrase

foreach $src (keys %count){
    $dcount{"$src"}=scalar (keys %{$count2{"$src"}});
    #printf  "$src ->".$dcount{"$src"}."\n";
}
$totdoc=scalar (keys %doclist);


printf STDERR "Total of segments is: $totdoc\n";
printf STDERR "Pass 2: generate KNN training file\n";

#write # topics
my $n=split(/ +/,$VEC[1]);

printf KNNFILE "$n\n";
my $curphrase="";
open(PHFILE,"<$phfile") || die "Cannot read from file $phfile\n";
while (chop($_=<PHFILE>)){

    ($src,$trg,$align,$seg)=split(/ \|\|\| /,$_);
    
    #printf (STDERR "Skip1: $src\n"),
    next if $count{$src} <  $minfreq; #skip unfrequent phrases
    #printf (STDERR "Skip2: $src\n"),
    next if $dcount{$src}/$totdoc> $maxdocfreq; #skip phrases that occurr in too many documents
    
    if ($src ne $curphrase){
        printf KNNFILE $src." ||| ".$count{"$src"}."\n";
        $curphrase=$src;
    }
    printf KNNFILE "$trg"." ||| ".$VEC[$seg]."\n";
    
}
close(PHFILE);
close(KNNFILE);






