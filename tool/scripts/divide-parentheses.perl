#!/usr/bin/env perl

# S-ID�դ��Υե����ޥåȤ����ϤȤ��ơ���̤���ʸ�Ȥ���ʬ�䤹��
# �����ϥ�����: euc-jp

use encoding 'euc-jp';
use SentenceFormatter;
use strict;

my $formatter = new SentenceFormatter({'divide_paren' => 1, 'include_paren' => 1, 'save_all' => 1});

my ($sid, $comment);
while (<STDIN>) {
    if (/^\# S-ID:(\S+)(.*)/) {
	$sid = $1; # . '-01';
	$comment = $2;
	$comment =~ s/^\s+//;
    }
    elsif ($sid) {
	chomp;
	# ��ʸ������̤ν���
	my ($main, @parens) = $formatter->FormatSentence($_, $sid);

	# ��ʸ��ɽ��
	&print_sentence($main);

	# ���ʸ��ɽ��
	for my $paren (@parens) {
	    &print_sentence($paren);
	}

	$sid = '';
    }
}

sub print_sentence {
    my ($ref) = @_;

    printf "# S-ID:%s", $ref->{sid};
    printf " %s", $ref->{comment} if $ref->{comment};
    print "\n";
    print $ref->{sentence}, "\n" if $ref->{sentence};
}
