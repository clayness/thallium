#!/usr/bin/env bash
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

RESULTS_DIR=$(pwd)/results/latest

W="\033[0m"
R="\033[0;31m"
G="\033[0;32m"
B="\033[0;96m"

FAIL="${R}fail${W}"
DONE="${G}done${W}"

COUNT=${1:-100}

echo -n "Running DART simulation            ... "
mkdir -p "${RESULTS_DIR}/dart"
pushd ../pladapt/examples/dart/dartsim >/dev/null
cp "${RESULTS_DIR}/reach/dart.yaml" "${RESULTS_DIR}/dart/dart.i.yaml"
cp "${RESULTS_DIR}/reach/dart-step.yaml" "${RESULTS_DIR}/dart/dart.yaml"
>${RESULTS_DIR}/dart/pladapt.csv
>${RESULTS_DIR}/dart/thallium.csv
for ((i=0; i<COUNT; i++)); do
  SEED=$(printf '%05d' $RANDOM)
  DART_OPTS="--adapt-mgr sdp --seed $SEED --altitude-levels $MAX_ALT --threat-range $RANGE_THREAT --dl-target-sensor-range $RANGE_SENSOR"
  ./run.sh $DART_OPTS --yaml-folder "${RESULTS_DIR}/trim/" >"${RESULTS_DIR}/dart/$SEED-thallium.log" && \
  ./run.sh $DART_OPTS --yaml-folder "${RESULTS_DIR}/dart/" >"${RESULTS_DIR}/dart/$SEED-pladapt.log"
  if [[ $? -ne 0 ]]; then
      echo -e "${FAIL}"
      popd >/dev/null
      exit 1
  fi
  echo "$SEED,$(tail -n 1 ${RESULTS_DIR}/dart/$SEED-pladapt.log)"  >> ${RESULTS_DIR}/dart/pladapt.csv
  echo "$SEED,$(tail -n 1 ${RESULTS_DIR}/dart/$SEED-thallium.log)" >> ${RESULTS_DIR}/dart/thallium.csv
done
sed -i '' 's/csv,//g' ${RESULTS_DIR}/dart/*.csv
popd >/dev/null
echo -e "${DONE}"
