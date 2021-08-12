#! /usr/bin/env fish
set -l listfile "edits"
set -l vars filters start_time end_time

set -l dateCmd "date"
set -l touchCmd "touch"

if string match -q "Darwin" (uname) && type -q gdate && type -q gtouch
  set dateCmd "gdate"
  set touchCmd "gtouch"
end

if not test -e $listfile
  exit 0
end

set -l filesProcessed 0

for f in (awk -F'\t' "!_[\$1]++" $listfile)
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

  set editedname (dirname $filename)/edited-(basename $filename)
  set ogDate ($dateCmd -r $filename --iso-8601=seconds)
  set vCodec (ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $filename)
  ffmpeg -hide_banner -i $filename $start_time $end_time -c copy -c:v $vCodec $filters $editedname
  mv $editedname $filename
  $touchCmd -d $ogDate $filename
  set filesProcessed (math $filesProcessed + 1)
end
if test $filesProcessed -eq 0
  echo "No files processed, check your file and paths"
  exit 1
end
rm $listfile
