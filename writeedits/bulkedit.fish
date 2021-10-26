#! /usr/bin/env fish
argparse -i 's/strip=?' 'm/multiple' 'noclean' 'h/help' -- $argv

if set -q _flag_h
  echo "Consume a tab-separated edit list of files and apply ffmpeg filters to it"
  echo ""
  echo "Usage: bulkedit.fish [options]"
  echo "  -s, --strip: Strips supplied pattern from input filenames."
  echo "  -m, --multiple: Allows multiple edits to the same source file. Recommend setting output in editfile, else will clobber"
  echo "  -n, --noclean: Don't delete editlist when done"
  echo "  -h, --help: Show this help"
  echo ""
  echo "Editlist format is 1 edit instruction per line, tab separated. Fields are:"
  echo "filename, filters, start time, end time, output filename"
  echo "Only filename is required, although script will do nothing if no other fields are specified"
  exit
end

set -l listfile "edits"
set -l vars filters start_time end_time output_name

set -l dateCmd "date"
set -l touchCmd "touch"

if string match -q "Darwin" (uname)
  set dateCmd "gdate"
  set touchCmd "gtouch"
end

if not test -e $listfile
  exit 0
end

set -l filterCmd ""

if test -n "$_flag_s"
  set _flag_s (string escape --style=regex "$_flag_s" | string replace -a '/' '\/')
  set filterCmd "{ gsub(/"$_flag_s"/, \"\"); print }"
end

set -l dedupeCmd "!_[\$1]++"
if  set -q _flag_m
  set dedupeCmd "1"
end

set -l filesProcessed 0

for f in (awk -F'\t' "$dedupeCmd $filterCmd" $listfile)
  echo $f | read -d \t -l filename $vars
  if not test -e $filename
    continue
  end

  for i in $vars
    if test -z "$$i"
      set -e $i
    end
  end


  set -q start_time; and set -p start_time "-ss"
  set -q end_time; and set -p end_time "-to"
  set -q filters; and set -p filters "-vf"

  set -l editedname ""
  if set -q output_name
    set editedname $output_name
  else
    set editedname (dirname $filename)/edited-(basename $filename)
  end

  set ogDate ($dateCmd -r $filename --iso-8601=seconds)
  set vCodec (ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $filename)

  ffmpeg -hide_banner -i $filename $start_time $end_time -c copy -c:v $vCodec $filters $editedname

  if not set -q output_name
    mv $editedname $filename
    $touchCmd -d $ogDate $filename
  end
  set filesProcessed (math $filesProcessed + 1)
end
if test $filesProcessed -eq 0
  echo "No files processed, check your file and command line options"
  exit 1
end
set -q _flag_noclean; or rm $listfile
