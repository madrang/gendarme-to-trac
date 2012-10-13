#!/usr/bin/perl
use warnings;
use utf8;

#use Encode qw( decode );
use Encode;

use Getopt::Std;
use XML::XPath;
use Text::CSV;
use Text::CSV::Encoded;
use File::Temp qw/ :POSIX /;

if ($#ARGV == 0) {
    print "usage: convert gendarme.xml files to cvs for trac\n";
    exit;
}

my %args;
getopt('iorst', \%args);

my $inputFile = $args{i};
my $outputFile = $args{o};
my $reporter = $args{r};
my $reportStatus = $args{s};
my $reportType = $args{t};

print "Input: ".($inputFile||"Not Defined")."\n";
print "Output: ".($outputFile||"Not Defined")."\n";
print "Reporter: ".($reporter||"Not Defined")."\n";
print "Report Status: ".($reportStatus||"Not Defined")."\n";
print "Report Type: ".($reportType||"Not Defined")."\n";

if (!defined $inputFile) {
	die("Missing Input file\n");
}
if (!defined $outputFile) {
	die("Missing Output file");
}

my $br = "\\\\";

print("Writting Csv\n");
my $csv = Text::CSV::Encoded->new ({ encoding  => "utf8", eol => $/ }) or die "Cannot use CSV: ".Text::CSV->error_diag ();
open my $fhcsv, ">:raw", $outputFile;

print("Building header\n");
my @names = ("summary", "description");
if(defined $reporter) {
	push (@names, "reporter");
}
if(defined $reportStatus) {
	push (@names, "status");
}
if(defined $reportType) {
	push (@names, "type");
}
$csv->print($fhcsv, \@names);

print("Reading Xml output\n");
my($xp) = XML::XPath->new($inputFile);
my(@rules) = $xp->findnodes( '/gendarme-output/results/rule' );

foreach my $rule ( @rules ) {
	if (!defined $rule) {
		next;
	}
	
	my ($problem, $solution, $type, $assembly);
	my @targets;
	
	my $summary = $rule->getAttribute ("Name");
	my $uri = "[[".$rule->getAttribute ("Uri")."]]";
	
	foreach my $field ( $rule->getChildNodes() ) {
		if (!defined $field || !defined $field->getName()) {
			next;
		}
		if($field->getName() eq "problem") {
			$problem = "Problem: ".$field->string_value();
			next;
		}
		if($field->getName() eq "solution") {
			$solution = "Solution: ".$field->string_value();
			next;
		}
		if($field->getName() eq "target") {
			$type = "Type: ".$field->getAttribute ("Name");
			$assembly = "Assembly: ".$field->getAttribute ("Assembly");
			
			foreach my $target ( $field->getChildNodes() ) {
				if (!defined $target || !defined $target->getName() ) {
					next;
				}
				if($target->getName() eq "defect") {
					my ($severity, $location, $source,$fix);
					$severity = "Severity: ".$target->getAttribute ("Severity");
					$location = "Location: ".$target->getAttribute ("Location");
					$source = "Source: ".$target->getAttribute ("Source");
					#Confidence="Total"
					
					$fix = "Proposed fix: ".$target->string_value();
					
					push(@targets, join($br,$location,$source,$severity,$fix));
				}
			}
		}
	}
	
	my $joinTargets = join($br, @targets);
	my $description = join($br, $type, $assembly, $problem, $solution, $br, $joinTargets, $br, $uri);
	
	my @row = (encode('UTF-8',$summary), encode('UTF-8',$description));
	if(defined $reporter) {
		push (@row, $reporter);
	}
	if(defined $reportStatus) {
		push (@row, $reportStatus);
	}
	if(defined $reportType) {
		push (@row, $reportType);
	}
	$csv->print($fhcsv, \@row);
}
