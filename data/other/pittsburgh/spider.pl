#!/usr/bin/perl -w

use WWW::Mechanize;
use Data::Dumper;

# spider is the  program which spiders the port  authority website and
# outputs a series of html files  for the other tools to extract route
# information from.

my $date = $ARGV[0] || `date '+%Y%m%d'`;
chomp $date;

# this is to correct for when we have really stupid mistakes in our
# spider program - to patch the missing routes
my $startbus = $ARGV[1] || undef;
my $endbus = $ARGV[2] || undef;

my $rootdir = `pwd`;
chomp $rootdir;
$rootdir .= "/routes/$date";
if (! -d $rootdir) {
  system "mkdirhier \"$rootdir\"";
}

my $url = "http://www.portauthority.org/ride/pgSchedules.asp";
my $mech = WWW::Mechanize->new();
$mech->agent_alias( 'Windows IE 6' );
my $mech2 = WWW::Mechanize->new();
$mech2->agent_alias( 'Windows IE 6' );

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

my $size = scalar @list;
my $count = 0;
my $temphash = {};
my %visited;
print "####################\n";
my $begin = 0;
foreach my $l (@list) {
  ++$count;
  # if ($count > 10000) {
    if (1) {
    my %hashref = @{$l};
    if ($endbus and $hashref{selectRoute} =~ /$endbus/) {
      exit(0);
    }
    if ($begin || ! $startbus || $hashref{selectRoute} =~ /$startbus/) {
      $begin = 1;
      print Dumper(%hashref);
      $mech = WWW::Mechanize->new();
      $mech->agent_alias( 'Windows IE 6' );
      $mech->get( $url );
      my $res = $mech->submit_form(form_number => 2,
				   fields => \%hashref,
				   button => "Submit");

      my $content = $res->content();
      $temphash->{$content} = 1;
      my $keys = scalar keys %$temphash;
      print "$keys keys\n";
      print "$count/$size\n";

      if ($content =~ /Your Search Returned No Results/) {
	# print $content."\n";
	print "Fail\n";
      } else {
	# now we must look deeper and get the results
	print "Success\n";

	# now we want to extract the relevant information
	# "http://www.portauthority.org/ride/pgResultsOneTrip.asp?pattern=I%20&seq=421"
	foreach my $link ($mech->links()) {
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
	      $turl =~ s/\s/%20/g;
	      print "$turl\n";
	      $mech2 = WWW::Mechanize->new();
	      $mech2->agent_alias( 'Windows IE 6' );
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
		my $routecontent = $1;
		my $OUT;
		system "mkdirhier $dirhier";
		open (OUT, ">$outfile");
		print OUT $contents;
		close (OUT);
		print "Did not match expected table format\n";
	      }
	    }
	  }
	}
      }
      $mech->back();
      # $mech->_pop_page_stack();
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
