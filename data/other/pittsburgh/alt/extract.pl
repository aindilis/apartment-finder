#!/usr/bin/perl -w

my $file = $ARGV[0];
my $contents = `cat $file`;
$contents =~ s/<TABLE><TR><TD><B>Trip<\/TD><TD><B>Time<\/TD><TD><B>Stop Location<\/TD><\/TR>//;
$contents =~ s/\s*<\/table>\s*//s;


my $last;
foreach my $sect (split /[\n\r]\s[\n\r]/,$contents) {
#print "<<<$sect>>>\n\n\n\n";

  if ($sect =~ /<td>.*?<td> \&nbsp; \&nbsp;(.*?)<\/td>.*?<td>\&nbsp; \&nbsp;(.*?)<\/td>/s) {
    $last = $1 if $1;
    print "<$last,$2>\n";
  } else {
    print "error\n";
  }
}
