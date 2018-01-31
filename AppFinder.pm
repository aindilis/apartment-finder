package AppFinder;

use BOSS::Config;
use Geo::Distance;
use Manager::Dialog qw(Message);
use PerlLib::Geo;
use PerlLib::Scraper::Craigslist::Apartment;

use Data::Dumper;

use Class::MethodMaker
  new_with_init => 'new',
  get_set       =>
  [

   qw / Config Results Geo ScoreHash WorkAddressInfo /

  ];

sub init {
  my ($self,%args) = @_;
  $specification = "
	-u [<host> <port>]	Run as a UniLang agent

	--update		Update apartment data
	--gen			Generate website of best apartments
";
  # $UNIVERSAL::systemdir = ConcatDir(Dir("internal codebases"),"appfinder");
  $self->Config(BOSS::Config->new
		(Spec => $specification,
		 ConfFile => ""));
  my $conf = $self->Config->CLIConfig;
  if (exists $conf->{'-u'}) {
    $UNIVERSAL::agent->Register
      (Host => defined $conf->{-u}->{'<host>'} ?
       $conf->{-u}->{'<host>'} : "localhost",
       Port => defined $conf->{-u}->{'<port>'} ?
       $conf->{-u}->{'<port>'} : "9000");
  }
}

sub Execute {
  my ($self,%args) = @_;
  my $conf = $self->Config->CLIConfig;
  if (exists $conf->{'--update'}) {
    $self->UpdateApartmentData;
  } elsif (exists $conf->{'--gen'}) {
    $self->ProcessApartmentData;
  }
  if (exists $conf->{'-u'}) {
    # enter in to a listening loop
    while (1) {
      $UNIVERSAL::agent->Listen(TimeOut => 10);
    }
  }
  if (exists $conf->{'-w'}) {
    Message(Message => "Press any key to quit...");
    my $t = <STDIN>;
  }
}

sub ProcessMessage {
  my ($self,%args) = @_;
  my $m = $args{Message};
  my $it = $m->Contents;
  if ($it) {
    if ($it =~ /^echo\s*(.*)/) {
      $UNIVERSAL::agent->SendContents
	(Contents => $1,
	 Receiver => $m->{Sender});
    } elsif ($it =~ /^(quit|exit)$/i) {
      $UNIVERSAL::agent->Deregister;
      exit(0);
    }
  }
}

sub UpdateApartmentData {
  my ($self,%args) = @_;
  my $apt = PerlLib::Scraper::Craigslist::Apartment->new;
  $apt->UpdateSource;
}

sub ProcessApartmentData {
  my ($self,%args) = @_;
  my $workaddress;
  my $worklatlong;
  my $dogeo = 1;

  if (! -f "results.pl") {
    Message(Message => "Loading Geo");
    $self->Geo(PerlLib::Geo->new);

    Message(Message => "Calculating");
    $workaddress = "chicago at noble";
    $worklatlong = $self->Geo->GetLatLongForAddress($workaddress);
    $self->WorkAddressInfo({WorkAddress => $workaddress, WorkLatLong => $worklatlong});
    print Dumper($self->WorkAddressInfo);
    $self->ScoreHash({
		      tele => 1,
		      email => 1,
		     });
    $self->Results([]);
    my $scores = {};
    my $i = 0;

    foreach my $f (split /\n/, `find data/source/CraigsList`) {
      if (-f $f) {
	my $c = `cat $f`;
	my $e = $self->Process
	  (Contents => $c,
	   File => $f);
	push @{$self->Results}, $e;
      }
    }

    # save the results file
    my $OUT;
    if (open(OUT,">results.pl")) {
      print OUT Dumper($self->Results);
      close(OUT);
    } else {
      print "Can't open results.pl for writing\n";
    }
  } else {
    $self->Results(eval `cat results.pl`);
  }

  # save the results html file
  if (open(OUT,">results.html")) {
    print OUT $self->PrintOutput;
    close(OUT);
  } else {
    print "Can't open results.html for writing\n";
  }
}

sub Process {
  my ($self,%args) = @_;
  return unless $args{File} =~ /chicago.craigslist.org/;
  my $c = $args{Contents};
  # extract information
  my $i = {
	   # Contents => $args{Contents},
	   File => $args{File},
	  };

  # telephone number
  if ($c =~ /(([0-9]{3}.?)?[0-9]{3}.?[0-9]{4})/) {
    my $h = {};
    my @res;
    my @links = $c =~ /(([0-9]{3}.?)?[0-9]{3}.?[0-9]{4})/g;
    foreach my $link (@links) {
      if (defined $link and $link =~ /.{7}/) {
	$h->{$link}++;
      }
    }
    foreach my $key (keys %$h) {
      push @res, $key if (exists $h->{$key} and $h->{$key} < 5);
    }
    $i->{tele} = \@res;
  }

  # rent
  if ($c =~ /\$([0-9]+)/) {
    $i->{rent} = $1;
  }

  # location

  # ./chicago.craigslist.org/apa/150685621.html:Deming at Clark&nbsp;&nbsp;&nbsp;<font size="-1"><a target="_new" href="http://maps.google.com/?q=loc%3A+Deming+at+Clark+Chicago+IL+US">google map</a>&nbsp;&nbsp;&nbsp;<a target="_new" href="http://maps.yahoo.com/maps_result?addr=Deming+at+Clark&amp;csz=Chicago+IL&amp;country=US">yahoo map</a></font><br>

  foreach my $l (split /\n/, $c) {
    if ($l =~ /maps.google/) {
      if ($l =~ /^(.*?)\&nbsp\;.*(http:\/\/maps.google.com\/[^\"]+)/) {
	$i->{locname} = $1;
	$i->{loclink} = $2;
      }
    }
  }

  # email address

  system "rm /tmp/dump";
  system "lynx -dump $args{File} > /tmp/dump";
  my $dump = `cat /tmp/dump`;
  # Reply to: [11]tim.ewers@cbexchange.com
  if ($dump =~ /Reply to: \[\d+\](.*)\s*$/m) {
    $i->{email} = $1;
  }
  my $e =  {
	    Info => $i,
	   };
  my $score = 0;

  # if it has a phone number
  foreach my $key (keys %{$self->ScoreHash}) {
    if (ref $e->{Info}->{$key} eq "ARRAY") {
      if (@{$e->{Info}->{$key}}) {
	$score += $self->ScoreHash->{$key};
      }
    } else {
      if (exists $e->{Info}->{$key}) {
	$score += $self->ScoreHash->{$key};
      }
    }
  }

  $e->{latlong} = $self->Geo->GetLatLongForAddress($e->{Info}->{locname});
  # compute distance here
  if ($e->{latlong} !~ /unknown/) {
    $e->{distance} = $self->Geo->CalculateDistanceBetweenLatLongs
      (
       Type => "streetwise",
       LatLong1 => $self->WorkAddressInfo->{WorkLatLong},
       LatLong2 => $e->{latlong},
      );
    # if ($e->{distance} == 0) {
    # $e->{distance} = 999;
    # }
  }

  # now add distances and cost
  if (exists $e->{distance}) {
    $score -= 10 * $e->{distance};
  } else {
    $score -= 10 * 10;
  }
  if (exists $e->{Info}->{rent}) {
    $score -= $e->{Info}->{rent} / 50.0;
  } else {
    $score -= 20;
  }
  $e->{Info}->{Score} = $score;
  print Dumper($e);
  return $e;
}

sub PrintOutput {
  my ($self,%args) = @_;
  my $string = "<html><body><table border=2>\n";
  $string .= "<tr><td>Link</td><td>Score</td><td>Rent</td><td>Distance</td><td>Email</td><td>Phone</td></tr>\n";
  foreach my $e (sort {$b->{Info}->{Score} <=> $a->{Info}->{Score}} @{$self->Results}) {
    my $i = $e->{Info};
    #   print "<tr><td><a href=\"file:///home/andrewd/org/systems/apartment/CraigsList/".
    #     $i->{File}."\">".$i->{File}."</a></td><td>".
    #       $scores->{$key}."</td><td>".
    # 	$i->{rent}."</td><td>".
    # 	  $e->{distance}."</td><td>".
    # 	    $i->{email}."</td><td>".
    # 	      join(", ",@{$i->{tele}})."</td></tr>\n";
    my @tele;
    if (exists $i->{tele} and scalar @{$i->{tele}}) {
      push @tele, @{$i->{tele}};
    }
    if ($e->{distance}) {
      $string .= sprintf("<tr><td>%3.3f</td><td>".
			 "\$%i</td><td>%3.3f</td><td>%s</td><td>%s</td>".
			 "<td><a href=\"%s\">%s</a></td>".
			 "</tr>\n",
			 $i->{Score} || -999,
			 $i->{rent} || 999,
			 $e->{distance} || 999,
			 $i->{email} || "",
			 join(", ",@tele),
			 $i->{File} || "",
			 $i->{File} || "",
			);
    }
  }
  $string .= "</table></body></html>\n";
  return $string;
}

1;
