use strict;
use warnings;

BEGIN {
  package Test::Scope::Guard;
  sub new { my ($class, $code) = @_; bless [$code], $class; }
  sub DESTROY { my $self = shift; $self->[0]->() }
}

print "1..8\n";

our $had_error;

# try to ensure this is the last-most END so we capture future tests
# running in other ENDs
require B;
my $reinject_retries = my $max_retry = 5;
my $end_worker;
$end_worker = sub {
  my $tail = (B::end_av()->ARRAY)[-1];
  if (!defined $tail or $tail == $end_worker) {
    $? = $had_error || 0;
    $reinject_retries = 0;
  }
  elsif ($reinject_retries--) {
    push @{B::end_av()->object_2svref}, $end_worker;
  }
  else {
    print STDERR "\n\nSomething is racing with @{[__FILE__]} for final END block definition - can't win after $max_retry iterations :(\n\n";
    require POSIX;
    POSIX::_exit( 255 );
  }
};
END { push @{B::end_av()->object_2svref}, $end_worker }

sub ok ($$) {
  $had_error++, print "not " if !$_[0];
  print "ok";
  print " - $_[1]" if defined $_[1];
  print "\n";
}

END {
  ok( ! Devel::GlobalDestruction::XS::in_global_destruction(), 'Not yet in GD while in END block 2' )
}

ok( eval "use Devel::GlobalDestruction::XS; 1", "use Devel::GlobalDestruction::XS" );

ok( defined prototype \&Devel::GlobalDestruction::XS::in_global_destruction, "defined prototype" );

ok( prototype \&Devel::GlobalDestruction::XS::in_global_destruction eq "", "empty prototype" );

ok( ! Devel::GlobalDestruction::XS::in_global_destruction(), "Runtime is not GD" );

our $sg1 = Test::Scope::Guard->new(sub { ok( Devel::GlobalDestruction::XS::in_global_destruction(), "Final cleanup object destruction properly in GD" ) });

END {
  ok( ! Devel::GlobalDestruction::XS::in_global_destruction(), 'Not yet in GD while in END block 1' )
}

our $sg2 = Test::Scope::Guard->new(sub { ok( ! Devel::GlobalDestruction::XS::in_global_destruction(), "Object destruction in END not considered GD" ) });
END { undef $sg2 }
