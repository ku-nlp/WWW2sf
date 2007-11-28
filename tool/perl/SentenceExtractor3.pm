package SentenceExtractor3;

# 文章 -> 文 フィルタ
# from TextExtor.pm (Japanese), sentence-boundary.pl (English)

# $Id$

use vars qw($open_kakko $close_kakko $period $dot @honorifics);
# use strict;
use utf8;
use CharacterRange;
use Encode;

$open_kakko  = qr/（|〔|［|｛|＜|≪|「|『|【|\(|\[|\{/;
$close_kakko = qr/）|〕|］|｝|＞|≫|」|』|】|\)|\]|\}/;

$period = qr/。|？|！|♪|…/;
$dot = qr/．/;
# $alphabet_or_number = qr/\xa3(?:[\xc1-\xda]|[\xe1-\xfa]|[\xb0-\xb9])/;
$itemize_header = qr/\p{alphabet_or_number}．/;

@honorifics = qw(Adj. Adm. Adv. Asst. Bart. Brig. Bros. Capt. Cmdr. Col. Comdr. Con. Cpl. Dr. Ens. Gen. Gov. Hon. Hosp. Insp. Lt. M. MM. Maj. Messrs. Mlle. Mme. Mr. Mrs. Ms. Msgr. Op. Ord. Pfc. Ph. Prof. Pvt. Rep. Reps. Res. Rev. Rt. Sen. Sens. Sfc. Sgt. Sr. St. Supt. Surg. vs. v.);

sub new
{
   my($this, $paragraph, $language) = @_;

   $this = {paragraph => $paragraph, 
	    sentences => []};

   bless($this);

   if ($language eq 'english') {
       @{$this->{sentences}} = &SplitEnglish($paragraph);
   }
   else {
       @{$this->{sentences}} = &SplitJapanese($paragraph);
   }

   return $this;
}

sub GetSentences
{
    my ($this) = @_;

    return @{$this->{sentences}};
}


sub FixParenthesis {
    my ($slist) = @_;

    for my $i (0 .. scalar(@{$slist} - 1)) {
	# 1つ目の文以降で、閉じ括弧が文頭にある場合は、閉じ括弧をとって前の文にくっつける
	if ($i > 0 && $slist->[$i] =~ /^($close_kakko)(.*)/) {
	    $slist->[$i - 1] .= $1;
	    $slist->[$i] = $2;
	}

	# 1つ前の文と当該文に”が奇数個含まれている場合は、前の文に該当文をくっつける
	my $num_of_zenaku_quote_prev = scalar(split('”', $slist->[$i - 1])) - 1;
	my $num_of_zenaku_quote_curr = scalar(split('”', $slist->[$i])) - 1;
	if ($num_of_zenaku_quote_prev > 0 && $num_of_zenaku_quote_curr > 0) {
	    if ($num_of_zenaku_quote_prev % 2 == 1 && $num_of_zenaku_quote_curr % 2 == 1) {
		$slist->[$i - 1] .= $slist->[$i];
		splice(@$slist, $i, $i);
	    }
	}

	# 当該文が^$itemize_header$にマッチする場合、箇条書きと判断し、次の文とくっつける
 	if ($slist->[$i] =~ /^$itemize_header$/) {
 	    $slist->[$i] .= $slist->[$i + 1];
 	    splice(@$slist, $i + 1, $i + 1);
 	    redo;
 	}
    }
}

### テキストを句点で文単位に分割する
### カッコ内の句点では分割しない
sub SplitJapanese {
    my ($str) = @_;
    my (@chars, @buf, $ignore_level);

    # 字単位に分割 (UTF8)
#   my @chars = split(//, decode('utf8', $str));
    my @chars = split(//, $str);

#   my @open = grep(/^$open_kakko$/o, @chars);
#   my @close = grep(/^$close_kakko$/o, @chars);

    # 開きカッコと閉じカッコの数が整合しない場合、または
    # カッコがない場合はカッコを考慮しない
    # 括弧の対応をまじめに考えるように変更
#   if ((scalar(@open) == 0 and scalar(@close) == 0) || 
#       (scalar(@open) != scalar(@close))) {
#	$ignore_level = 1;
#   }

    my $level = 0;
    @buf = ('');
    for my $i (0 .. scalar(@chars) - 1) {
	my $char = $chars[$i];

	$buf[-1] .= $char;
	# ((括弧内でない && ．の両側にアルファベット・数字が現れていない) || $char が句読点) ならば
	if (($ignore_level || $level == 0) && 
	    # dotの前後にアルファベットや数字がある場合は切らない(URLなど)
	    (($char =~ /^$dot$/o && 
	      !($i < scalar(@chars) - 1 && $chars[$i + 1] =~ /^\p{alphabet_or_number}$/o && # 右側にアルファベットがあるかどうか
		($i == 0 || $chars[$i - 1] =~ /^\p{alphabet_or_number}$/o))) || # 右側にアルファベットがあるかどうか
	     $char =~ /^$period$/o)) {

	    if ($buf[-1] =~ /^(?:$period|$dot)$/o && scalar(@buf) > 1) { # periodの連続は前に結合
		$buf[-2] .= $buf[-1];
		$buf[-1] = '';
	    }
	    else {
		## ・・・で文を区切る
 		my $cdot = '・';
		my $sent = $buf[-1];
		my @buf2 = ();
 		while($sent =~ /^(.*?)((?:$cdot){3,}(?:$period)?)/o){
 		    my $sent1 = $1 . $2;
 		    push(@buf2, $sent1);

 		    $sent = "$'";
 		}
		push(@buf2, $sent);

		my @buf3 = ();
		foreach my $s (@buf2){
		    # 文の先頭から（...）が始まっていたら
		    if($s =~ /^(（.+?）)/){
			my $sub_s = $1;
			$s = "$'";
			while($sub_s =~ m/(.+?(?:$period|$dot))/){
			    push(@buf3, $1);
			    $sub_s = "$'";
			}
			if($sub_s ne ''){
			    push(@buf3, $sub_s);
			}
		    }
		    push(@buf3, $s);
		}

		my $size = scalar(@buf) - 1;
		foreach my $s (@buf3){
		    $buf[$size++] = $s;
		}
		push(@buf, ''); # 新しい文を始める
		$level = 0; # 括弧の対応をリセット
	    }
	}
	elsif ($char =~ /^$open_kakko$/o) {
	    $level++;
	}
	elsif ($char =~ /^$close_kakko$/o) {
	    $level-- if ($level > 0); # 開き括弧が既出であれば
	}
    }

    my @buf2 = ();
    foreach my $y (@buf) {
	$y =~ s/^\s+//;
	$y =~ s/\s+$//;
	$y =~ s/^(?:　)+//;
	$y =~ s/(?:　)+$//;

	push(@buf2, $y);
    }

    &FixParenthesis(\@buf2);
    @buf = &concatSentences(\@buf2);
    pop(@buf) unless $buf[-1];
    return @buf;
}

sub concatSentences {
    my ($sents) = @_;
    my @buff = ();
    my $tail = scalar(@{$sents}) - 1;
    while ($tail > 0) {
	if ($sents->[$tail - 1] =~ /(?:！|？|$close_kakko)$/ && $sents->[$tail] =~ /^(?:と|っ|です)/) {
	    $sents->[$tail - 1] .= $sents->[$tail];
	}
	elsif ($sents->[$tail - 1] =~ /$itemize_header$/ && $sents->[$tail] =~ /^(?:と|や|の)($itemize_header)?/) {
	    $sents->[$tail - 1] .= $sents->[$tail];
	}
	else {
	    unshift(@buff, $sents->[$tail]);
	}
	$tail--;
    }
    unshift(@buff, $sents->[0]);
    return @buff;
}

sub SplitEnglish
{
   my ($paragraph) = @_;
   my (@sentences, @words, $sentence);

   # Split the paragraph into words
   @words = split(" ", $paragraph);

   $sentence = "";

   for $i (0..$#words)
   {
      $newword = $words[$i];

      # Print the words
      #print "word is: ($newword)\n";

      # Check the existence of a candidate
      $period_pos = rindex($newword, ".");
      $question_pos = rindex($newword, "?");
      $exclam_pos = rindex($newword, "!");

      # Determine the position of the rightmost candidate in the word
      $pos = $period_pos;
      $candidate = ".";
      if ($question_pos > $period_pos)
      {
         $pos = $question_pos;
         $candidate = "?";
      }
      if ($exclam_pos > $pos)
      {
         $pos = $exclam_pos;
         $candidate = "!";
      }

      # Do the following only if the word has a candidate
      if ($pos != -1)
      {
         # Check the previous word
         if (!defined($words[$i - 1]))
         {
            $wm1 = "NP";
            $wm1C = "NP";
            $wm2 = "NP";
            $wm2C = "NP";
         }
         else
         {
            $wm1 = $words[$i - 1];
            $wm1C = Capital($wm1);

            # Check the word before the previous one 
            if (!defined($words[$i - 2]))
            {
               $wm2 = "NP";
               $wm2C = "NP";
            }
            else
            {
               $wm2 = $words[$i - 2];
               $wm2C = Capital($wm2);
            }
         }
         # Check the next word
         if (!defined($words[$i + 1]))
         {
            $wp1 = "NP";
            $wp1C = "NP";
            $wp2 = "NP";
            $wp2C = "NP";
         }
         else
         {
            $wp1 = $words[$i + 1];
            $wp1C = Capital($wp1);

            # Check the word after the next one 
            if (!defined($words[$i + 2]))
            {
               $wp2 = "NP";
               $wp2C = "NP";
            }
            else
            {
               $wp2 = $words[$i + 2];
               $wp2C = Capital($wp2);
            }
         }

         # Define the prefix
         if ($pos == 0)
         {
            $prefix = "sp";
         }
         else
         {
            $prefix = substr($newword, 0, $pos);
         }
         $prC = Capital($prefix);

         # Define the suffix
         if ($pos == length($newword) - 1)
         {
            $suffix = "sp";
         }
         else
         {
            $suffix = substr($newword, $pos + 1, length($newword) - $pos);
         }
         $suC = Capital($suffix);
 
         # Call the Sentence Boundary subroutine
         $prediction = Boundary($candidate, $wm2, $wm1, $prefix, $suffix, $wp1, 
            $wp2, $wm2C, $wm1C, $prC, $suC, $wp1C, $wp2C);

         # Append the word to the sentence
         $sentence = join ' ', $sentence, $words[$i];
         if ($prediction eq "Y")
         {
            # Eliminate any leading whitespace
            $sentence = substr($sentence, 1);

	    push(@sentences, $sentence);
            $sentence = "";
         }
      }
      else
      { 
         # If the word doesn't have a candidate, then append the word to the sentence
         $sentence = join ' ', $sentence, $words[$i];
      }
   }
   if ($sentence ne "")
   {
      # Eliminate any leading whitespace
      $sentence = substr($sentence, 1);

      push(@sentences, $sentence);
      $sentence = "";
   }
   return @sentences;
}

sub get_sentences
{
    my ($this) = @_;

    return @{$this->{sentences}};
}

# This subroutine returns "Y" if the argument starts with a capital letter.
sub Capital
{
   my ($substring);

   $substring = substr($_[0], 0, 1);
   if ($substring =~ /[A-Z]/)
   {
      return "Y";
   }
   else
   {
      return "N";
   }
}

# This subroutine does all the boundary determination stuff
# It returns "Y" if it determines the candidate to be a sentence boundary,
# "N" otherwise
sub Boundary
{
   # Declare local variables
   my($candidate, $wm2, $wm1, $prefix, $suffix, $wp1, $wp2, $wm2C, $wm1C, 
         $prC, $suC, $wp1C, $wp2C) = @_;

   # Check if the candidate was a question mark or an exclamation mark
   if ($candidate eq "?" || $candidate eq "!")
   {
      # Check for the end of the file
      if ($wp1 eq "NP" && $wp2 eq "NP")
      {
         return "Y";
      }
      # Check for the case of a question mark followed by a capitalized word
      if ($suffix eq "sp" && $wp1C eq "Y")               
      {
         return "Y";
      }
      if ($suffix eq "sp" && StartsWithQuote($wp1))
      {
         return "Y";
      }
      if ($suffix eq "sp" && $wp1 eq "--" && $wp2C eq "Y") 
      {
         return "Y";
      }
      if ($suffix eq "sp" && $wp1 eq "-RBR-" && $wp2C eq "Y")
      {
         return "Y";
      }
      # This rule takes into account vertical ellipses, as shown in the
      # training corpus. We are assuming that horizontal ellipses are
      # represented by a continuous series of periods. If this is not a
      # vertical ellipsis, then it's a mistake in how the sentences were
      # separated.
      if ($suffix eq "sp" && $wp1 eq ".")
      {
         return "Y";
      }
      if (IsRightEnd($suffix) && IsLeftStart($wp1))
      {
         return "Y";
      }
      else 
      {
         return "N";
      }
   }
   else
   {
      # Check for the end of the file
      if ($wp1 eq "NP" && $wp2 eq "NP")
      {
         return "Y";
      }
      if ($suffix eq "sp" && StartsWithQuote($wp1))
      {
         return "Y";
      }
      if ($suffix eq "sp" && StartsWithLeftParen($wp1))
      {
         return "Y";
      }
      if ($suffix eq "sp" && $wp1 eq "-RBR-" && $wp2 eq "--")
      {
         return "N";
      }
      if ($suffix eq "sp" && IsRightParen($wp1))
      {
         return "Y";
      }
      # This rule takes into account vertical ellipses, as shown in the
      # training corpus. We are assuming that horizontal ellipses are
      # represented by a continuous series of periods. If this is not a
      # vertical ellipsis, then it's a mistake in how the sentences were
      # separated.
      if ($prefix eq "sp" && $suffix eq "sp" && $wp1 eq ".")
      {
         return "N";
      }
      if ($suffix eq "sp" && $wp1 eq ".")
      {
         return "Y";
      }
      if ($suffix eq "sp" && $wp1 eq "--" && $wp2C eq "Y" 
            && EndsInQuote($prefix))
      {
         return "N";
      }
      if ($suffix eq "sp" && $wp1 eq "--" && ($wp2C eq "Y" || 
               StartsWithQuote($wp2)))
      {
         return "Y";
      }
      if ($suffix eq "sp" && $wp1C eq "Y" && 
           ($prefix eq "p.m" || $prefix eq "a.m") && IsTimeZone($wp1))
      {
         return "N";
      }
      # Check for the case when a capitalized word follows a period,
      # and the prefix is a honorific
      if ($suffix eq "sp" && $wp1C eq "Y" && IsHonorific($prefix."."))
      {
         return "N";
      }
      # Check for the case when a capitalized word follows a period,
      # and the prefix is a honorific
      if ($suffix eq "sp" && $wp1C eq "Y" && StartsWithQuote($prefix))
      {
         return "N";
      }
      # This rule checks for prefixes that are terminal abbreviations
      if ($suffix eq "sp" && $wp1C eq "Y" && IsTerminal($prefix))
      {
         return "Y";
      }
      # Check for the case when a capitalized word follows a period and the
      # prefix is a single capital letter
      if ($suffix eq "sp" && $wp1C eq "Y" && $prefix =~ /^([A-Z]\.)*[A-Z]$/)
      {
         return "N";
      }
      # Check for the case when a capitalized word follows a period
      if ($suffix eq "sp" && $wp1C eq "Y")               
      {
         return "Y";
      }
      if (IsRightEnd($suffix) && IsLeftStart($wp1))
      {
         return "Y";
      }
   }
   return "N";
}


# This subroutine checks to see if the input string is equal to an element
# of the @honorifics array.
sub IsHonorific
{
   my($word) = @_;
   my($newword);

   foreach $newword (@honorifics)
   {
      if ($newword eq $word)
      {
         return 1;      # 1 means true
      }
   }
   return 0;            # 0 means false
}

# This subroutine checks to see if the string is a terminal abbreviation.
sub IsTerminal
{
   my($word) = @_;
   my($newword);
   my(@terminals) = ("Esq", "Jr", "Sr", "M.D");

   foreach $newword (@terminals)
   {
      if ($newword eq $word)
      {
         return 1;      # 1 means true
      }
   }
   return 0;            # 0 means false
}

# This subroutine checks if the string is a standard representation of a U.S.
# timezone
sub IsTimeZone
{
   my($word) = @_;
   
   $word = substr($word,0,3);
   if ($word eq "EDT" || $word eq "CST" || $word eq "EST")
   {
      return 1;
   }
   else
   {
      return 0;
   }
}

# This subroutine checks to see if the input word ends in a closing double
# quote.
sub EndsInQuote 
{
   my($word) = @_;

   if (substr($word,-2,2) eq "''" || substr($word,-1,1) eq "'" || 
         substr($word, -3, 3) eq "'''" || substr($word,-1,1) eq "\""
         || substr($word, -2,2) eq "'\"")
   {
      return 1;         # 1 means true
   }
   else
   {
      return 0;         # 0 means false
   }
}

# This subroutine checks to see if a given word starts with one or more quotes
sub StartsWithQuote 
{
   my($word) = @_;

   if (substr($word,0,1) eq "'" ||  substr($word,0,1) eq "\"" || 
         substr($word, 0, 1) eq "`")
   {
      return 1;         # 1 means true
   }
   else
   {
      return 0;         # 0 means false
   }
}

# This subroutine checks to see if a word starts with a left parenthesis, be it
# {, ( or <
sub StartsWithLeftParen 
{
   my($word) = @_;

   if (substr($word,0,1) eq "{" || substr($word,0,1) eq "(" 
         || substr($word,0,5) eq "-LBR-")
   {
      return 1;         # 1 means true
   }
   else
   {
      return 0;         # 0 means false
   }
}

# This subroutine checks to see if a word starts with a left quote, be it
# `, ", "`, `` or ```
sub StartsWithLeftQuote 
{
   my($word) = @_;

   if (substr($word,0,1) eq "`" || substr($word,0,1) eq "\"" 
         || substr($word,0,2) eq "\"`")
   {
      return 1;         # 1 means true
   }
   else
   {
      return 0;         # 0 means false
   }
}


sub IsRightEnd
{
   my($word) = @_;
   
   if (IsRightParen($word) || IsRightQuote($word))
   {
      return 1;
   }
   else
   {
      return 0;
   }
}

# This subroutine detects if a word starts with a start mark.
sub IsLeftStart
{
   my($word) = @_;

   if(StartsWithLeftQuote($word) || StartsWithLeftParen($word) 
         || Capital($word) eq "Y")
   {
      return 1;
   }
   else
   {
      return 0;
   }
}

# This subroutine checks to see if a word is a right parenthesis, be it ), }
# or >
sub IsRightParen 
{
   my($word) = @_;

   if ($word eq "}" ||  $word eq ")" || $word eq "-RBR-")
   {
      return 1;         # 1 means true
   }
   else
   {
      return 0;         # 0 means false
   }
}

sub IsRightQuote
{
   my($word) = @_;

   if ($word eq "'" ||  $word eq "''" || $word eq "'''" || $word eq "\"" 
         || $word eq "'\"")
   {
      return 1;         # 1 means true
   }
   else
   {
      return 0;         # 0 means false
   }
}

# This subroutine prints out the elements of an array.
sub PrintArray
{
   my($word);

   foreach $word (@_)
   {
      print "Array Element = ($word)\n";
   }
}

1;
