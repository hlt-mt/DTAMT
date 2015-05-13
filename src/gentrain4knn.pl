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

my ($phfile,$vecfile,$knnfile)=();
my ($minfreq)=5;      #skip src phrases that appear less than N times
my ($maxdocfreq)=0.05; #skip src phrases that appear in X% of the lines
my ($help)=();

&GetOptions(
    'pf=s' => \$phfile,
    'vf=s' => \$vecfile,
    'of=s'=>\$knnfile,
    'minfreq=s'=>\$minfreq,
    'maxdocfreq' => \$maxdocfreq,
    'h|help' => \$help,);

if ($help || !$phfile || !$vecfile || !$knnfile) {
    my $cmnd = basename($0);
    print "\n$cmnd - generate training set for KNN algorithm\n",
    "\nUSAGE:\n",
    "       $cmnd [options]\n",
    "\nOPTIONS:\n",
    "       --pf  <string>        phrase-pair file including segment identifiers \n",
    "       --vf <string>         topic vector file \n",
    "       --of <string>         output file \n",
    "       --minfreq <count>     minimum corpus frequency for words (default 5)\n",
    "       --maxdocfreq <fraction>  maximum document frequency of words (default 0.1)\n",
    "       -h, --help            (optional) print these instructions\n",
    "\n";
    
    exit(1);
}

my (@VEC)=("DUMMY"); #real vectors start from position 1

#We filter out phrase pairs with low frequency
#Phrase collection must be sorted wrt source phrase


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



&loadvectors($vecfile);

#check that knn file does not exist
die "cannot overwrite $knnfile\n" if -e $knnfile;
open(KNNFILE,">$knnfile") || die "Cannot open knn file $phfile\n";
my ($src,$trg,$align,$seg)=();


#First pass: count translations for each source phrase
printf STDERR "Pass 1: count translations of each source phrase\n";
my (%count,%count2,%doclist,%dcount,$totdoc,$totph)=();
open(PHFILE,"<$phfile") || die "Cannot read from file $phfile\n";
while (chop($_=<PHFILE>)){
    ($src,$trg,$align,$seg)=split(/ \|\|\| /,$_);
    
    $count{"$src"}++;
    ${$count2{"$src"}}{"$seg"}++;
    $doclist{"$seg"}++;
    
    printf STDERR "." if (++$totph % 1000000)==0;
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
$totph=0;
while (chop($_=<PHFILE>)){
    
    printf STDERR "." if (++$totph % 1000000)==0;
    ($src,$trg,$align,$seg)=split(/ \|\|\| /,$_);
    
    #printf (STDERR "Skip1: $src\n"),
    next if $count{$src} <  $minfreq; #skip unfrequent phrases
    #printf (STDERR "Skip2: $src\n"),
    next if $dcount{$src}/$totdoc> $maxdocfreq; #skip phrases that occurr in too many documents
    
    if ($src ne $curphrase){
        printf KNNFILE metaquote($src)." ||| ".$count{"$src"}."\n";
        $curphrase=$src;
    }
    printf KNNFILE metaquote($trg)." ||| ".$VEC[$seg]."\n";
    
}
close(PHFILE);
close(KNNFILE);






