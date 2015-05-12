#! /usr/bin/perl

use strict;
use Getopt::Long "GetOptions";
use File::Basename;

my $debug=0;

#training data will have the following structure:
#  #topics
#  src-phrase  #translations
#  trg-phrase  topic-vector
#  ....
#  trg-phrase topic-vector
#  src phrase  #translations
#  trg-phrase  topic-vector
#  ....

#the file is created from the phrase pairs file and the topic distributions
#we will also create dictionaries for source and target phrases (assumption
#we will only work with short phrases)

my(@VOC,%VOC,$MAXCODE)=();
my (@VEC)=("DUMMY"); #real vectors start from position 1

#We need probably to filter out some phrase pairs before processing
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

sub Encode(){
    my ($word) = @_;
    my ($code)=();
    if (!defined($code=$VOC{$word})){
        $code=($VOC{$word}=$MAXCODE++);
        $VOC[$code]=$word;
    }
    return $code;
}

sub Decode(){
    my ($code) = @_;
    die "decode: code $code is out of boundaries [0,$MAXCODE)\n" if ($code < 0 || $code >= $MAXCODE);
    return $VOC[$code];
}


#####

my ($phfile,$vecfile,$knnfile)=(@ARGV);


&loadvectors($vecfile);

#check that knn file does not exist
die "cannot overwrite $knnfile\n" if -e $knnfile;
open(KNNFILE,">$knnfile") || die "Cannot open knn file $phfile\n";


my ($src,$trg,$align,$seg)=();



#First pass: count translations for each source phrase
printf "Pass 1: count translations of each source phrase\n";
my %count=();
open(PHFILE,"<$phfile") || die "Cannot read from file $phfile\n";
while (chop($_=<PHFILE>)){
    ($src,$trg,$align,$seg)=split(/ \|\|\| /,$_);
    $count{"$src"}++;
}
close(PHFILE);

printf "Pass 2: cgenerate KNN training file\n";

#write # topics
my $n=split(/ +/,$VEC[1]);

printf KNNFILE "$n\n";
my $curphrase="";
open(PHFILE,"<$phfile") || die "Cannot read from file $phfile\n";
while (chop($_=<PHFILE>)){
    print "$_\n";
    ($src,$trg,$align,$seg)=split(/ \|\|\| /,$_);
    next if $count{$src}<5;
    if ($src ne $curphrase){
        print "-$src-\n";
        printf KNNFILE $src." ||| ".$count{"$src"}."\n";
        $curphrase=$src;
    }
    printf KNNFILE "$trg"." ||| ".$VEC[$seg]."\n";
    
}
close(PHFILE);
close(KNNFILE);






