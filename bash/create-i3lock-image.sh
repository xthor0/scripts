#!/bin/bash

# this script will convert a background image to be used with i3lock
# it will super-impose a lock icon (or, any other image) at the center of the screen
# shamelessly stolen from https://github.com/guimeira/i3lock-fancy-multimonitor

# Default variables
DISPLAY_RE="([0-9]+)x([0-9]+)\\+([0-9]+)\\+([0-9]+)"
IMAGE_RE="([0-9]+)x([0-9]+)"
FOLDER="$(dirname "$(readlink -f "$0")")"
PARAMS=""
OUTPUT_IMAGE="~/Pictures/i3lock.png"
DISPLAY_TEXT=true

# user help
function usage() {
	echo "`basename $0`: Create a background image for i3lock."
	echo "Usage:

`basename $0` [ -n ] [ -l <path to lock image> ] [ -t <path to text image> ]

    -n : do not include text.png in image
    -l : specify alternate lock image (default is lock.png in same directory as this script)
    -t : specify alternate text image (default is text.png in same directory as this script)"
	exit 255
}

# get command-line args
while getopts "nl:t:" OPTION; do
	case $OPTION in
		n) DISPLAY_TEXT=false
		l) lockimage=${OPTARG};;
		t) textimage=${OPTARG};;
		*) usage;;
	esac
done

# verify command-line args
if [ "${DISPLAY_TEXT}" == "false" -a -n "${textimage}" ]; then
  echo "Confusing, both -n and -l were specified."
	usage
fi

# unless specified on the command-line...
if [ "${DISPLAY_TEXT}" == "true" ]; then
  if [ -z "${textimage}" ]; then
    textimage="$FOLDER/../img/text.png"
  fi
fi

if [ -z "${lockimage}" ]; then
  lockimage="$FOLDER/../img/lock.png"
fi


# make sure images exist
for image in ${lockimage} ${textimage}


# Read user input
POSITIONAL=()
for i in "$@"
do
  case $i in
  -h|--help)
    echo "lock: Syntax: lock [-n|--no-text] [-p|--pixelate] [-b=VAL|--blur=VAL]"
    echo "for correct blur values, read: http://www.imagemagick.org/Usage/blur/#blur_args"
    exit
    shift
    ;;
  -b=*|--blur=*)
    VAL="${i#*=}"
    BLURTYPE=(${VAL//=/ }) 
    shift
    ;;
  -n|--no-text)
    DISPLAY_TEXT=false
    shift # past argument
    ;;
  -p|--pixelate)
    PIXELATE=true
    shift # past argument
    ;;
  *)    # unknown option
    echo "unknown option: $i"
    exit
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

#T ake screenshot:
scrot $OUTPUT_IMAGE

#Get dimensions of the lock image:
LOCK_IMAGE_INFO=`identify $LOCK`
[[ $LOCK_IMAGE_INFO =~ $IMAGE_RE ]]
IMAGE_WIDTH=${BASH_REMATCH[1]}
IMAGE_HEIGHT=${BASH_REMATCH[2]}

if $DISPLAY_TEXT ; then
  #Get dimensions of the text image:
  TEXT_IMAGE_INFO=`identify $TEXT`
  [[ $TEXT_IMAGE_INFO =~ $IMAGE_RE ]]
  TEXT_WIDTH=${BASH_REMATCH[1]}
  TEXT_HEIGHT=${BASH_REMATCH[2]}
fi

#Execute xrandr to get information about the monitors:
while read LINE
do
  #If we are reading the line that contains the position information:
  if [[ $LINE =~ $DISPLAY_RE ]]; then
    #Extract information and append some parameters to the ones that will be given to ImageMagick:
    WIDTH=${BASH_REMATCH[1]}
    HEIGHT=${BASH_REMATCH[2]}
    X=${BASH_REMATCH[3]}
    Y=${BASH_REMATCH[4]}
    POS_X=$(($X+$WIDTH/2-$IMAGE_WIDTH/2))
    POS_Y=$(($Y+$HEIGHT/2-$IMAGE_HEIGHT/2))

    PARAMS="$PARAMS '$LOCK' '-geometry' '+$POS_X+$POS_Y' '-composite'"

    if $DISPLAY_TEXT ; then
        TEXT_X=$(($X+$WIDTH/2-$TEXT_WIDTH/2))
        TEXT_Y=$(($Y+$HEIGHT/2-$TEXT_HEIGHT/2+200))
        PARAMS="$PARAMS '$TEXT' '-geometry' '+$TEXT_X+$TEXT_Y' '-composite'"
    fi
  fi
done <<<"`xrandr`"

#Execute ImageMagick:
if $PIXELATE ; then
  PARAMS="'$OUTPUT_IMAGE' '-scale' '10%' '-scale' '1000%' $PARAMS '$OUTPUT_IMAGE'"
else
  PARAMS="'$OUTPUT_IMAGE' '-level' '0%,100%,0.6' '-blur' '$BLURTYPE' $PARAMS '$OUTPUT_IMAGE'"
fi

eval convert $PARAMS

#Lock the screen:
i3lock -i $OUTPUT_IMAGE -t

#Remove the generated image:
rm $OUTPUT_IMAGE
