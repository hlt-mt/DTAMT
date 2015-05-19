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

#open file of phrase-pairs
open(PHFILE,"< $phfile") || open(PHFILE,"$phfile|") || die "Cannot read from file $phfile\n";

#Open knnfile
open(KNNFILE,">$knnfile") || die "Cannot open knn file $phfile\n";
#Write size of topic vectors
my $n=split(/ +/,$VEC[1]); printf KNNFILE "$n\n";

my ($ln,$src,$trg,$align,$seg,@src,@trg)=();

my ($count,$newsrc,@rest,$out,$totph)=();

chop($ln=<PHFILE>); #read first line

do{
    printf STDERR "." if (++$totph % 1000000)==0;
    ($src,$trg,$align,$seg)=split(/ \|\|\| /,$ln);
    
    #start checks
    
    @src=split(/ /,$src); @trg=split(/ /,$trg);
    
    #print "matching -$src- -$src[0]- -$src[1]-\n";
    
    if (($blacklistfile && (defined($blacklist{"$src[0]"}) || ($src[1] && defined($blacklist{"$src[1]"}))) && &msg(1,$src,$trg))
    ||
    ($filterfile && !defined($filter{"$src"})  && &msg(2,$src,$trg))
    ||
    ($blacklistfile && (!($src[0]=~/[a-zA-Z]{3,}/) || ($src[1] && !($src[1]=~/[a-zA-Z]{3,}/)) || ($src=~/\&[a-zA-Z]+\;/)) && &msg(4,$src,$trg))
    ||
    ($blacklistfile && (!($trg[0]=~/[a-zA-Z]{3,}/) || ($trg[1] && !($trg[1]=~/[a-zA-Z]{3,}/)) || ($trg=~/\&[a-zA-Z]+\;/)) && &msg(5,$src,$trg)))
    {
        #do nothing
        
    }else{
        #increment number of found translations
        $count++;
        #store line to be printed at the end
        $out=$out.$trg." ||| ".$VEC[$seg]."\n";
    }
    #read next source phrase
    chop($ln=<PHFILE>);
    ($newsrc,@rest)=split(/ \|\|\| /,$ln);
    
    if ($newsrc ne  $src) {
        if ($count && $count >= $minfreq){
            printf KNNFILE "%s" , $src." ||| ".$count."\n";
            printf KNNFILE "%s" , $out;
        }
        $out="";$count=0;
    }
} while($ln);

close(PHFILE);
close(KNNFILE);

#track filtering 
sub msg(){
    my($n,$s,$t)=@_;
    print "skip($n): -$s- -$t-\n" if $debug;
    return 1;
}



