#!/usr/bin/perl -w

# generates  compact  routes raw  files  from  the  data retrieved  by
# spider,  but for all  stops, not  just ones  with times.   For those
# without time  information, puts time  range, also includes  an extra
# counter so the planner is certain that it is the same trip of a bus,
# i.e. that  it is not  just two of  the same bus number  scheduled to
# arrive at the same location. not really but just in case.

# 0 - short, 1 - long

my $outputfile = shift;
my $restriction = shift;

die "Usage: gen-all.pl <outputfile> <restriction>" unless $outputfile;

my $OUT;
open(OUT,">$outputfile") or die "cannot open outputfile $outputfile";

my $format = 0;
my $count = 0;
my %locationhash;

use Data::Dumper;

my $cnt = 0;

foreach my $file (split /\n/,`find routes/pittsburgh`) {
  if (-f $file and ($file =~ /routes\/pittsburgh\/([^\/]+)\/(Inbound|Outbound)\/(Weekday|Holiday|Saturday|Sunday)\/([0-9]{1,2}:[0-9]{2}[ap])$/)) {
    my $route = $1;
    my $direction = $2;
    my $day = $3;
    my $time = $4;
    # print "<$route><$direction><$day><$time>\n";

    if ($restriction) {
      next unless $route =~ /$restriction/;
    }

    if ($direction =~ /Inbound/) {
      $direction = "I";
    } elsif ($direction =~ /Outbound/) {
      $direction = "O";
    }

    if ($day =~ /Sunday/) {
      $day = "S";
    } elsif ($day =~ /Saturday/) {
      $day = "Sa";
    } elsif ($day =~ /Weekday/) {
      $day = "W";
    } elsif ($day =~ /Holiday/) {
      $day = "H";
    }

    my $contents = `cat $file`;
    $contents =~ s/<TABLE><TR><TD><B>Trip<\/TD><TD><B>Time<\/TD><TD><B>Stop Location<\/TD><\/TR>//;
    $contents =~ s/\s*<\/table>\s*//s;

    my $last;
    my $ll;
    my $lt;
    foreach my $sect (split /[\n\r]\s[\n\r]/,$contents) {
      #print "<<<$sect>>>\n\n\n\n";
      if ($sect =~ /<td>.*?<td> \&nbsp; \&nbsp;(.*?)<\/td>.*?<td>\&nbsp; \&nbsp;(.*?)<\/td>/s) {
	if (! $format) {
	  if (defined $1 and $1 ne "") {
	    if (defined $lt and $lt ne "" and defined $ll) {
	      print OUT "$route,$day,$direction,".Compress($ll).",".Compress($2).",$lt,$1,$cnt\n";
	    }
	    $lt = $1;
	    $ll = $2;
	  } else {
	    if (defined $lt and $lt ne "" and defined $ll) {
	      print OUT "$route,$day,$direction,".Compress($ll).",".Compress($2).",$lt,,$cnt\n";
	    }
	    $ll = $2;
	  }
	} else {
	  print OUT "<$last,$2>\n";
	}
      } else {
	print OUT "<<<ERROR: $sect>>>\n";
      }
    }
    ++$cnt;
  }
}

sub Compress {
  my $item = shift;
  # return $item;
  if (defined $locationhash{$item}) {
    return $locationhash{$item};
  } else {
    $locationhash{$item} = $count++;
    return $locationhash{$item};
  }
}

close(OUT);
open(OUT,">$outputfile.lh") or die "cannot open locationhash outputfile $outputfile.lh";
print OUT Dumper({%locationhash});
close(OUT);

system "gzip $outputfile";
