#!/bin/zsh

# just drop the files in an encode directory in PWD
test -d encode || mkdir encode

find . -type f -maxdepth 1 -iname '*.mp4' -o -iname '*.mov' | while read infile; do

    # holy shit, zsh is way easier to do this with than Bash. Where has this been my whole life.
    filefront="${infile:t:r}"
    outfile="encode/${filefront}.mp4"

    # HandBrake this biatch
    if [ -f "${outfile}" ]; then
        echo "Output file already exists: ${outfile}"
    else
        echo "HandBraking this mother fucker: ${outfile}"
        echo | HandBrakeCLI -d -E aac -B 128 -e x264 --encoder-tune film --encoder-preset fast -i "${infile}" -o "${outfile}"
    fi
done

