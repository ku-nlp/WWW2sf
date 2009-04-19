package Emoticon;

use utf8;
use Encode;
use strict;
use File::Basename;

# read the emoticon dictionary
our $EmoticonDic = require sprintf("%s/Emoticon.dic", dirname($INC{'Emoticon.pm'}));

sub new {
    my ($class, $opt) = @_;

    # decode the emoticon dictionary
    map {$_ = decode('utf8', $_) unless (utf8::is_utf8($_))} @$EmoticonDic;

    my $this = {opt => $opt, 
		# emoticon_pattern => decode('utf8', sprintf("(?:%s)", join('|', @{$EmoticonDic}))), 
	       };
    bless $this;
}

sub check_emoticon {
    my ($this, $arg) = @_;
    my (@check_array, $char_array, $str);
    my $char_point = 0;

    if (ref($arg)) { # ARRAY reference
	$str = join('', @{$arg});
	$char_array = $arg;

    }
    else { # string
	$str = $arg;
	$char_array = [split(//, $arg)];
    }

    # initialization
    for my $i (0 .. scalar(@{$char_array}) - 1) {
	$check_array[$i] = 0;
    }

# このようにすると、もっとも長い顔文字がとれない (部分マッチしてしまう)
#     while ($str =~ /^(.*)($this->{emoticon_pattern})/go) {
# 	my ($pre_str, $emoticon) = ($1, $2);
# 	for my $i ($char_point .. $char_point + length($emoticon) - 1) {
# 	    $check_array[$i] = 1;
# 	}
# 	$char_point += length($pre_str) + length($emoticon);
#     }

    my $pos = 0;
    while ($pos < scalar(@check_array)) {
	# find the longest emoticon
	my $matched_emoticon;
	my $max_length = 0;
	for my $emoticon (@{$EmoticonDic}) {
	    if (substr($str, $pos, length($emoticon)) eq $emoticon) {
		my $len = length($emoticon);
		if ($max_length < $len) {
		    $max_length = $len;
		    $matched_emoticon = $emoticon;
		}
	    }
	}

	if ($matched_emoticon) {
	    # turn on a flag for the emoticon area
 	    for my $i ($pos .. $pos + $max_length - 1) {
 		$check_array[$i] = 1;
 	    }
	    $pos += $max_length;
	}
	else {
	    $pos++;
	}
    }

    # print for debug
    if ($this->{opt}{debug}) {
	for my $i (0 .. scalar(@check_array) - 1) {
	    printf "%02d ", $i;
	}
	print "\n";
	for my $i (0 .. scalar(@check_array) - 1) {
	    printf "%d  ", $check_array[$i];
	}
	print "\n";
	for my $i (0 .. scalar(@check_array) - 1) {
	    printf "%s ", $char_array->[$i];
	}
	print "\n";
    }

    return @check_array;
}

1;
