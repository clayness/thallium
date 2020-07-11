#!/usr/bin/env bash
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

## some defaults
          HORIZON=${HORIZON:-10}
    SECS_PER_STEP=${SECS_PER_STEP:-10}
     SERVICE_RATE=${SERVICE_RATE:-10}
       DIMMER_ADJ=${DIMMER_ADJ:-1.5}
        THRESHOLD=${THRESHOLD:-4000}
SRV_COST_PER_HOUR=${SRV_COST_PER_HOUR:-0.07}
 EXP_ARRIVAL_RATE=${EXP_ARRIVAL_RATE:-0}
 MAX_ARRIVAL_RATE=${MAX_ARRIVAL_RATE:-20}
            MAX_S=${MAX_S:-6}
            MAX_P=${MAX_P:-2}
            MAX_D=${MAX_D:-2}

## parse the arguments
for i in "$@"; do case $i in
  --reach-path=*) REACH_PATH="${i#*=}"; shift;;
  --prism-path=*) PRISM_PATH="${i#*=}"; shift;;
  -s=*|--servers=*)    MAX_S="${i#*=}"; shift;;
  -p=*|--progress=*)   MAX_P="${i#*=}"; shift;;
  -d=*|--dimmer=*)     MAX_D="${i#*=}"; shift;;
  --skip-analysis) SKIP="TRUE"; shift;;
  *) echo "Usage: run_all [--reach-path=<path>] [--prism-path=<path>] [--skip-analysis]"; exit 1;;
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
  ./run_reach.sh  rubis "$REACH_PATH" \
    >>"${RESULTS_DIR}/reach.log" || { echo -e "${FAIL}"; exit 1; }
  echo -e "${DONE}"
  
  ## compute the bounds using the run_bounds script
  echo -n "Computing upper- and lower-bounds  ... "
  ./run_bounds.sh "$PRISM_PATH" -s=$MAX_S -p=$MAX_P -d=$MAX_D \
    >>"${RESULTS_DIR}/bounds.log" || { echo -e "${FAIL}"; exit 1; }
  echo -e "${DONE}"
fi

while read -r -u10 W; do  
  pushd java &>/dev/null
  echo -n "Optimizing fuzzy values ($W) ... "
  ./gradlew makeFuzzy --args "rubis ${RESULTS_DIR}/prism ${RESULTS_DIR}/fuzzy${W//,/-} $W" --quiet --console=plain \
    >>"${RESULTS_DIR}/fuzzy.log" || { echo -e "${FAIL}"; exit 1; }
  echo -e "${DONE}"

  echo -n "Pareto optimization of transitions ... "
  ./gradlew trimGraph --args "rubis ${RESULTS_DIR}/reach/rubis.yaml ${RESULTS_DIR}/fuzzy${W//,/-} ${RESULTS_DIR}/trim${W//,/-} $W" --quiet --console=plain --info \
    >>"${RESULTS_DIR}/pareto.log" || { echo -e "${FAIL}"; exit 1; }
  echo -e "${DONE}"
  popd &>/dev/null

  # trim the graph with the python script
  echo -n "Trimming reachability graph        ... "
  TRIM_OUTPUT=$(W=${W//,/-} ./python/trim-rubis.py)
  if [[ $? -ne 0 ]]; then
      echo -e "${FAIL}"
      echo $TRIM_OUTPUT
      exit 1
  else
      echo -e "${DONE}"
      echo $TRIM_OUTPUT
      echo "$W: $TRIM_OUTPUT" >> ${RESULTS_DIR}/trim-percent.txt
  fi
done 10< "${RESULTS_DIR}/.weights"
