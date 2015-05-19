#!/usr/bin/perl -w

use Data::Dumper;
#
# input are
# phrases extracted from knn
# input file on which the phrases are extracted
#

open INPUT, $ARGV[0];
my $topk = $ARGV[1];
my $cbtm=0;
my $xi=1;
while(<STDIN>) { 
	chop();
	$line = <INPUT>;
	if($_ eq "") {print $line; next;}
	my @PhrasePairs = split(/ \|\|\|\| /);
	my %tranOptsCounts=();
	my %tranOptsValue=();
	my %finalizedTranslations=();
	my %finalizedTranslationsSum=();
	for my $x (@PhrasePairs){
		my ($srcPhrase, $opts) = split(/ \|\|\| /, $x);
		my (@options) = split(/ \|\| /, $opts);
		my $count=0;
		my $key="";$value=0;
		for my $opt (@options){
			if($count%2==0){
				$key=$opt;
			}
			else{
				$value=$opt;
				$tranOptsCounts{$srcPhrase}{$key}++;
				$tranOptsValue{$srcPhrase}{$key}=2-$value;
			}
			$count++;
		}
	}
#	print Dumper \%tranOptsCounts;
#	print STDERR Dumper \%tranOptsValue;
	for my $x(sort keys %tranOptsCounts){
		my $count=0;
		for my $y(sort keys %{$tranOptsCounts{$x}}){
			if($count >= $topk){ last;}
			$finalizedTranslations{$x}{$y} = $tranOptsCounts{$x}{$y} * $tranOptsValue{$x}{$y};
			$finalizedTranslationsSum{$x} += $tranOptsCounts{$x}{$y} * $tranOptsValue{$x}{$y};
			$count++;
		}
		for my $y(sort keys %{$finalizedTranslations{$x}}){
			$finalizedTranslations{$x}{$y} = ($finalizedTranslations{$x}{$y}*1.0) / (1.0 * $finalizedTranslationsSum{$x} ); 
		}
	}

	print STDERR Dumper \%finalizedTranslations;
	if($cbtm){
		my $command= "<dlt type=\"cbtm\" cbtm=\"";
		my $flag=0;
		foreach my $x(sort keys %finalizedTranslations){
			foreach my $y(sort { $finalizedTranslations{$x}{$b} <=> $finalizedTranslations{$x}{$a} } keys %{$finalizedTranslations{$x}}){
				$command .= "$x ||| $y |||| ";
			}
		}
		$command = substr($command, 0, -6);
		$command .= "\"/>";
		print $command." ".$line;
	}
	elsif ($xi){
		foreach my $x(sort keys %finalizedTranslations){
			my $options="";
			my $prob="";
			foreach my $y(sort { $finalizedTranslations{$x}{$b} <=> $finalizedTranslations{$x}{$a} } keys %{$finalizedTranslations{$x}}){
				$options .= "$y||";
				$prob .= "$finalizedTranslations{$x}{$y}||";
			}
			$options = substr($options, 0, -2);
			$prob = substr($prob, 0, -2);
			my $command = "<n translation=\"".$options."\" prob=\"".$prob."\">".$x."</n>";
			$line =~ s/^$x /$command /;
			$line =~ s/ $x / $command /;
			$line =~ s/ $x$/ $command/;
		}
		print $line;
	}
}
close(INPUT);
