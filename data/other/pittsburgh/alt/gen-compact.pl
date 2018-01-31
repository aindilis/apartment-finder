#!/usr/bin/perl -w

# generates compact routes raw files from the data retrieved by spider

# gen-compact.pl  generates a more  compact version  of the  routes by
# substituting numbers for locations, and printing and index for this.
# this may save some time, I haven't tested

# 0 - short, 1 - long
my $format = 0;
my $count = 0;
my %locationhash;

foreach my $file (split /\n/,`find routes/pittsburgh`) {
  if (-f $file and ($file =~ /routes\/pittsburgh\/([^\/]+)\/(Inbound|Outbound)\/(Weekday|Holiday|Saturday|Sunday)\/([0-9]{1,2}:[0-9]{2}[ap])$/)) {
    my $route = $1;
    my $direction = $2;
    my $day = $3;
    my $time = $4;
    # print "<$route><$direction><$day><$time>\n";

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
    my $ll, $lt;
    foreach my $sect (split /[\n\r]\s[\n\r]/,$contents) {
      #print "<<<$sect>>>\n\n\n\n";
      if ($sect =~ /<td>.*?<td> \&nbsp; \&nbsp;(.*?)<\/td>.*?<td>\&nbsp; \&nbsp;(.*?)<\/td>/s) {
	if (! $format) {
	  if (defined $1 and $1 ne "") {
	    if (defined $lt and $lt ne "" and defined $ll) {
	      # print "<$1,$2>\n";
	      print "$route, $day, $direction, ".Compress($ll).", ".Compress($2).", $lt, $1\n";
	    }
	    $lt = $1;
	    $ll = $2;
	  }
	} else {
	  print "<$last,$2>\n";
	}
      } else {
	print "<<<ERROR: $sect>>>\n";
      }
    }
  }
}

sub Compress {
  my $item = shift;
  if (defined $locationhash{$item}) {
    return $locationhash{$item};
  } else {
    $locationhash{$item} = $count++;
    return $locationhash{$item};
  }
}

print Dumper(%locationhash);
