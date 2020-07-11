#!/usr/bin/env bash
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

## in case we have any args later
for i in "$@"; do case $i in
    *) POSARG+=("$1"); shift;;
esac; done
set -- "${POSARG[@]}"

## make sure we specify rubis/dart/deltaiot
if [[ -z $1 ]]; then
  >&2 echo 'USAGE: run_reach.sh <rubis|dart|deltaiot> [path/to/reach.sh]' && exit 1
fi

## make sure we can find reach.sh
REACH_PATH=${2:-$REACH_PATH}
if [[ -z $REACH_PATH ]]; then
  >&2 echo 'ERROR: cannot find reach.sh, please pass the path or define REACH_PATH' && exit 1
fi

## clean up our temp files when the script exits
TEMP_PATH=$(mktemp -d)
trap "rm -rf $TEMP_PATH" 0

## create the output directory
OUTPUT_ROOT=${RESULTS_DIR:-.}/reach
mkdir -p $OUTPUT_ROOT && rm -f $OUTPUT_ROOT/*

if [ "$1" = "rubis" ]; then 
  ## replace the placeholders with the arguments in the models
  for i in rubis.als rubis-step.als; do
    cat ./model/$i \
      | sed -E "s/\/\*MAX_SERVERS=\*\/ *[0-9]+/$MAX_S/"  \
      | sed -E "s/\/\*MAX_PROGRESS=\*\/ *[0-9]+/$MAX_P/" \
      | sed -E "s/\/\*MAX_DIMMER=\*\/ *[0-9]+/$MAX_D/"   \
      > $TEMP_PATH/$i
  done
  
  ## execute the reachability generation script on the temp files
  $REACH_PATH/reach.sh -i   $TEMP_PATH/rubis.als      ${OUTPUT_ROOT}/rubis.yaml \
    && $REACH_PATH/reach.sh $TEMP_PATH/rubis-step.als ${OUTPUT_ROOT}/rubis-step.yaml
elif [ "$1" = "dart" ]; then
  ## replace the placeholders for dart
  for i in dart2.als dart2-step.als; do
    cat ./model/$i \
      | sed -E "s/\/\*MAX_ALT=\*\/ *[0-9]+/$MAX_ALT/g" \
      | sed -E "s/\/\*MAX_FRM=\*\/ *[0-9]+/$MAX_FRM/g" \
      | sed -E "s/\/\*MAX_LAT=\*\/ *[0-9]+/$MAX_LAT/g" \
      > ${OUTPUT_ROOT}/$i
  done
  ## execute the reachability generation script on the temp files
  $REACH_PATH/reach.sh -i   -d ${OUTPUT_ROOT}/dart2.als      ${OUTPUT_ROOT}/dart.yaml \
    && $REACH_PATH/reach.sh -d ${OUTPUT_ROOT}/dart2-step.als ${OUTPUT_ROOT}/dart-step.yaml
elif [ "$1" = "deltiot" ]; then
  ## replace the placeholders for deltaiot
  for i in deltaiot.als deltaiot-step.als; do
    cat ./model/$i > ${OUTPUT_ROOT}/$i
  done
  ## execute the reachability generation script on the temp files
  $REACH_PATH/reach.sh -i   -d ${OUTPUT_ROOT}/deltaiot.als      ${OUTPUT_ROOT}/deltaiot.yaml \
    && $REACH_PATH/reach.sh -d ${OUTPUT_ROOT}/deltaiot-step.als ${OUTPUT_ROOT}/deltaiot-step.yaml
else
  ## unexpected value, log an error
  >&2 echo "ERROR: unknown example name: $1" && exit 1
fi
