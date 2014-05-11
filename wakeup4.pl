#!/usr/bin/perl

#Wakeup by Stephen Wetzel Sept 6th 2012
#Gradual volume ramp up script for MPD.  Used as my alarm.

#use strict;
#use warnings;
use Cwd;

#these settings should be set by the user:
my $rate = 1.03; #change in wait between each step, 1.03 = 103%
my $wakeUpStep = 80; #step on which wakeup typically occurs (volume ranges 0-100)
my $wakeUpTime = 15; #time in minutes a wakeup should take (from 0 volume to step listed above).

#variables used by script
my $debug=0; #set to 1 to get output, and prevent actual volume messing with
my $pause; #time in seconds between volume up steps
my $confirm=0; #flag, is time is ok
my $sleep; #time in seconds to sleep for
my $endTime; #wakeup time
my $time; #current time
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
my $wakeUpTimesec = $wakeUpTime * 60; #wakeup time converted to seconds

#check for command line argument
#this allows the script to be controlled by cron, pass 0 and it will begin the volume ramp up immediately
if (@ARGV) 
{# if a command line argument was passed we will wait that number of hours instead
	print "\npassed: ".$ARGV[0];
	$sleep = $ARGV[0]; #time in hours
	$confirm = 1; #won't enter user input loop
	chomp($sleep); #newlines
	$sleep *= 60*60; #convert hours to seconds
}

#user input loop
#runs if we did not get a command line argument
while ($confirm == 0)
{#main loop, will run until user gives us a valid number of hours to sleep for
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time); #current time
	$time = sprintf("%4d-%02d-%02d %02d:%02d:%02d\n", $year+1900, $mon+1, $mday, $hour, $min, $sec);
	print "\nIt is currently: $time";
	print "\nEnter number of hours to wait ";
	$sleep = <stdin>; #time in hours to sleep, we will make it seconds later
	chomp($sleep); #newlines
	print "\nIn $sleep hours it will be ";
	$sleep *= 60*60; #convert from hours to seconds
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time+$sleep); #wakeup time
	$endTime = sprintf("%4d-%02d-%02d %02d:%02d:%02d\n", $year+1900, $mon+1, $mday, $hour, $min, $sec);
	print "$endTime";
	print "\nEnter 1 to accept or 0 to change time ";
	$confirm = <stdin>; #confirm this is the correct wakeup time
	chomp($confirm); #newlines
}

#display the wakeup time and wait
system("clear");
print "Current - $time";
print "Wake up - $endTime";
$sleep -= $wakeUpTimesec; #deduct the wakeup time from sleep time
print "\nGoing to sleep for ", $sleep/3600, " hours, followed by a $wakeUpTime minute wakeup \n";

#go to sleep
if ($sleep<1) {$sleep=0;} #ensure a positive sleep time
sleep ($sleep);

#wakeup time
if (!$debug)
{#all the stuff that messes with mpd and volumes, skip in debug mode
	print "Wakeup!\n";
	system "mpc stop"; #stop current music
	
	system "amixer set Master 0"; #set system volume to 0
	system "mpc play"; #start music, volume at 0
	#can only set mpc volume while it is playing
	sleep(1);
	system "mpc volume 0"; #set's mpd volume to 0
	system "unmuteall.sh"; #unmutes system volume
	
}


my $tempWakeupTime = (1-($rate**$wakeUpStep))/(1-$rate); #geometric series sum formula
#we now know how long a wakeup will take with 1 sec starting interval, we will find the scaler needed for desired length
$pause=($wakeUpTimesec/$tempWakeupTime); #the begining pause length between steps
(print "\nWUTS - $wakeUpTimesec, TWUT - $tempWakeupTime \n") if ($debug);

for (my $ii = 1; $ii < 125; $ii++)
{#step up volume at our rate
	$pause *= $rate; #gradually increase pause between steps
	$pause = int($pause*1000)/1000; #round to 3 decimals places, just to keep the display nice
	print "\nStep - $ii, Pause - $pause\n";
	print "\nNew";
	#this ensures mpc hasn't been paused, and is playing during the rampup
	(system "mpc play") if (!$debug);
	(system "amixer set Master 1+") if (!$debug  && $ii % 2 == 0); #only 64 master volume steps
	(system "mpc volume +1") if (!$debug);
	sleep($pause + 0.5); #sleep only takes the int, so we add 0.5 so it rounds rather than truncates to int
}
