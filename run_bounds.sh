#!/usr/bin/env bash
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

## parse the command line arguments for the maximum value for
## the servers, progress, and dimmer (and keep the positional
## arguments for later, since we need the path to reach.sh)
for i in "$@"; do case $i in
    *) POSARG+=("$1"); shift;;
esac; done
set -- "${POSARG[@]}"

## make sure we specify rubis/dart
if [[ -z $1 ]]; then
  >&2 echo 'USAGE: run_bounds.sh <rubis|dart> [path/to/prism]' && exit 1
fi

## make sure the paths we need are properly set/exist
PRISM_PATH=${2:-$PRISM_PATH}
if [[ -z $PRISM_PATH ]]; then
  >&2 echo 'ERROR: cannot find prism, please pass the path or define PRISM_PATH' && exit 1
fi
mkdir -p ${RESULTS_DIR:-.}/prism

## run some ridiculous perl regex business in order to account for the various
## configurable values that actually require changes to the Prism model. for
## example, changing the arrival rate requires actual code changes to the 
## 'evolve' module, which we have to change in the model file itself. similarly,
## Prism doesn't have a factorial function, so we have to compute those values
## and hard code them in the 'CFact' reward. lastly, Prism requires a different
## syntax for variables within a range and variables that are a single value
build_rubis_model () {
  perl -00 -pe "s/(module evolve).*(endmodule)/\1\n$(
    echo "    [do_env] (turn=ENV_TURN) -> (local_arrivals'=$1);"
  )\n\2/s;" -pe "s/(^formula CFact[\s=]+$).*(^\s*;\s*$)/\1\n$(
    if ((MAX_S>=3)); then
      for ((i=MAX_S;i>=3;i--)); do
        fac=$(perl -MMath::BigInt -le "print Math::BigInt->new($i-1)->bfac()")
        echo "        (num_servers=$i?$fac:"
      done
    fi
    echo "        1";
    if ((MAX_S>=3)); then
      echo -n "        "
      for ((i=MAX_S;i>=3;i--)); do
        echo -n ")"
      done
      echo
    fi
  )\n\2/sm;" -pe "s/(^.*dimmer : .*$)/$(
    if ((MAX_D > 1)); then
      echo -n '\1'
    else
      echo '    dimmer : int init 1;'
    fi
  )/m;" -pe "s/(^.*num_servers : .*$)/$(
    if ((MAX_S > 1)); then
      echo -n '\1'
    else
      echo '    num_servers : int init 1;'
    fi
  )/m;" -pe "s/(^.*progress *: .*$)/$(
    if ((MAX_P > 1)); then
      echo -n '\1'
    else
      echo '    progress : int init 1;'
    fi
  )/m;" <./model/rubis.smg >${RESULTS_DIR:-.}/prism/$2
}

if [ "$1" = "rubis" ]; then
  ## build up the constants to pass to Prism, paying attention to 
  ## whether the experimental maxima are equal to 1
  CONSTS="HORIZON=$HORIZON,MAX_DIMMER=$MAX_D,MAX_SERVERS=$MAX_S,MAX_PROGRESS=$MAX_P"
  for i in SECS_PER_STEP SERVICE_RATE DIMMER_ADJ THRESHOLD SRV_COST_PER_HOUR MAX_ARRIVAL_RATE; do
    CONSTS="$CONSTS,$i=${!i}"
  done;
  if ((MAX_DIMMER > 1)); then
    CONSTS="$CONSTS,INIT_DIMMER=1:1:$MAX_D"
  else
    CONSTS="$CONSTS,INIT_DIMMER=1"
  fi
  if ((MAX_PROGRESS > 1)); then
    CONSTS="$CONSTS,INIT_PROGRESS=1:1:$MAX_P"
  else
    CONSTS="$CONSTS,INIT_PROGRESS=1"
  fi
  if ((MAX_SERVERS > 1)); then
    CONSTS="$CONSTS,INIT_SERVERS=1:1:$MAX_S"
  else
    CONSTS="$CONSTS,INIT_SERVERS=1"
  fi
  echo $CONSTS | tr "," "\n" > ${RESULTS_DIR:-.}/prism/.env
  
  build_rubis_model 0 rubis-best.smg
  $PRISM_PATH/prism \
    ${RESULTS_DIR:-.}/prism/rubis-best.smg \
    ./model/rubis-best.pctl \
    -const $CONSTS \
    -exportresults "${RESULTS_DIR:-.}/prism/rubis-best.txt" 
  
  build_rubis_model $MAX_ARRIVAL_RATE rubis-worst.smg
  $PRISM_PATH/prism \
    ${RESULTS_DIR:-.}/prism/rubis-worst.smg \
    ./model/rubis-worst.pctl \
    -const $CONSTS \
    -exportresults "${RESULTS_DIR:-.}/prism/rubis-worst.txt" 
  
  build_rubis_model $EXP_ARRIVAL_RATE rubis-exp.smg
  $PRISM_PATH/prism \
    ${RESULTS_DIR:-.}/prism/rubis-exp.smg \
    ./model/rubis-best.pctl \
    -const $CONSTS \
    -exportresults "${RESULTS_DIR:-.}/prism/rubis-exp.txt" 
elif [ "$1" = "dart" ]; then
  MAX_LAT=$((MAX_LAT-1))
  CONSTS="INIT_T=0,MAX_ALTITUDE=$MAX_ALT,MAX_LATENCY=$MAX_LAT,INIT_F=0:1:1"
  for i in HORIZON P_LOOSE_DESTROY P_LOOSE_DETECT P_TIGHT_DESTROY P_TIGHT_DETECT TOTAL_THREATS TOTAL_TARGETS RANGE_SENSOR RANGE_THREAT; do
    CONSTS="$CONSTS,$i=${!i}"
  done
  if ((MAX_ALT>1)); then
    CONSTS="$CONSTS,INIT_A=1:1:$MAX_ALT"
  else
    CONSTS="$CONSTS,INIT_A=1"
  fi
  if ((MAX_LAT>0)); then
    CONSTS="$CONSTS,INIT_L=-$MAX_LAT:1:$MAX_LAT"
  else
    CONSTS="$CONSTS,INIT_L=0"
  fi
  for i in best worst; do
    cp ./model/dart2-smg.prism "${RESULTS_DIR:-.}/prism/dart-$i.smg"
    $PRISM_PATH/prism \
      "${RESULTS_DIR:-.}/prism/dart-$i.smg" \
      "./model/dart-$i.pctl" \
      -const "$CONSTS,EXPECTED=0" \
      -exportresults "${RESULTS_DIR:-.}/prism/dart-$i.txt"
  done
  cp ./model/dart2-exp.prism ${RESULTS_DIR:-.}/prism/
  $PRISM_PATH/prism \
    "${RESULTS_DIR:-.}/prism/dart2-exp.prism" \
    "./model/dart-exp.pctl" \
    -const "$CONSTS,EXPECTED=1" \
    -exportresults "${RESULTS_DIR:-.}/prism/dart-exp.txt"
else
  ## unexpected value, log an error
  >&2 echo "ERROR: unknown example name: $1" && exit 1
fi
