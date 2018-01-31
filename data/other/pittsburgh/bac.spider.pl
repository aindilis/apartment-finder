#!/usr/bin/perl -w

use WWW::Mechanize;
use Data::Dumper;

# spider is the  program which spiders the port  authority website and
# outputs a series of html files  for the other tools to extract route
# information from.

my $date = $ARGV[0] || `date '+%Y%m%d'`;
chomp $date;

my $rootdir = `pwd`;
chomp $rootdir;
$rootdir .= "/routes/$date";
if (! -d $rootdir) {
  system "mkdirhier \"$rootdir\"";
}

my $url = "http://www.portauthority.org/ride/pgSchedules.asp";
my $mech = WWW::Mechanize->new();

$mech->get( $url );
my $search = $mech->form_number(2);

my %values;
foreach my $input (@{$search->{inputs}}) {
  $values{$input->{name}} = $input->{value_names};
}

my @tmp;
foreach my $item (@{$values{selectRoute}}) {
  push @tmp, $item;
}

print Dumper($values{selectRoute});

$values{selectRoute} = \@tmp;
my @tmp2;
foreach my $item (@{$values{SelectTime}}) {
  if ($item ne "") {
    push @tmp2, $item;
  }
}
$values{SelectTime} = \@tmp2;

# $values{selectDirection} = ["Outbound"];
# $values{SelectTime} = ["5", "6", "7"];

my @list = ([]);
# foreach my $key (keys %values) {
foreach my $key (qw{selectRoute selectDirection selectDay selectToD SelectTime}) {
  my @list2;
  if (@{$values{$key}}) {
    foreach my $elt (@list) {
      foreach my $value (@{$values{$key}}) {
	push @list2, [@{$elt},$key,$value];
      }
    }
    @list = @list2;
  }
}

my $mech2 = $mech;
my $size = scalar @list;
my $count = 0;
my %visited;
foreach my $l (@list) {
  ++$count;
  if (1) {			#($count < 30205) {
    my %hashref = @{$l};
    print Dumper(%hashref);
    my $mech2 = WWW::Mechanize->new();
    if (1) {
      print $url."\n";
    } else {
      $mech2->get( $url );
      my $res = $mech2->submit_form(form_number => 2,
				    fields => \%hashref,
				    button => "Submit");

      my $content = $res->content();
      print "$count/$size\n";

      if ($content =~ /Your Search Returned No Results/) {
	print "Fail\n";
      } else {
	# now we must look deeper and get the results
	print "Success\n";

	# now we want to extract the relevant information
	# "http://www.portauthority.org/ride/pgResultsOneTrip.asp?pattern=I%20&seq=421"
	foreach my $link ($mech2->links()) {
	  if ($link->[0] =~ /\/ride\/pgResultsOneTrip.asp\?pattern=/) {
	    my $route = $hashref{selectRoute};
	    $route =~ s/^(\S+) - .*/$1/;
	    my $dirhier = "$rootdir/".
	      $route
		."/".
		  $hashref{selectDirection}
		    ."/".
		      $hashref{selectDay};
	    my $outfile = "$dirhier/".$link->[1];
	    print "<<<$outfile>>>\n";
	    if ((! defined $visited{$outfile}) and
		(! -f $outfile)) {
	      # if ($link->[0] =~ /\/ride\/pgResultsOneTrip.asp\?pattern=I/) {
	      # go there and download links
	      my $turl = "http://www.portauthority.org".$link->[0];
	      $mech2->get( $turl );
	      my $contents = $mech2->content();
	      # print "$contents\n";
	      if ($contents =~ /(<TABLE><TR><TD><B>Trip<\/TD><TD><B>Time<\/TD><TD><B>Stop Location<\/TD><\/TR>.*?<\/table>)/is) {
		my $routecontent = $1;
		my $OUT;
		system "mkdirhier $dirhier";
		open (OUT, ">$outfile");
		print OUT $routecontent;
		close (OUT);
		$visited{$outfile} = 1;
	      } else {
		print "error\n";
	      }
	    }
	  }
	}
      }
    }
  }
}


sub ProcessSection {
  my $contents = shift;
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
}
