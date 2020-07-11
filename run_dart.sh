#!/usr/bin/env bash
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

## some defaults
MAX_ALT=${MAX_ALT:-5}
MAX_FRM=${MAX_FRM:-1}
MAX_LAT=${MAX_LAT:-2}
HORIZON=${HORIZON:-10}
P_LOOSE_DESTROY=${P_LOOSE_DESTROY:-1.0}
P_LOOSE_DETECT=${P_LOOSE_DETECT:-1.0}
P_TIGHT_DESTROY=${P_TIGHT_DESTROY:-0.4}
P_TIGHT_DETECT=${P_TIGHT_DETECT:-0.4}
TOTAL_THREATS=${TOTAL_THREATS:-2}
TOTAL_TARGETS=${TOTAL_TARGETS:-6}

## parse the arguments
for i in "$@"; do case $i in
  --reach-path=*)  REACH_PATH="${i#*=}"; shift;;
  --prism-path=*)  PRISM_PATH="${i#*=}"; shift;;
  --skip-analysis) SKIP="TRUE"; shift;;
  --simcount=*)    SIMCOUNT="${i#*=}"; shift;;
  *) echo "Usage: run_dart [--reach-path=<path>] [--prism-path=<path>] [--skip-analysis] [--simcount=<count>]"; exit 1;;
esac; shift; done

W="\033[0m"
R="\033[0;31m"
G="\033[0;32m"
B="\033[0;96m"

FAIL="${R}fail${W}"
DONE="${G}done${W}"

## make sure the paths are set
if [[ -z $REACH_PATH ]]; then
  >&2 echo -e "${R}ERROR${W}: no path provided to reach.sh. Please pass '--reach-path' or set 'REACH_PATH' in the env" && exit 1;
fi
if [[ -z $PRISM_PATH ]]; then
  >&2 echo -e "${R}ERROR${W}: no path provided to prism. Please pass '--prism-path' or set 'PRISM_PATH' in the env" && exit 1;
fi

## set the environment variable determining the results directory
export RESULTS_DIR="$PWD/results/${1:-$(date +run_%Y%m%d_%H%M%S)}"
mkdir -p $RESULTS_DIR
if [[ -n $SKIP ]]; then
  cp "$PWD/results/latest/reach.log" "$RESULTS_DIR/"
  cp "$PWD/results/latest/bounds.log" "$RESULTS_DIR/"
  cp -R "$PWD/results/latest/reach" "$RESULTS_DIR/"
  cp -R "$PWD/results/latest/prism" "$RESULTS_DIR/"
fi
ln -sfn $RESULTS_DIR ./results/latest
echo -e "Results directory: ${B}${RESULTS_DIR}${W} (or ./results/latest)"
cp .weights "${RESULTS_DIR}/.weights"

if [[ -z $SKIP ]]; then
  ## compute the reachability using the run_reach script
  echo -n "Computing reachability graph       ... "
  ./run_reach.sh dart "$REACH_PATH" \
    >>"${RESULTS_DIR}/reach.log" || { echo -e "${FAIL}"; exit 1; }
  echo -e "${DONE}"
  
  ## compute the bounds using the run_bounds script
  echo -n "Computing upper- and lower-bounds  ... "
  ./run_bounds.sh dart "$PRISM_PATH" \
    >>"${RESULTS_DIR}/bounds.log" || { echo -e "${FAIL}"; exit 1; }
  echo -e "${DONE}"
fi

while read -r -u10 W; do
  pushd java &>/dev/null
  echo -n "Optimizing fuzzy values ($W) ... "
  ./gradlew makeFuzzy --args "dart ${RESULTS_DIR}/prism ${RESULTS_DIR}/fuzzy${W//,/-} $W" --quiet --console=plain \
    >>"${RESULTS_DIR}/fuzzy.log" || { echo -e "${FAIL}"; exit 1; }
  echo -e "${DONE}"
  
  echo -n "Pareto optimization of transitions       ... "
  ./gradlew trimGraph --args "dart ${RESULTS_DIR}/reach/dart.yaml ${RESULTS_DIR}/fuzzy${W//,/-} ${RESULTS_DIR}/trim${W//,/-} $W" --quiet --console=plain \
    >>"${RESULTS_DIR}/pareto.log" || { echo -e "${FAIL}"; exit 1; }
  echo -e "${DONE}"
  popd &>/dev/null
  
  # trim the graph with the python script
  echo -n "Trimming reachability graph              ... "
  TRIM_OUTPUT=$(W=${W//,/-} ./python/trim-dart.py)
  if [[ $? -ne 0 ]]; then
      echo -e "${FAIL}"
      echo $TRIM_OUTPUT
      exit 1
  else
      echo -n -e "${DONE} "
      echo $TRIM_OUTPUT
      echo "$W: $TRIM_OUTPUT" >> ${RESULTS_DIR}/trim-percent.txt
      cp "${RESULTS_DIR}/reach/dart-step.yaml" "${RESULTS_DIR}/trim${W//,/-}/dart.yaml"
  fi
done 10< "${RESULTS_DIR}/.weights"

SIMCOUNT="${SIMCOUNT:-1000}"
if ((SIMCOUNT > 0)); then
  printf "Running DART simulation (%4d)           ... " $SIMCOUNT
  mkdir -p "${RESULTS_DIR}/dart"
  pushd ../pladapt/examples/dart/dartsim >/dev/null
  cp "${RESULTS_DIR}/reach/dart.yaml"      "${RESULTS_DIR}/dart/dart.i.yaml"
  cp "${RESULTS_DIR}/reach/dart-step.yaml" "${RESULTS_DIR}/dart/dart.yaml"
  
  for ((i=0; i<SIMCOUNT; i++)); do
    SEED=$(printf '%05d' $RANDOM)
    while read -r -u10 W; do
      DART_OPTS="--adapt-mgr sdp --seed $SEED --altitude-levels $MAX_ALT --threat-range $RANGE_THREAT --dl-target-sensor-range $RANGE_SENSOR"
      ./run.sh $DART_OPTS --yaml-folder "${RESULTS_DIR}/trim${W//,/-}/" >"${RESULTS_DIR}/dart/$SEED-${W//,/-}thallium.log" && \
      ./run.sh $DART_OPTS --yaml-folder "${RESULTS_DIR}/dart/"          >"${RESULTS_DIR}/dart/$SEED-${W//,/-}pladapt.log"
      if [[ $? -ne 0 ]]; then
          echo -e "${FAIL}"
          popd >/dev/null
          exit 1
      fi
    done 10< "${RESULTS_DIR}/.weights"
  done
  popd >/dev/null
  echo -e "${DONE}"
fi
