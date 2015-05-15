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

my ($phfile,$vecfile,$knnfile,$filterfile,$blacklistfile)=();
my ($minfreq)=10;      #skip src phrases that appear less than N times
my ($maxdocfreq)=1; #skip src phrases that appear in more X% of the lines
my ($help)=();


&GetOptions(
    'pf=s' => \$phfile,
    'vf=s' => \$vecfile,
    'of=s'=>\$knnfile,
    'ff=s'=>\$filterfile,
    'bf=s'=>\$blacklistfile,
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
    "       --ff <string>         filter file \n",
    "       --bf <string>         blacklist file \n",
    "       --minfreq <count>     minimum corpus frequency for words (default 10)\n",
    "       --maxdocfreq <fraction>  maximum document relative frequency of words (default 1)\n",
    "       -h, --help            (optional) print these instructions\n",
    "\n";
    
    exit(1);
}



#We filter out phrase pairs with low frequency
#Phrase collection must be sorted wrt source phrase
my (@VEC)=("DUMMY"); #real vectors start from position 1

sub loadvectors(){
    my ($file)=@_;
    open(FILE,"<$file") || open(FILE,"$file |") || die "Cannot open $file\n";
    printf STDERR "loading vectors ...";
    while(chop($_=<FILE>)){
        push(@VEC,$_);
    }
    close(FILE);
    printf STDERR "done (". $#VEC.")\n";
   
}



#####
my (%filter)=();

sub loadfilter(){
    my ($file)=@_;
    open(FILE,"<$file") || open(FILE,"$file |") || die "Cannot open $file\n";
    printf STDERR "loading filter ...";
    my ($src,@src)=();
     while (chop($src=<FILE>)){
        @src=split(/ /,$src);
        $filter{"$src[0]"}++;
        for (my $i=1;$i <= $#src; $i++){
            $filter{"$src[$i]"}++;$filter{"$src[$i-1] $src[$i]"}++;
        }
    }
    close(FILE);
    printf STDERR "done\n";
}
#####
my (%blacklist)=();

sub loadblacklist(){
    my ($file)=@_;
    open(FILE,"<$file") || open(FILE,"$file |") || die "Cannot open $file\n";
    printf STDERR "loading blacklist ...";
    my ($src)=();
    while (chop($src=<FILE>)){
        $blacklist{"$src"}++;
    }
    close(FILE);
    printf STDERR "done\n";
}



#check that knn file does not exist
die "cannot overwrite $knnfile\n" if -e $knnfile;

&loadvectors($vecfile);
&loadblacklist($blacklistfile) if $blacklistfile;
&loadfilter($filterfile) if $filterfile;


#Open knnfile
open(KNNFILE,">$knnfile") || die "Cannot open knn file $phfile\n";
my ($src,$trg,$align,$seg,@src,@trg)=();

#First pass: count translations for each source phrase
printf STDERR "Pass 1: count translations of each source phrase\n";
my (%count,%count2,%doclist,%dcount,$totdoc,$totph)=();
open(PHFILE,"<$phfile") || open(PHFILE,"$phfile|") || die "Cannot read from file $phfile\n";

while (chop($_=<PHFILE>)){
    printf STDERR "." if (++$totph % 1000000)==0;
    ($src,$trg,$align,$seg)=split(/ \|\|\| /,$_);
    @src=split(/ /,$src); @trg=split(/ /,$trg);
    next if $blacklistfile && (defined($blacklist{"$src[0]"}) || defined($blacklist{"$src[1]"}));
    next if $filterfile && !defined($filter{"$src"});
    #skip entries not containing real words wither in source or target
    next if $blacklistfile && (!($src[0]=~/[a-zA-Z]{3,}/) || ($src[1] && !($src[1]=~/[a-zA-Z]{3,}/)) || ($src=~/\&[a-zA-Z]+;/));
    next if $blacklistfile && (!($trg[0]=~/[a-zA-Z]{3,}/) || ($trg[1] && !($trg[1]=~/[a-zA-Z]{3,}/)) || ($trg=~/\&[a-zA-Z]+;/));

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
open(PHFILE,"<$phfile") || open(PHFILE,"$phfile|") || die "Cannot read from file $phfile\n";
$totph=0;
while (chop($_=<PHFILE>)){
    
    printf STDERR "." if (++$totph % 1000000)==0;
    ($src,$trg,$align,$seg)=split(/ \|\|\| /,$_);
    @src=split(/ /,$src); @trg=split(/ /,$trg);
    next if $blacklistfile && (defined($blacklist{"$src[0]"}) || defined($blacklist{"$src[1]"}));
    next if $filterfile && !defined($filter{"$src"});
    #skip entries not containing real words wither in source or target
    next if $blacklistfile && (!($src[0]=~/[a-zA-Z]{3,}/) || ($src[1] && !($src[1]=~/[a-zA-Z]{3,}/)) || ($src=~/\&[a-zA-Z]+;/));
    next if $blacklistfile && (!($trg[0]=~/[a-zA-Z]{3,}/) || ($trg[1] && !($trg[1]=~/[a-zA-Z]{3,}/)) || ($trg=~/\&[a-zA-Z]+;/));
    
    #printf (STDERR "Skip1: $src\n"),
    next if $count{$src} <  $minfreq; #skip unfrequent phrases
    #printf (STDERR "Skip2: $src\n"),
    next if $dcount{$src}/$totdoc> $maxdocfreq; #skip phrases that occurr in too many documents
    
    if ($src ne $curphrase){
        printf KNNFILE "%s" , $src." ||| ".$count{"$src"}."\n";
        $curphrase=$src;
    }
    printf KNNFILE "%s" , $trg." ||| ".$VEC[$seg]."\n";
    
}
close(PHFILE);
close(KNNFILE);






