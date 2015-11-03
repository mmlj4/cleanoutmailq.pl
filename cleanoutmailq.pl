#!/usr/bin/perl

# File: cleanoutmailq.pl
# Version: 0.1
# Author: Joey Kelly
# GPL version 2
#
# If your postfix mailq is filled with bogus bounces (see typical entry at the end of this file),
# run this script to nuke them. You're given the option of what to do with each entry,
# but obvious spam is simply deleted from the queue.

use strict;
use warnings;

my $mailq = '/usr/bin/mailq';
my @mailq = `$mailq`;

# header and footer, handle these
#-Queue ID- --Size-- ----Arrival Time---- -Sender/Recipient-------
#-- 1578 Kbytes in 352 Requests.
shift @mailq;               # gets rid of the column header
my $summary = pop @mailq;   # gets rid of the summary
print "$summary\n";

my $line;
my ($queueid, $email);
my @token;
my @ip;
foreach (@mailq) {
  chomp;
  $line++;
  # get a candidate queue id
  my @trash;
  if ($line == 1) {
    ($queueid,@trash) = split ' ', $_;
    chomp $queueid;
  }
  # weed out everything except apparent bogus SMTP targets
  if ( ($line == 2) && $queueid && ($_ =~ /Connection refused/) ) {
    $_ =~ s/\t/ /g;   # do we even have tabs in the output?
    $_ =~ s/^ +//g;
    my @line2 = split ' ', $_;
    @token = split '\[', $line2[2];
    @ip = split '\]', $token[1];
  }
  # LATER: store the IP address if this entry is a candidate for nuking
  if ( ($line == 3) && $queueid ) {
    $_ =~ s/^ +//g;
    $_ =~ s/ +$//g;
    $email = $_;
  }
  # this should be a blank line between queue entries
  if ($line == 4) {
    # refactor this, put in an array maybe?
    if ($email =~ 'info@'
        || $email =~ 'information@'
        || $email =~ 'admin@'
        || $email =~ 'clinic@'
        || $email =~ 'health@'
        || $email =~ 'noreply@'
        || $email =~ 'blog@'
        || $email =~ 'mayo@') {
      # we're just going to help everybody out and trash this as spam
      system "postsuper -d $queueid";
      print "\n";
    } else {
      print "$token[0]\t$ip[0]\t$email\n";
      print "\tdelete out of the queue? yes/no/quit (y/N/q)?\n";
      my $action = <STDIN>;
      chomp $action;
      system "postsuper -d $queueid" if $action eq 'y';
      die "user bailed out\n" if $action eq 'q';
      print "\n";
    }
    $line = 0;
    $queueid = 0;
  }

}

# typical mailq entry
#4129A38226     3920 Sun Oct 18 09:25:12  MAILER-DAEMON
#(connect to job.hiredbythebest5companies.com[85.114.130.146]:25: Connection refused)
#                                         info@hiredbythebest5companies.com
#
